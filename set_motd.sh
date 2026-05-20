#!/usr/bin/env bash
# set_motd.sh — Installer for the nerdy MOTD generator.
# https://github.com/koljasagorski/change-motd
#
# Installs:
#   /usr/local/bin/motd-generate         — the MOTD renderer
#   /usr/local/bin/motd-self-update      — pulls latest version from GitHub
#   /etc/update-motd.d/01-nerdy-motd     — Debian/Ubuntu update-motd hook
#   /etc/default/motd                    — user-editable configuration
#   /etc/systemd/system/motd-self-update.{service,timer}
#
# Usage:
#   sudo ./set_motd.sh                 # install / upgrade everything
#   sudo ./set_motd.sh --uninstall     # restore previous MOTD
#   sudo ./set_motd.sh --no-timer      # install but don't enable auto-update
#   sudo ./set_motd.sh --branch <name> # install from a different GitHub branch

set -euo pipefail

# --- Configuration ----------------------------------------------------------

REPO="${MOTD_REPO:-koljasagorski/change-motd}"
BRANCH="${MOTD_BRANCH:-main}"
RAW_BASE="https://raw.githubusercontent.com/${REPO}/${BRANCH}"
BACKUP_DIR="/var/backups/motd"
ENABLE_TIMER=1
ACTION="install"

while (( $# > 0 )); do
    case "$1" in
        --uninstall) ACTION="uninstall" ;;
        --no-timer)  ENABLE_TIMER=0 ;;
        --branch)    BRANCH="${2:?--branch needs a value}"; RAW_BASE="https://raw.githubusercontent.com/${REPO}/${BRANCH}"; shift ;;
        --help|-h)
            sed -n '2,18p' "$0"
            exit 0
            ;;
        *) echo "Unknown argument: $1" >&2; exit 2 ;;
    esac
    shift
done

# --- Pretty output ----------------------------------------------------------

if [[ -t 1 ]]; then
    C_OK=$'\e[38;2;166;227;161m'; C_WARN=$'\e[38;2;249;226;175m'
    C_ERR=$'\e[38;2;243;139;168m'; C_INFO=$'\e[38;2;137;180;250m'
    C_DIM=$'\e[2m'; NC=$'\e[0m'
else
    C_OK=""; C_WARN=""; C_ERR=""; C_INFO=""; C_DIM=""; NC=""
fi
log()  { printf '%s[*]%s %s\n' "$C_INFO" "$NC" "$*"; }
ok()   { printf '%s[✓]%s %s\n' "$C_OK"   "$NC" "$*"; }
warn() { printf '%s[!]%s %s\n' "$C_WARN" "$NC" "$*"; }
err()  { printf '%s[✗]%s %s\n' "$C_ERR"  "$NC" "$*" >&2; }

require_root() {
    if [[ $EUID -ne 0 ]]; then
        err "Bitte als root oder mit sudo ausführen."
        exit 1
    fi
}

# --- Distro check -----------------------------------------------------------

detect_distro() {
    [[ -r /etc/os-release ]] || { err "/etc/os-release nicht gefunden — nicht unterstützt."; exit 1; }
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID:-}" in
        debian|ubuntu|raspbian|kali|linuxmint|pop)
            ok "Distro: ${PRETTY_NAME:-$ID}"
            ;;
        *)
            warn "Distro ${ID:-unknown} ist nicht offiziell getestet — Installation läuft weiter."
            ;;
    esac
}

# --- Dependency installer ---------------------------------------------------

PACKAGES=(figlet curl ca-certificates fortunes-min lsb-release bsdmainutils)
# Optional but recommended: jq for nicer geo-IP parsing.
OPTIONAL_PACKAGES=(jq lm-sensors)

install_packages() {
    log "Installiere Pakete: ${PACKAGES[*]}"
    DEBIAN_FRONTEND=noninteractive apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${PACKAGES[@]}" >/dev/null
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${OPTIONAL_PACKAGES[@]}" >/dev/null 2>&1 || true
    ok "Pakete installiert."
}

# --- Helpers ----------------------------------------------------------------

# Download a file. Falls back to local copy (when set_motd.sh runs from a clone).
fetch() {
    local rel="$1" dest="$2"
    local script_dir
    script_dir="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "${script_dir}/${rel}" ]]; then
        install -m 0755 -D "${script_dir}/${rel}" "$dest"
        log "Lokale Datei kopiert: ${rel} → ${dest}"
    else
        log "Lade von GitHub: ${rel}"
        curl -fsSL --retry 4 --retry-delay 2 --max-time 30 \
            "${RAW_BASE}/${rel}" -o "$dest.new"
        chmod 0755 "$dest.new"
        mv -f "$dest.new" "$dest"
    fi
}

