#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=== Phase 3: Docker Object Setup ==="

# --- 1. Apply HA candidate labels to manager nodes ---
echo "[1/3] Applying node labels..."

for node in node1 node2 node3; do
    ssh ubuntu@$(grep "^${node} " "${ROOT_DIR}/ansible/inventory" | grep -oP 'ansible_host=\K[0-9.]+') \
        "docker node update --label-add ha.candidate=true ${node}"
done

echo "  Labels applied to node1, node2, node3."

# --- 2. Create Docker volumes (bind-mounted to GlusterFS) ---
echo "[2/3] Creating Docker volumes..."

declare -A VOLUMES=(
    [portainer_data]="/gluster-mount/portainer"
    [influxdb_data]="/gluster-mount/influxdb"
    [grafana_data]="/gluster-mount/grafana"
    [unifi_data]="/gluster-mount/unifi"
    [pihole_data]="/gluster-mount/pihole"
    [wireguard_data]="/gluster-mount/wireguard"
)

for node in node1 node2 node3 node4 node5 node6 node7; do
    IP=$(grep "^${node} " "${ROOT_DIR}/ansible/inventory" | grep -oP 'ansible_host=\K[0-9.]+')
    for vol in "${!VOLUMES[@]}"; do
        MOUNT_PATH="${VOLUMES[$vol]}"
        ssh ubuntu@"${IP}" "mkdir -p ${MOUNT_PATH}"
        ssh ubuntu@"${IP}" "docker volume create --driver local --opt type=none --opt o=bind --opt device=${MOUNT_PATH} ${vol} 2>/dev/null || true"
    done
done

echo "  Volumes created on all nodes."

# --- 3. Generate Docker Secrets from .txt files ---
echo "[3/3] Generating Docker Secrets..."

for secret_file in "${ROOT_DIR}/secrets"/*.txt; do
    [[ -f "${secret_file}" ]] || continue
    secret_name=$(basename "${secret_file}" .txt)
    cat "${secret_file}" | docker secret create "${secret_name}" -
    echo "  Secret created: ${secret_name}"
done

echo "=== Phase 3 Complete ==="
