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

## Pending / open decisions

- **Tailscale zone is fully open.** `tailscale0` sits in the firewalld `trusted` zone, so every port (including
  enabled NAS services) is reachable from anywhere on the tailnet. Accepted for now; tighten (e.g. a dedicated
  zone with explicit services, or Tailscale ACLs) as needs appear.
- **User/SSH-key provisioning is not wired up.** sshd is key-only and root login is off, so a fresh install has no
  SSH access until a user and key exist. Options (see below); none is baked into the CI ISO yet.
- **Not yet built or booted.** Recipe, package names, `kargs.d` and the update-timer drop-in are only statically
  checked (`tests/run.sh`); verify in a bootc VM after the first CI build (see the design spec).

### User provisioning options

- **ISO via bootc-image-builder** (bare metal): a `config.toml` with `[[customizations.user]]` (`name`, `key`,
  optional `password`, `groups`), or a custom kickstart via `customizations.installer.kickstart.contents`. The two
  are mutually exclusive. Prefer an SSH `key`: a `password` is stored in plain text in the config and the ISO.
- **cloud-init** (installed): works on VMs/cloud with a datasource; on bare metal it needs a NoCloud seed
  (a volume labelled `CIDATA`). Ignition is not available on CentOS bootc.
- **Cockpit** still accepts the account password (PAM), independent of the sshd key-only setting.
