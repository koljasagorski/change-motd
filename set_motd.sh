#!/bin/bash

# Pfad zur MOTD-Datei
MOTD_FILE="/etc/motd"

# Informationen sammeln
HOSTNAME=$(hostname)
OS_VERSION=$(lsb_release -d | awk -F'\t' '{print $2}')
KERNEL=$(uname -r)
UPTIME=$(uptime -p)
USERS=$(who -q | tail -n 1 | awk '{print $2}')
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
MEMORY_USAGE=$(free -m | awk '/Mem:/ { printf("%.0f"), $3/$2*100 }')
DISK_USAGE=$(df -h / | awk '/\// {print $5}' | sed 's/%//')
LOAD_AVERAGE=$(cat /proc/loadavg | awk '{print $1}')
IPV4_ADDRESS=$(hostname -I | awk '{print $1}')
IPV6_ADDRESS=$(ip -6 addr show scope global | grep inet6 | awk '{print $2}' | cut -d'/' -f1 | head -n 1)
EXTERNAL_IP=$(curl -s ifconfig.me)
UPDATES=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
SECURITY_UPDATES=$(apt list --upgradable 2>/dev/null | grep -i security | wc -l)
DATE=$(date)

# Fail2Ban Status
FAIL2BAN_STATUS=$(systemctl is-active fail2ban)

# Laufende Prozesse
PROCESS_LIST=$(ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n 10)

# Laufende Dienste
SERVICES=($(systemctl list-units --type=service --state=running --no-pager | awk '{print $1}' | tail -n +2))

# Informationen zum letzten Login
LAST_LOGIN=$(last -i -n 1 | head -n 1)
LAST_USER=$(echo "$LAST_LOGIN" | awk '{print $1}')
LAST_IP=$(echo "$LAST_LOGIN" | awk '{print $3}')
LAST_TIME=$(echo "$LAST_LOGIN" | awk '{print $4, $5, $6, $7}')
LAST_TERMINAL=$(echo "$LAST_LOGIN" | awk '{print $2}')
LAST_DURATION=$(echo "$LAST_LOGIN" | awk '{print $10}')

# Betriebssystemversion
CURRENT_VERSION=$(lsb_release -r | awk '{print $2}')
if [[ "$OS_VERSION" == *"Ubuntu"* ]]; then
    VERSION_LATEST=$(curl -s "https://releases.ubuntu.com/" | grep -Po 'Ubuntu \K[0-9]+\.[0-9]+' | sort -V | tail -n 1)
elif [[ "$OS_VERSION" == *"Debian"* ]]; then
    VERSION_LATEST=$(curl -s "https://www.debian.org/releases/" | grep -Po 'Debian GNU/Linux \K[0-9]+' | sort -V | tail -n 1)
else
    VERSION_LATEST="Unbekannt"
fi

# Funktion zur farbigen Ausgabe des Betriebssystemstatus und Upgrade-Hinweis
function display_os_version_status {
    if [ "$CURRENT_VERSION" = "$VERSION_LATEST" ]; then
        echo -e "\e[32m$OS_VERSION (aktuell)\e[0m"  # Grün für die neueste Version
    else
        echo -e "\e[31m$OS_VERSION (nicht aktuell - neueste Version: $VERSION_LATEST)\e[0m"  # Rot für veraltete Version
        if [[ "$OS_VERSION" == *"Ubuntu"* ]]; then
            echo -e "Zum Upgrade auf die neueste Version verwenden Sie: \e[34msudo do-release-upgrade\e[0m"
        elif [[ "$OS_VERSION" == *"Debian"* ]]; then
            echo -e "Zur Aktualisierung auf die neueste Version ändern Sie die Quellenliste und verwenden Sie:\n\e[34msudo apt update && sudo apt full-upgrade\e[0m"
        fi
    fi
}

# Funktion zur Erstellung eines farbigen ASCII-Balkens
function draw_bar {
    local usage=$1
    local bar_length=20
    local filled_length=$(( usage * bar_length / 100 ))
    local bar=$(printf "%-${bar_length}s" "#" | tr ' ' '#')
    
    # Färbung basierend auf Auslastung
    if [ "$usage" -lt 50 ]; then
        color="\e[32m"  # Grün für niedrige Auslastung
    elif [ "$usage" -lt 80 ]; then
        color="\e[33m"  # Gelb für mittlere Auslastung
    else
        color="\e[31m"  # Rot für hohe Auslastung
    fi

    echo -e "[${color}${bar:0:filled_length}\e[0m\e[90m${bar:filled_length:$((bar_length-filled_length))}\e[0m] $usage%"
}

# Funktion zur farbigen Ausgabe des Fail2Ban-Status und Statistiken
function display_fail2ban_status {
    if [ "$FAIL2BAN_STATUS" = "active" ]; then
        echo -e "\e[32mFail2Ban ist aktiv\e[0m"
        
        # Anzeige der Jails und der gesperrten IP-Adressen
        JAILS=$(fail2ban-client status | grep 'Jail list:' | cut -d ':' -f2 | tr -d ',' | xargs)
        for JAIL in $JAILS; do
            BANNED_IPS=$(fail2ban-client status "$JAIL" | grep 'Banned IP list:' | cut -d ':' -f2)
            BAN_COUNT=$(echo "$BANNED_IPS" | wc -w)
            echo -e "\e[34mJail: $JAIL - Gesperrte IPs: $BAN_COUNT\e[0m"
            if [ "$BAN_COUNT" -gt 0 ]; then
                echo -e "\e[90m$BANNED_IPS\e[0m"
            fi
        done
    else
        echo -e "\e[31mFail2Ban ist inaktiv\e[0m"
    fi
}

