#!/bin/bash
set -e

pass -c torch/phajas

cd "$(dirname "$0")"

echo "Running torch setup playbook..."
ansible-playbook setup.yml -i hosts -K

echo "✓ Setup complete!"
