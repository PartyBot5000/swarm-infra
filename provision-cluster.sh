#!/usr/bin/env bash
set -euo pipefail

# Master orchestration script — runs the full 4-phase provisioning pipeline.
# Executed from the control machine. Ansible playbooks run inside a Docker
# container; bootstrap and setup scripts run locally with SSH to nodes.
#
# Usage: ./provision-cluster.sh
#
# Prerequisites:
#   1. ansible/inventory populated with hostnames and SSH credentials
#   2. secrets/*.txt populated with real credential values
#   3. Docker available on the control machine

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="${SCRIPT_DIR}/ansible"
ANSIBLE_CONTAINER="swarm-infra-ansible"

echo "======================================================"
echo " Swarm Infrastructure — Full Cluster Provisioning"
echo "======================================================"
echo ""

# ── Phase 1: Bootstrap SSH keys ──────────────────────────────
echo "[Phase 1/4] Bootstrapping SSH keys..."
echo "──────────────────────────────────────────────────────"
bash "${SCRIPT_DIR}/bootstrap/bootstrap-node.sh" "${ANSIBLE_DIR}/inventory"
echo ""

# ── Phase 2: Ansible infrastructure (via Docker container) ───
echo "[Phase 2/4] Running Ansible playbooks..."
echo "──────────────────────────────────────────────────────"

# Build and start the Ansible container
echo "Starting Ansible container..."
docker run --rm --name "${ANSIBLE_CONTAINER}" \
    -v "${ANSIBLE_DIR}:/etc/ansible:ro" \
    -v "${SCRIPT_DIR}/bootstrap:/tmp/bootstrap:ro" \
    ansible/ansible:latest \
    ansible-playbook -i /etc/ansible/inventory /etc/ansible/install_docker.yml

docker run --rm --name "${ANSIBLE_CONTAINER}" \
    -v "${ANSIBLE_DIR}:/etc/ansible:ro" \
    ansible/ansible:latest \
    ansible-playbook -i /etc/ansible/inventory /etc/ansible/init_swarm.yml

docker run --rm --name "${ANSIBLE_CONTAINER}" \
    -v "${ANSIBLE_DIR}:/etc/ansible:ro" \
    ansible/ansible:latest \
    ansible-playbook -i /etc/ansible/inventory /etc/ansible/provision_gluster.yml

echo ""

# ── Phase 3: Docker object setup ─────────────────────────────
echo "[Phase 3/4] Setting up Docker objects..."
echo "──────────────────────────────────────────────────────"
bash "${SCRIPT_DIR}/scripts/setup.sh"
echo ""

# ── Phase 4: Deploy stacks ───────────────────────────────────
echo "[Phase 4/4] Deploying service stacks..."
echo "──────────────────────────────────────────────────────"
bash "${SCRIPT_DIR}/scripts/deploy.sh"
echo ""

echo "======================================================"
echo " Provisioning complete!"
echo "======================================================"