# Funktion zur Anzeige von IP-Adresse, Hostname und whois-Link unter der IP
function display_ip_info {
    local ip=$1
    if [[ -n "$ip" ]]; then
        local hostname=$(host "$ip" | awk '/domain name pointer/ {print $5}' | sed 's/\.$//')
        local whois_link="https://who.is/whois-ip/ip-address/$ip"
        
        if [[ -z "$hostname" ]]; then
            hostname="N/A"
        fi
        
        echo -e "$ip (Hostname: $hostname)\nWhois: \e[34m$whois_link\e[0m"
    else
        echo "IP-Adresse nicht verfügbar"
    fi
}

# MOTD erstellen
echo "Willkommen auf $HOSTNAME!" | sudo tee $MOTD_FILE
echo "Datum und Uhrzeit: $DATE" | sudo tee -a $MOTD_FILE
echo "" | sudo tee -a $MOTD_FILE

echo "Systeminformationen:" | sudo tee -a $MOTD_FILE
echo "---------------------" | sudo tee -a $MOTD_FILE

# Systeminformationen untereinander anzeigen
{
    printf "%-20s : %s\n" "Betriebssystem" "$(display_os_version_status)"
    printf "%-20s : %s\n" "Kernel-Version" "$KERNEL"
    printf "%-20s : %s\n" "Systemlaufzeit" "$UPTIME"
    printf "%-20s : %s\n" "Angemeldete Benutzer" "$USERS"
    printf "%-20s : %s\n" "IPv4-Adresse" "$(display_ip_info $IPV4_ADDRESS)"
    printf "%-20s : %s\n" "IPv6-Adresse" "$(display_ip_info $IPV6_ADDRESS)"
    printf "%-20s : %s\n" "Externe IP-Adresse" "$(display_ip_info $EXTERNAL_IP)"
    printf "%-20s : %s\n" "Systemlast" "$LOAD_AVERAGE"
    printf "%-20s : %s\n" "Fail2Ban Status" "$(display_fail2ban_status)"
} | sudo tee -a $MOTD_FILE
echo "" | sudo tee -a $MOTD_FILE

echo "Ressourcennutzung:" | sudo tee -a $MOTD_FILE
echo "------------------" | sudo tee -a $MOTD_FILE

# Ressourcen als ASCII-Balkendiagramme
{
    printf "%-20s : %-30s\n" "CPU-Auslastung" "$(draw_bar $CPU_USAGE)"
    printf "%-20s : %-30s\n" "Speicherauslastung" "$(draw_bar $MEMORY_USAGE)"
    printf "%-20s : %-30s\n" "Festplattennutzung" "$(draw_bar $DISK_USAGE)"
} | sudo tee -a $MOTD_FILE
echo "" | sudo tee -a $MOTD_FILE

echo "Systemaktualisierungen:" | sudo tee -a $MOTD_FILE
echo "------------------------" | sudo tee -a $MOTD_FILE
printf "%-20s : %-30s\n" "Verfügbare Updates" "$UPDATES"
printf "%-20s : %-30s\n" "Sicherheitsupdates" "$SECURITY_UPDATES"
echo "" | sudo tee -a $MOTD_FILE

echo "Laufende Dienste:" | sudo tee -a $MOTD_FILE
echo "-----------------" | sudo tee -a $MOTD_FILE

# Zweispalten-Anzeige der Dienste
SERVICE_COUNT=${#SERVICES[@]}
MID=$(( (SERVICE_COUNT + 1) / 2 ))

for (( i=0; i<$MID; i++ )); do
    LEFT="${SERVICES[$i]}"
    RIGHT="${SERVICES[$((i + MID))]}"
    printf "%-40s %-40s\n" "$LEFT" "$RIGHT" | sudo tee -a $MOTD_FILE
done
echo "" | sudo tee -a $MOTD_FILE

echo "Letzter Login:" | sudo tee -a $MOTD_FILE
echo "--------------" | sudo tee -a $MOTD_FILE
printf "%-15s : %-30s\n" "Benutzer" "$LAST_USER" | sudo tee -a $MOTD_FILE
printf "%-15s : %-30s\n" "IP-Adresse" "$(display_ip_info $LAST_IP)" | sudo tee -a $MOTD_FILE
printf "%-15s : %-30s\n" "Zeitpunkt" "$LAST_TIME" | sudo tee -a $MOTD_FILE
printf "%-15s : %-30s\n" "Terminal" "$LAST_TERMINAL" | sudo tee -a $MOTD_FILE
printf "%-15s : %-30s\n" "Dauer" "$LAST_DURATION" | sudo tee -a $MOTD_FILE
echo "" | sudo tee -a $MOTD_FILE

echo "Top Prozesse:" | sudo tee -a $MOTD_FILE
echo "-------------" | sudo tee -a $MOTD_FILE
echo "$PROCESS_LIST" | sudo tee -a $MOTD_FILE
echo "" | sudo tee -a $MOTD_FILE

echo "Viel Erfolg beim Arbeiten!" | sudo tee -a $MOTD_FILE
