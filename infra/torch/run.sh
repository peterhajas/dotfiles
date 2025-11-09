#!/bin/bash
set -e

pass -c torch/phajas

cd "$(dirname "$0")"

echo "Running torch setup playbook..."
ansible-playbook setup.yml -i hosts -K

echo ""
echo "Installing dependencies..."
ansible-playbook dependencies.yml -i hosts -K

echo ""
echo "Configuring Podman storage..."
ansible-playbook configure_podman_storage.yml -i hosts -K

echo ""
echo "Setting up Jellyfin..."
ansible-playbook service_jellyfin.yml -i hosts

echo ""
echo "✓ All setup complete!"
