# 󰣛 nerdy-motd

> Eine schöne, nerdige Message-of-the-Day für Linux-Server — mit Auto-Update
> direkt aus GitHub.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    _   _              _        ____
   | \ | | ___ _ __ __| |_   _ / ___|  ___ _ ____   _____ _ __
   |  \| |/ _ \ '__/ _` | | | |\___ \ / _ \ '__\ \ / / _ \ '__|
   | |\  |  __/ | | (_| | |_| | ___) |  __/ |   \ V /  __/ |
   |_| \_|\___|_|  \__,_|\__, ||____/ \___|_|    \_/ \___|_|
                         |___/

    Debian 12 (bookworm)  ·    Mon 19 May 2026 · 14:32:01 CEST

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ▎  System ─────────────────────────────────────────────────────────────
       OS           Debian 12 (bookworm)   up to date
       Kernel       6.1.0-21-amd64
       Uptime       3 days, 4 hours
       Load         0.42 · 0.51 · 0.48
       Users        2 logged in

  ▎  Resources ──────────────────────────────────────────────────────────
       CPU          [██████████░░░░░░░░░░░░░░]  42%
       Memory       [████████████████░░░░░░░░]  67%   3.2 / 4.8 GiB
       Disk /       [██████░░░░░░░░░░░░░░░░░░]  25%  12.0 / 48.0 GiB
       Temp         45°C

  ▎  Network ────────────────────────────────────────────────────────────
       IPv4         192.168.1.42   → router.local
       External     203.0.113.5    → mail.example.com    DE · Berlin

  ▎  Security ───────────────────────────────────────────────────────────
       Fail2Ban     ✓ active — 3 jails, 17 banned
       SSH (24h)    14 failed attempts
       Tor          ✓ active

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     Berlin: ☀ +18°C
     Talk is cheap. Show me the code. — Linus Torvalds
```

## Features

-  **Truecolor-Banner** (24-bit Gradient) mit Hostname via `figlet`
-  **Distro-Detection** über `/etc/os-release` (Debian, Ubuntu, Raspbian, Kali, Fedora, Arch, Alpine, …)
-  **Unicode-Balken** (█ ░) statt `#` für CPU / Memory / Disk
-  **Nerd-Font-Glyphs** für jedes Feld
-  **Geo-IP-Lookup** der externen IP (mit Reverse-DNS)
-  **Fail2Ban**-Status, gesperrte IPs, fehlgeschlagene SSH-Logins (24 h)
-  **Tor** und  **Docker** werden automatisch erkannt — keine extra Skripte mehr
-  **Wetter** (wttr.in) und Random-Nerd-Quote im Footer
-  **Caching** für teure HTTP-Calls (Geo-IP, External-IP, Release-Check)
-  **Dynamisches MOTD** via `/etc/update-motd.d/` — Werte sind beim Login immer frisch
-  **Auto-Update** aus GitHub (systemd-Timer, 4×/Tag)

---

## Installation (Debian / Ubuntu)

```bash
curl -fsSL https://raw.githubusercontent.com/koljasagorski/change-motd/main/set_motd.sh -o /tmp/set_motd.sh
sudo bash /tmp/set_motd.sh
```

Der Installer:

1. installiert die nötigen Pakete (`figlet`, `curl`, `jq`, `lm-sensors`, `fortunes-min`, …),
2. legt das bisherige `/etc/motd` unter `/var/backups/motd/` ab,
3. deaktiviert die Default-Skripte in `/etc/update-motd.d/`,
4. installiert
   - `/usr/local/bin/motd-generate` — den MOTD-Renderer,
   - `/usr/local/bin/motd-self-update` — den Auto-Updater,
   - `/etc/update-motd.d/01-nerdy-motd` — den Login-Hook,
   - `/etc/default/motd` — die Konfiguration,
5. aktiviert den **systemd-Timer** für Auto-Updates (s. u.).

Beim nächsten SSH-Login erscheint das neue MOTD.

---

##  Auto-Update: immer die neueste Version auf allen Servern

