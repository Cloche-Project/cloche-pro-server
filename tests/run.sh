#!/usr/bin/env bash
# Static checks for cloche-pro-server: recipe shape and shipped config files.
# No build or network needed. Run from anywhere: ./tests/run.sh

set -uo pipefail
cd "$(dirname "$0")/.."

fail=0
check() {
    local name="$1"; shift
    if "$@" >/dev/null 2>&1; then echo "PASS  $name"; else echo "FAIL  $name"; fail=1; fi
}
has() { grep -qE "$1" "$2"; }

R=recipes/cloche-pro-server.yml
S=files/system
Q=$S/usr/share/cloche-server/quadlets

recipe_ok() {
    python3 - "$R" <<'PY'
import sys, yaml
r = yaml.safe_load(open(sys.argv[1]))
assert r["name"] == "cloche-pro-server"
assert r["base-image"] == "ghcr.io/cloche-project/cloche-pro"
types = [m["type"] for m in r["modules"]]
assert types == ["os-release", "containerfile", "files", "systemd"], types
sd = next(m for m in r["modules"] if m["type"] == "systemd")["system"]
for u in ("sshd.service", "cockpit.socket", "tailscaled.service", "firewalld.service",
          "podman-auto-update.timer", "bootc-fetch-apply-updates.timer"):
    assert u in sd["enabled"], u
for u in ("sleep.target", "suspend.target", "hibernate.target", "hybrid-sleep.target"):
    assert u in sd["masked"], u
osr = next(m for m in r["modules"] if m["type"] == "os-release")["properties"]
assert "ID" not in osr, "ID must stay commented out (bootc-image-builder)"
PY
}

quadlets_ok() {
    local f
    for f in samba.container syncthing.container nextcloud.pod nextcloud-db.container \
             nextcloud-redis.container nextcloud-app.container nextcloud.env.example; do
        [ -f "$Q/$f" ] || return 1
    done
    for f in "$Q"/*.container; do has '^Image=' "$f" && has '^\[Container\]' "$f" || return 1; done
    has '^\[Pod\]' "$Q/nextcloud.pod" || return 1
    # every host volume must be SELinux-relabelled
    ! grep -E '^Volume=' "$Q"/*.container | grep -vE ':[zZ]$'
}

check "recipe shape"                recipe_ok
check "sshd key-only"               has '^PasswordAuthentication no' $S/etc/ssh/sshd_config.d/10-cloche-server.conf
check "sshd no root"                has '^PermitRootLogin no' $S/etc/ssh/sshd_config.d/10-cloche-server.conf
check "lid switch ignored"          has '^HandleLidSwitch=ignore' $S/etc/systemd/logind.conf.d/10-cloche-server.conf
check "lid ignored on power+dock"   bash -c "grep -q '^HandleLidSwitchExternalPower=ignore' $S/etc/systemd/logind.conf.d/10-cloche-server.conf && grep -q '^HandleLidSwitchDocked=ignore' $S/etc/systemd/logind.conf.d/10-cloche-server.conf"
check "update window Sunday 04:00"  has '^OnCalendar=Sun \*-\*-\* 04:00:00' $S/etc/systemd/system/bootc-fetch-apply-updates.timer.d/10-cloche-server.conf
check "consoleblank karg"           has 'consoleblank=60' $S/usr/lib/bootc/kargs.d/10-cloche-server.toml
check "tailscale0 in trusted zone"  has 'interface name="tailscale0"' $S/etc/firewalld/zones/trusted.xml
check "nas quadlets + :Z volumes"   quadlets_ok
check "nas readme shipped"          test -f $S/usr/share/cloche-server/README.md
check "no nas host packages"        bash -c "! grep -qE '^\s+(samba|nfs-utils|zfs)' $R"

exit $fail
