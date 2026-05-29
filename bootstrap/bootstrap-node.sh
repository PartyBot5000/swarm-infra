#!/usr/bin/env bash
set -euo pipefail

# Bootstrap SSH key distribution from control machine to all cluster nodes.
# Accepts credentials from the Ansible inventory and uses sshpass to
# push the control machine's public key to every node.
#
# Usage: ./bootstrap-node.sh /path/to/inventory

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

INVENTORY="${1:-${ROOT_DIR}/ansible/inventory}"

if [[ ! -f "${INVENTORY}" ]]; then
    echo "ERROR: Inventory not found at ${INVENTORY}"
    exit 1
fi

# Generate control-machine SSH keypair if it doesn't exist
SSH_KEY="${HOME}/.ssh/id_ed25519"
if [[ ! -f "${SSH_KEY}" ]]; then
    echo "Generating SSH keypair for control machine..."
    ssh-keygen -t ed25519 -f "${SSH_KEY}" -N "" -q
fi
PUB_KEY="${SSH_KEY}.pub"

# Ensure sshpass is available (should be present in the ansible container)
if ! command -v sshpass &>/dev/null; then
    echo "ERROR: sshpass not found. Run from the ansible container."
    exit 1
fi

echo "Distributing SSH public key to all cluster nodes..."
echo "Control machine key: ${PUB_KEY}"
echo ""

FAILED=()

while IFS= read -r line; do
    # Skip comments and group headers
    [[ "${line}" =~ ^#.*$ || "${line}" =~ ^\[.*\]$ || -z "${line}" ]] && continue

    host=$(echo "${line}" | grep -oP 'ansible_host=\K\S+')
    user=$(echo "${line}" | grep -oP 'ansible_user=\K\S+')
    password=$(echo "${line}" | grep -oP 'ansible_password=\K\S+' || echo "")

    [[ -z "${host}" ]] && continue

    echo "  → ${user}@${host} ..."
    if sshpass -p "${password}" ssh-copy-id -o StrictHostKeyChecking=no "${user}@${host}" 2>/dev/null; then
        echo "     ✓ SSH key installed"
    else
        echo "     ✗ FAILED — will retry later"
        FAILED+=("${user}@${host}:${password}")
    fi
done < "${INVENTORY}"

# Retry failures
if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo ""
    echo "Retrying failed nodes..."
    for entry in "${FAILED[@]}"; do
        user=$(echo "${entry}" | cut -d: -f1 | cut -d@ -f1)
        host=$(echo "${entry}" | cut -d: -f1 | cut -d@ -f2)
        password=$(echo "${entry}" | cut -d: -f2)

        echo "  → ${user}@${host} (retry) ..."
        if sshpass -p "${password}" ssh-copy-id -o StrictHostKeyChecking=no "${user}@${host}" 2>/dev/null; then
            echo "     ✓ SSH key installed (retry)"
        else
            echo "     ✗ STILL FAILED — manual intervention required"
        fi
    done
fi

echo ""
echo "Bootstrap complete. All nodes should now accept key-based SSH from the control machine."