backup_existing() {
    mkdir -p "$BACKUP_DIR"
    local ts
    ts="$(date +%Y%m%d-%H%M%S)"
    if [[ -s /etc/motd && ! -L /etc/motd ]]; then
        cp -a /etc/motd "$BACKUP_DIR/motd.$ts"
        ok "Backup: $BACKUP_DIR/motd.$ts"
    fi
    if [[ -d /etc/update-motd.d ]]; then
        tar -C /etc -czf "$BACKUP_DIR/update-motd.d.$ts.tgz" update-motd.d 2>/dev/null || true
    fi
}

disable_default_motd() {
    # Disable Debian/Ubuntu default scripts but don't delete them
    # — uninstall will re-enable them.
    if [[ -d /etc/update-motd.d ]]; then
        local f
        for f in /etc/update-motd.d/*; do
            [[ -f "$f" ]] || continue
            case "$(basename "$f")" in
                01-nerdy-motd) continue ;;
            esac
            chmod -x "$f" 2>/dev/null || true
        done
    fi
    # Replace static /etc/motd with an empty file so it doesn't double-print.
    : > /etc/motd
}

enable_default_motd() {
    if [[ -d /etc/update-motd.d ]]; then
        chmod +x /etc/update-motd.d/* 2>/dev/null || true
        rm -f /etc/update-motd.d/01-nerdy-motd
    fi
}

# --- Install ----------------------------------------------------------------

install_motd() {
    require_root
    detect_distro
    install_packages
    backup_existing
    disable_default_motd

    fetch "motd-generate"     /usr/local/bin/motd-generate
    fetch "motd-self-update"  /usr/local/bin/motd-self-update

    # update-motd.d hook (tiny wrapper, falls back gracefully).
    cat >/etc/update-motd.d/01-nerdy-motd <<'EOF'
#!/bin/sh
exec /usr/local/bin/motd-generate
EOF
    chmod 0755 /etc/update-motd.d/01-nerdy-motd

    # Config file with sensible defaults; only write if missing.
    if [[ ! -f /etc/default/motd ]]; then
        cat >/etc/default/motd <<EOF
# Configuration for /usr/local/bin/motd-generate
# Reload by simply logging in again.

# Weather city for the wttr.in line. Leave empty to disable.
MOTD_WEATHER_CITY=""

# Cache directory for expensive external calls.
MOTD_CACHE_DIR="/var/cache/motd"

# Timeout (seconds) for outbound HTTP requests.
MOTD_HTTP_TIMEOUT="3"

# GitHub repo for self-updates. Override to pin to a fork or branch.
MOTD_REPO="${REPO}"
MOTD_BRANCH="${BRANCH}"
EOF
        ok "/etc/default/motd geschrieben."
    fi

    mkdir -p /var/cache/motd
    chmod 0755 /var/cache/motd

    # systemd timer for self-updates.
    fetch "systemd/motd-self-update.service" /etc/systemd/system/motd-self-update.service
    fetch "systemd/motd-self-update.timer"   /etc/systemd/system/motd-self-update.timer
    chmod 0644 /etc/systemd/system/motd-self-update.{service,timer}

    systemctl daemon-reload
    if (( ENABLE_TIMER )); then
        systemctl enable --now motd-self-update.timer >/dev/null
        ok "Auto-Update aktiviert (systemd timer)."
    else
        warn "Auto-Update-Timer wurde nicht aktiviert (--no-timer)."
    fi

    ok "Installation abgeschlossen."
    printf '\n%s── Preview ──%s\n\n' "$C_DIM" "$NC"
    /usr/local/bin/motd-generate || true
    printf '\n%sNeu einloggen, um das MOTD beim Login zu sehen.%s\n' "$C_DIM" "$NC"
}

# --- Uninstall --------------------------------------------------------------

uninstall_motd() {
    require_root
    log "Deinstalliere nerdy-motd …"
    systemctl disable --now motd-self-update.timer 2>/dev/null || true
    rm -f \
        /etc/systemd/system/motd-self-update.service \
        /etc/systemd/system/motd-self-update.timer \
        /etc/update-motd.d/01-nerdy-motd \
        /usr/local/bin/motd-generate \
        /usr/local/bin/motd-self-update
    systemctl daemon-reload 2>/dev/null || true
    enable_default_motd
    # Restore the most recent /etc/motd backup, if any.
    local latest
    latest="$(ls -1t "$BACKUP_DIR"/motd.* 2>/dev/null | head -n1 || true)"
    if [[ -n "$latest" ]]; then
        cp -a "$latest" /etc/motd
        ok "Vorheriges /etc/motd wiederhergestellt: $latest"
    fi
    ok "Deinstallation abgeschlossen."
}

case "$ACTION" in
    install)   install_motd ;;
    uninstall) uninstall_motd ;;
esac
