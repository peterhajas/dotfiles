# phajas office_music config

## Getting Started

1. Download "Minimal/IOT image" from [here](https://www.armbian.com/orange-pi-zero-3/) and `dd` it onto an SD card.
2. `ssh` in with password `1234`:
    ssh root@orangepizero3
3. Upon login, Armbian will run a little wizard.
4. Set root password to something very secure.
5. Make a `phajas` account and change the password for the user.
    * Make it another very secure password.
6. Enable `sshd` with:
    sudo systemctl enable ssh.service
    sudo systemctl start ssh.service
7. Copy `ssh` keys over with `ssh-copy-id phajas@orangepizero3`
8. Do setup with:
    ansible-playbook setup.yml -i hosts -K
9. Before shutting down, run `armbian-config` to set up wifi
10. Shut down with:
    ansible-playbook shutdown.yml -i hosts -K
11. Enjoy.

## TODO

`uxplay` systemd service [like this](https://github.com/FDH2/UxPlay/issues/269#issuecomment-1916453728)
