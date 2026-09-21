# Cloche PRO Server: NAS Quadlets

The image installs **no NAS software on the host**. Example container Quadlets live in
`/usr/share/cloche-server/quadlets/` and are **disabled**: that path is not read by Quadlet.

## Enabling a service (per machine)

1. Copy the files you want into `/etc/containers/systemd/` (Nextcloud needs the `nextcloud.pod` and every `nextcloud-*.container`).
2. Edit `Volume=` to your mount point, and create the env file the Quadlet names under `/etc/cloche-server/`
   (`nextcloud.env.example` is a template).
3. `systemctl daemon-reload && systemctl start <name>` (`samba`, `syncthing`, `nextcloud-pod`).
   Copied Quadlets have `[Install]` sections, so they also start on boot.
4. Open the ports it needs. Each Quadlet has the `firewall-cmd` line in its header comment.

Services: Samba (SMB, 445), Syncthing (22000, 21027/udp, UI 8384), Nextcloud (app + PostgreSQL + Redis,
8080). Nextcloud has no reverse proxy or TLS; add Tailscale Serve or Caddy.

## Things to know

- **Firewall:** the default zone is `public` (ssh + cockpit). No NAS port is open until you open it.
  The `tailscale0` interface is in the `trusted` zone, so every port is reachable **over the tailnet**
  regardless of the public zone.
- **Storage:** the image takes no position. Mount disks per machine via Cockpit (Storage) or systemd
  mount units, e.g. at `/var/srv/nas`. `smartmontools` is installed.
- **SELinux:** data mounted from the host needs `:Z` (private) or `:z` (shared) on `Volume=`. A missing
  relabel is the usual cause of "Permission denied" inside the container.
- **SSH is key-only** and root login is off. Provide `authorized_keys` (e.g. cloud-init) before relying on it.
- **Updates:** `bootc-fetch-apply-updates.timer` runs Sundays at 04:00 and reboots into the new image.
- **Laptop:** lid close, idle and suspend/hibernate are disabled; the console blanks after 60 s.
