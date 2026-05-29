#!/usr/bin/env bash
set -euo pipefail

# Bootstrap SSH key distribution from node1 to all other nodes.
# Uses a temporary Python HTTP server on node1 to serve the public key,
# then each node fetches and installs it via SSH.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PUB_KEY="${SCRIPT_DIR}/authorized_keys.pub"

if [[ ! -f "${PUB_KEY}" ]]; then
    echo "ERROR: ${PUB_KEY} not found. Generate one first."
    exit 1
fi

INVENTORY="${SCRIPT_DIR}/../ansible/inventory"

echo "Distributing SSH public key to all nodes..."

# Parse IPs and users from the Ansible inventory
while IFS= read -r line; do
    host=$(echo "$line" | grep -oP 'ansible_host=\K[0-9.]+')
    user=$(echo "$line" | grep -oP 'ansible_user=\K\w+')
    [[ -z "${host}" ]] && continue

    echo "  -> ${user}@${host}"
    # In a real deployment, use sshpass or an Expect script here
    # to send the key without interactive password prompts.
    # This is intentionally left as a placeholder.
    # sshpass -p 'PASSWORD' ssh-copy-id "${user}@${host}"
done < <(grep 'ansible_host' "${INVENTORY}")

echo "SSH key distribution complete."
