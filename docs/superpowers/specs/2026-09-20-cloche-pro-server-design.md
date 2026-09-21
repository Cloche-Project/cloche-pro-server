# cloche-pro-server — design

## Goal

A new bootc image, `ghcr.io/cloche-project/cloche-pro-server`, built on `ghcr.io/cloche-project/cloche-pro`
(CentOS Stream 10 bootc base). It targets the maintainer's homelab servers, some of which are laptops
running headless.

Primary role: **container host** (Podman + Quadlet/systemd). No virtualization, no Kubernetes, no NAS stack.

## Structure

New repo `cloche-pro-server`, same shape as `cloche-pro-workstation`:

- `recipes/cloche-pro-server.yml`
- `files/system/{etc,usr}` overlay
- `.github/workflows/{build,build-iso}.yml`, copied from `cloche-pro-workstation` with the recipe name adapted
- `tests/`, `README.md`

Base image: `ghcr.io/cloche-project/cloche-pro`, `image-version: latest`.

### Recipe module order

1. `os-release`: `NAME: Cloche PRO Server`; `ID` stays commented out (it broke bootc-image-builder before).
2. `containerfile`: `dnf install` of the packages below, plus the Tailscale repo.
3. `files`: overlay from `files/system`. It runs after `dnf`, as in the workstation. There are no
   `cloche-*-defaults` RPMs here, so nothing gets shadowed.
4. `systemd`: enable the services below and mask the sleep targets.

No GNOME, Plasma, `cloche-*-defaults` or wallpapers, on purpose.

## Packages (dnf, in the containerfile)

- Containers: `podman`, `podman-compose`, `buildah`, `skopeo`, `crun`, `netavark`, `aardvark-dns`
- Cockpit: `cockpit`, `cockpit-podman`, `cockpit-storaged`, `cockpit-networkmanager`
- Access and CLI: `openssh-server`, `tmux`, `btop`, `git`, `zsh`
- Provisioning: `cloud-init` (the supported first-boot path on bootc; Ignition is not used)
- Network and system: `tailscale` (official repo), `firewalld`, `chrony`, `smartmontools`

## Services

Enabled: `sshd`, `cockpit.socket`, `tailscaled`, `firewalld`, `chronyd`, `podman-restart.service`,
`podman-auto-update.timer`, plus `bootc-fetch-apply-updates.timer` inherited from the base.

Firewall: default zone `public`, allowing only ssh, cockpit and the Tailscale interface.

SSH: drop-in in `sshd_config.d` with `PasswordAuthentication no` and `PermitRootLogin no`.

## Updates

A drop-in for `bootc-fetch-apply-updates.timer` schedules fetch and reboot for **Sunday 04:00**, so the
reboot never lands at an arbitrary time.

## Laptop-as-server behavior

1. `/etc/systemd/logind.conf.d/10-cloche-server.conf`: `HandleLidSwitch=ignore`,
   `HandleLidSwitchExternalPower=ignore`, `HandleLidSwitchDocked=ignore`, `IdleAction=ignore`.
2. Mask `sleep.target`, `suspend.target`, `hibernate.target`, `hybrid-sleep.target`.
3. `/usr/lib/bootc/kargs.d/10-cloche-server.toml` with `consoleblank=60`: the console blanks after 60 s
   and wakes on a keypress. The machines are headless, so the screen is only used occasionally.

## Verification

- `tests/`: validate the recipe YAML and check that the `files/` drop-ins exist with the expected keys.
- CI: build and Cosign-sign as in the other repos.
- After a build, boot the image in a bootc VM and check that:
  - the enabled services are active;
  - `systemctl suspend` fails because the target is masked;
  - `loginctl`/logind reports lid-switch handling as `ignore`;
  - `/proc/cmdline` contains `consoleblank=60`;
  - the SSH drop-in is in effect (`sshd -T`).

## Out of scope

Virtualization (libvirt), Kubernetes nodes, NAS/storage stack, desktop environments, custom RPMs from `rpm-repo`.
