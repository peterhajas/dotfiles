# torch - NAS Infrastructure

This directory contains Ansible playbooks for configuring `torch`, the NAS.

## Setup

Run the setup script:

```bash
./run.sh
```

This will:
- Install and configure Tailscale
- Install common dependencies (podman, htop, fish, git, etc.)
- Configure podman for rootless containers with hardware acceleration
- Set up all services

## What's Configured

- **Tailscale**: VPN for secure remote access
- **Podman**: Rootless container runtime with overlay storage driver
- **Hardware Acceleration**: Intel UHD Graphics QuickSync support via `/dev/dri`
- **User Groups**: phajas added to `render` and `video` groups for GPU access
- **Linger**: Enabled so containers run even when user is not logged in
- **Subordinate UIDs/GIDs**: Configured for proper rootless container support

## Services

- **Jellyfin** (`service_jellyfin.yml`): Media server with hardware transcoding
  - Accessible at http://torch:8096
  - Media mounted readonly from `/volume1/media`
- **Navidrome** (`service_navidrome.yml`): Music streaming server
  - Accessible at http://torch:4533
  - Music mounted readonly from `/volume1/media/music`

## Standard Pattern for Container Services

All container services follow this pattern for automatic startup on boot:

```yaml
---
- name: Setup [Service Name]
  hosts: torch
  become: false  # Run as phajas user
  tasks:
    - name: Create service directories
      file:
        path: /home/phajas/services/servicename
        state: directory

    - name: Create [Service] container
      containers.podman.podman_container:
        name: servicename
        image: docker.io/image:latest
        restart_policy: always
        recreate: true
        ports:
          - "port:port"
        volumes:
          - /home/phajas/services/servicename/data:/data
        env:
          TZ: America/Los_Angeles
        generate_systemd:
          path: /home/phajas/.config/systemd/user/
          restart_policy: always
          new: true

    - name: Enable [Service] systemd service
      ansible.builtin.systemd:
        name: container-servicename
        enabled: yes
        scope: user
        daemon_reload: yes
```

### Key Components

1. **`become: false`** - Always run as phajas user (rootless)
2. **`restart_policy: always`** - Container restarts if it crashes
3. **`recreate: true`** - Recreate container on playbook re-runs (for updates)
4. **`generate_systemd`** - Creates systemd user service unit file
5. **`scope: user`** - Enables service at user level
6. **Linger enabled** - Ensures containers start on boot without login

### Adding Hardware Acceleration

For containers that need GPU access (transcoding, etc.), add both device passthrough and group access:

```yaml
device:
  - /dev/dri:/dev/dri
group_add:
  - "44"   # video group (GID on torch)
  - "105"  # render group (GID on torch)
```

This ensures the container process can access the GPU devices in rootless mode.

### Read-only Mounts

For media or other read-only data:

```yaml
volumes:
  - /volume1/media:/media:ro
```

## Manual Container Management

```bash
# List containers
podman ps -a

# View logs
podman logs jellyfin

# Restart container
podman restart jellyfin

# Check systemd service status
systemctl --user status container-jellyfin

# View systemd logs
journalctl --user -u container-jellyfin
```

## Notes

- All containers run rootless as the `phajas` user
- Container data stored in `/home/phajas/services/`
- Systemd unit files in `/home/phajas/.config/systemd/user/`
- Password managed via `pass torch/phajas`
