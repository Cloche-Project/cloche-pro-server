<p align="center">
  <picture>
    <img src="cloche-logo/watermark.png" alt="Cloche OS Logo" height="80" />
  </picture>
</p>

<p align="center">
    <strong>bootc Server Image</strong>
</p>

<p align="center">
  <strong>Cloche PRO Server</strong> is a headless, container-host bootc image built on
  <a href="https://github.com/cloche-project/cloche-pro"><code>cloche-pro</code></a> (CentOS Stream 10), aimed at homelab servers.
</p>

> [!NOTE]
> Like the rest of Cloche PRO, this is `bootc` over CentOS Stream with plain `dnf install` in the
> containerfile, not `rpm-ostree` over Fedora. Published as `ghcr.io/cloche-project/cloche-pro-server`.

## What's in it

| Area | Details |
|------|---------|
| **Containers** | Podman, podman-compose, Buildah, Skopeo, Quadlet; `podman-restart` and `podman-auto-update.timer` enabled |
| **Admin** | key-only SSH (no root login), Cockpit (podman, storage, network), tmux, btop, zsh |
| **Network** | Tailscale, firewalld (`public`: ssh + cockpit; `tailscale0` in `trusted`), chrony |
| **Provisioning** | cloud-init for first-boot user/keys/hostname |
| **Updates** | `bootc-fetch-apply-updates.timer` fetches and reboots **Sundays 04:00** |
| **Laptop as server** | lid close/idle ignored, sleep/suspend/hibernate masked, console blanks after 60 s |
| **NAS** | No host software. Optional, disabled container Quadlets: Samba, Syncthing, Nextcloud (full stack) |

The NAS Quadlets ship in `/usr/share/cloche-server/quadlets/` with a README next to them explaining
activation, firewall ports, storage and SELinux (`:Z`). Source: [files/system/usr/share/cloche-server/](files/system/usr/share/cloche-server/README.md).

## Layout

- `recipes/cloche-pro-server.yml`: `os-release` → `containerfile` (dnf) → `files` → `systemd`
- `files/system/{etc,usr}`: overlay (sshd, logind, update timer, firewalld, kargs, NAS Quadlets)
- `tests/run.sh`: static checks of the recipe and shipped config, no build needed
- `docs/superpowers/specs/`: design spec

## Setup notes

- CI needs the `SIGNING_SECRET` repo secret (Cosign private key matching `cosign.pub`).
- `ID` in `os-release` stays commented out: enabling it broke bootc-image-builder before.
