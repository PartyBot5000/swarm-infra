#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo " Swarm Infrastructure — Full Provisioning"
echo "=========================================="
echo ""

# Phase 1: Bootstrap SSH keys
echo "[Phase 1/4] Bootstrapping SSH keys..."
bash "${SCRIPT_DIR}/bootstrap/bootstrap-node.sh"
echo ""

# Phase 2: Ansible infrastructure
echo "[Phase 2/4] Running Ansible playbooks..."
ansible-playbook "${SCRIPT_DIR}/ansible/install_docker.yml" -i "${SCRIPT_DIR}/ansible/inventory"
ansible-playbook "${SCRIPT_DIR}/ansible/init_swarm.yml"       -i "${SCRIPT_DIR}/ansible/inventory"
ansible-playbook "${SCRIPT_DIR}/ansible/provision_gluster.yml" -i "${SCRIPT_DIR}/ansible/inventory"
echo ""

# Phase 3: Docker object setup
echo "[Phase 3/4] Setting up Docker objects..."
bash "${SCRIPT_DIR}/scripts/setup.sh"
echo ""

# Phase 4: Deploy stacks
echo "[Phase 4/4] Deploying service stacks..."
bash "${SCRIPT_DIR}/scripts/deploy.sh"
echo ""

echo "=========================================="
echo " Provisioning complete!"
echo "=========================================="
