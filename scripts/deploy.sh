#!/usr/bin/env bash
set -euo pipefail

# Phase 4: Stack Deployment
# Runs from the control machine, SSHing into node1 (Swarm manager)
# to deploy each stack via docker stack deploy.
#
# Iterates over stacks/*/docker-compose.yml and deploys each one.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
STACKS_DIR="${ROOT_DIR}/stacks"
INVENTORY="${ROOT_DIR}/ansible/inventory"

node_ip() {
    grep "^$1 " "${INVENTORY}" | grep -oP 'ansible_host=\K\S+' | head -1
}

node_user() {
    grep "^$1 " "${INVENTORY}" | grep -oP 'ansible_user=\K\S+' | head -1
}

echo "=== Phase 4: Stack Deployment ==="

node1_ip=$(node_ip "node1")
node1_user=$(node_user "node1")

for stack_dir in "${STACKS_DIR}"/*/; do
    stack_name=$(basename "${stack_dir}")
    compose_file="${stack_dir}/docker-compose.yml"

    if [[ -f "${compose_file}" ]]; then
        echo "Deploying stack: ${stack_name}"

        # Copy compose file to node1, deploy, clean up
        ssh -o StrictHostKeyChecking=no "${node1_user}@${node1_ip}" \
            "cat <<'COMPOSE_EOF' > /tmp/${stack_name}-compose.yml
$(cat "${compose_file}")
COMPOSE_EOF"

        ssh -o StrictHostKeyChecking=no "${node1_user}@${node1_ip}" \
            "docker stack deploy -c /tmp/${stack_name}-compose.yml ${stack_name} && rm /tmp/${stack_name}-compose.yml"

        echo "  ✓ ${stack_name} deployed"
    else
        echo "  ⚠ Skipping ${stack_name} — no docker-compose.yml found."
    fi
done

echo ""
echo "=== Phase 4 Complete ==="
echo ""
echo "Stack status:"
ssh -o StrictHostKeyChecking=no "${node1_user}@${node1_ip}" "docker stack ls"
