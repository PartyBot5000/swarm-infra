#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
STACKS_DIR="${ROOT_DIR}/stacks"

echo "=== Phase 4: Stack Deployment ==="

for stack_dir in "${STACKS_DIR}"/*/; do
    stack_name=$(basename "${stack_dir}")
    compose_file="${stack_dir}/docker-compose.yml"

    if [[ -f "${compose_file}" ]]; then
        echo "Deploying stack: ${stack_name}"
        docker stack deploy -c "${compose_file}" "${stack_name}"
    else
        echo "Skipping ${stack_name} — no docker-compose.yml found."
    fi
done

echo "=== Phase 4 Complete ==="
