# phajas office-music config

## Getting Started

1. Change the password for the `orangepi` user to something reasonable with `pass`
2. Enable `sshd` with `sudo systemctl start sshd`
3. Install `ansible` by doing an ssh in, and running:

    python3 -m ensurepip
    ~/.local/bin/pip3 install ansible-core

4. Copy `ssh` keys over with `ssh-copy-id orangepi@orangepizero3`
5. Test out config with 

    ansible-playbook stats.yml -i hosts -K

6. Do setup with:

    ansible-playbook setup.yml -i hosts -K

7. Disable ssh with:

    ansible-playbook cleanup.yml -i hosts -K
