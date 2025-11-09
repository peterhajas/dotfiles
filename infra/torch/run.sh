#!/bin/bash
set -e

cd "$(dirname "$0")"

# Get password once and create JSON vars file
VARS_FILE=$(mktemp)
trap "rm -f $VARS_FILE" EXIT

echo "{\"ansible_become_pass\": \"$(pass torch/phajas | sed 's/"/\\"/g')\"}" > "$VARS_FILE"

echo "Running torch setup playbook..."
ansible-playbook setup.yml -i hosts -e "@$VARS_FILE"

echo ""
echo "Installing dependencies..."
ansible-playbook dependencies.yml -i hosts -e "@$VARS_FILE"

echo ""
echo "Configuring Podman storage..."
ansible-playbook configure_podman_storage.yml -i hosts -e "@$VARS_FILE"

echo ""
echo "Setting up Jellyfin..."
ansible-playbook service_jellyfin.yml -i hosts

echo ""
echo "Enabling rsync daemon..."
ansible-playbook enable_rsync_daemon.yml -i hosts -e "@$VARS_FILE"

echo ""
echo "✓ All setup complete!"
