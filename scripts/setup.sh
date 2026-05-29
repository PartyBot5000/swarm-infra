#!/usr/bin/env bash
set -euo pipefail

# Phase 3: Docker Object Setup
# Runs from the control machine, SSHing into each node.
#
# 1. Applies ha.candidate=true labels to manager nodes
# 2. Creates local bind-mount Docker volumes mapped to GlusterFS paths
# 3. Generates Docker Secrets from secrets/*.txt files
#    (secrets are created on node1 which is a Swarm manager)
#
# Prerequisites: key-based SSH access to all nodes (Phase 1),
#                Swarm initialised (Phase 2)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
INVENTORY="${ROOT_DIR}/ansible/inventory"

# ── Helper: read node IP from inventory ──────────────────────
node_ip() {
    grep "^$1 " "${INVENTORY}" | grep -oP 'ansible_host=\K\S+' | head -1
}

node_user() {
    grep "^$1 " "${INVENTORY}" | grep -oP 'ansible_user=\K\S+' | head -1
}

echo "=== Phase 3: Docker Object Setup ==="

# ── 1. Apply HA candidate labels ─────────────────────────────
echo "[1/3] Applying ha.candidate=true labels to manager nodes..."

for node in node1 node2 node3; do
    ip=$(node_ip "${node}")
    user=$(node_user "${node}")
    echo "  → ${node} (${user}@${ip})"
    ssh -o StrictHostKeyChecking=no "${user}@${ip}" \
        "docker node update --label-add ha.candidate=true ${node}"
done

echo "  ✓ Labels applied."

# ── 2. Create Docker volumes (bind-mounted to GlusterFS) ────
echo ""
echo "[2/3] Creating Docker volumes on all nodes..."

declare -A VOLUMES=(
    [portainer_data]="/gluster-mount/portainer"
    [influxdb_data]="/gluster-mount/influxdb"
    [grafana_data]="/gluster-mount/grafana"
    [unifi_data]="/gluster-mount/unifi"
    [pihole_data]="/gluster-mount/pihole"
    [wireguard_data]="/gluster-mount/wireguard"
)

for node in node1 node2 node3 node4 node5 node6 node7; do
    ip=$(node_ip "${node}")
    user=$(node_user "${node}")
    echo "  → ${node} (${user}@${ip})"

    for vol in "${!VOLUMES[@]}"; do
        mount_path="${VOLUMES[$vol]}"
        ssh -o StrictHostKeyChecking=no "${user}@${ip}" \
            "mkdir -p ${mount_path} && \
             docker volume create --driver local \
               --opt type=none \
               --opt o=bind \
               --opt device=${mount_path} \
               ${vol} 2>/dev/null || true"
    done
done

echo "  ✓ Volumes created on all 7 nodes."

# ── 3. Generate Docker Secrets ───────────────────────────────
echo ""
echo "[3/3] Generating Docker Secrets on node1..."

node1_ip=$(node_ip "node1")
node1_user=$(node_user "node1")

for secret_file in "${ROOT_DIR}/secrets"/*.txt; do
    [[ -f "${secret_file}" ]] || continue
    secret_name=$(basename "${secret_file}" .txt)

    echo "  → Secret: ${secret_name}"
    # Copy the secret file to node1, create the secret, then remove it
    ssh -o StrictHostKeyChecking=no "${node1_user}@${node1_ip}" \
        "cat <<'SECRET_EOF' | docker secret create ${secret_name} -
$(cat "${secret_file}")
SECRET_EOF"
done

echo "  ✓ Secrets created."

echo ""
echo "=== Phase 3 Complete ==="
