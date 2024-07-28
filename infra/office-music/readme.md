# phajas office-music config

## Getting Started

1. Make an account and change the password for the user.
2. Enable `sshd` with:
    sudo systemctl enable ssh.service
    sudo systemctl start ssh.service
3. Install `ansible` by doing an ssh in, and running:

    python3 -m ensurepip
    ~/.local/bin/pip3 install ansible-core

4. Copy `ssh` keys over with `ssh-copy-id orangepi@orangepizero3`
5. Do setup with:

    ansible-playbook setup.yml -i hosts -K
6. Enjoy.