Der Installer richtet einen systemd-Timer ein, der das MOTD-Skript
**viermal täglich** (00:17, 06:17, 12:17, 18:17 lokale Zeit + bis zu 15 min
zufällige Verzögerung) direkt aus GitHub aktualisiert. Damit haben alle Server
in einer Flotte immer dieselbe Version, ohne dass man eintippen muss.

```
/etc/systemd/system/motd-self-update.timer   ← wann
/etc/systemd/system/motd-self-update.service ← was
/usr/local/bin/motd-self-update              ← wie
```

### Timer prüfen

```bash
systemctl status motd-self-update.timer
systemctl list-timers motd-self-update.timer
```

Beispiel-Output:

```
NEXT                        LEFT          LAST                        PASSED  UNIT
Mon 2026-05-19 18:23:14 CEST 3h 51min left Mon 2026-05-19 12:31:42 CEST 2h ago motd-self-update.timer
```

### Manuell ein Update auslösen

```bash
sudo systemctl start motd-self-update.service
sudo journalctl -u motd-self-update.service -n 20
```

### Wie funktioniert das Update?

`motd-self-update` lädt jede Datei aus
`https://raw.githubusercontent.com/<repo>/<branch>/<file>`, vergleicht die
SHA-256-Summe mit der lokalen Version und ersetzt die Datei nur, wenn sie sich
geändert hat. Bei Netzwerkfehlern wird mit exponentiellem Backoff (2 s → 16 s)
bis zu viermal wiederholt. Jeder erfolgreiche Update-Lauf landet im Journal:

```bash
journalctl -t motd-self-update --since today
```

### Auf eine eigene Fork / Branch pinnen

```bash
sudo tee -a /etc/default/motd >/dev/null <<'EOF'
MOTD_REPO="meine-org/change-motd"
MOTD_BRANCH="production"
EOF
sudo systemctl restart motd-self-update.timer
```

### Update-Frequenz ändern

```bash
sudo systemctl edit motd-self-update.timer
```

Override-Snippet, z. B. stündlich:

```ini
[Timer]
OnCalendar=
OnCalendar=hourly
```

### Auto-Update deaktivieren

```bash
sudo systemctl disable --now motd-self-update.timer
```

---

##  Konfiguration

Alle Einstellungen in **`/etc/default/motd`**:

| Variable               | Default                       | Beschreibung                                     |
| ---------------------- | ----------------------------- | ------------------------------------------------ |
| `MOTD_WEATHER_CITY`    | _(leer = aus)_                | Stadt für `wttr.in` (z. B. `Berlin`)             |
| `MOTD_CACHE_DIR`       | `/var/cache/motd`             | Cache-Verzeichnis                                |
| `MOTD_HTTP_TIMEOUT`    | `3`                           | Timeout (s) für externe HTTP-Calls               |
| `MOTD_REPO`            | `koljasagorski/change-motd`   | GitHub-Repo für Self-Update                      |
| `MOTD_BRANCH`          | `main`                        | Branch für Self-Update                           |

Änderungen wirken beim nächsten Login (MOTD wird bei jedem Login dynamisch gerendert).

---

##  Nerd-Font-Hinweis

Für die Icons (   ) wird auf dem **Client-Terminal** eine
[Nerd Font](https://www.nerdfonts.com/) empfohlen, z. B. `FiraCode Nerd Font`
oder `JetBrainsMono Nerd Font`. Ohne Nerd Font erscheinen kleine Platzhalter,
das Layout funktioniert aber weiter.

---

##  Manuell rendern

```bash
/usr/local/bin/motd-generate
```

---

##  Deinstallieren

```bash
sudo bash /tmp/set_motd.sh --uninstall
```

Stellt das vorherige `/etc/motd` und die originalen `update-motd.d`-Skripte wieder
her und deaktiviert den Auto-Update-Timer.

---

##  Optionen des Installers

| Flag                  | Wirkung                                                |
| --------------------- | ------------------------------------------------------ |
| `--no-timer`          | Installation **ohne** Auto-Update-Timer                |
| `--branch <name>`     | Aus einem anderen GitHub-Branch installieren           |
| `--uninstall`         | Alles entfernen, vorheriges MOTD wiederherstellen      |

---

##  Lizenz

MIT
