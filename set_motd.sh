#!/bin/bash

# Pfad zur MOTD-Datei
MOTD_FILE="/etc/motd"

# Informationen sammeln
HOSTNAME=$(hostname)
OS_VERSION=$(lsb_release -d | awk -F'\t' '{print $2}')
KERNEL=$(uname -r)
UPTIME=$(uptime -p)
USERS=$(who -q | tail -n 1 | awk '{print $2}')
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')
MEMORY_USAGE=$(free -m | awk '/Mem:/ { printf("%.2f%%"), $3/$2*100 }')
DISK_USAGE=$(df -h / | awk '/\// {print $5}')
LOAD_AVERAGE=$(cat /proc/loadavg | awk '{print $1}')
IP_ADDRESS=$(hostname -I | awk '{print $1}')
EXTERNAL_IP=$(curl -s ifconfig.me)
UPDATES=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
SECURITY_UPDATES=$(apt list --upgradable 2>/dev/null | grep -i security | wc -l)
DATE=$(date)

# MOTD erstellen
echo "Willkommen auf $HOSTNAME!" | sudo tee $MOTD_FILE
echo "Datum und Uhrzeit: $DATE" | sudo tee -a $MOTD_FILE
echo "" | sudo tee -a $MOTD_FILE

echo "Systeminformationen:" | sudo tee -a $MOTD_FILE
echo "---------------------" | sudo tee -a $MOTD_FILE
echo "Betriebssystem       : $OS_VERSION" | sudo tee -a $MOTD_FILE
echo "Kernel-Version       : $KERNEL" | sudo tee -a $MOTD_FILE
echo "Systemlaufzeit       : $UPTIME" | sudo tee -a $MOTD_FILE
echo "Angemeldete Benutzer : $USERS" | sudo tee -a $MOTD_FILE
echo "" | sudo tee -a $MOTD_FILE

echo "Ressourcennutzung:" | sudo tee -a $MOTD_FILE
echo "------------------" | sudo tee -a $MOTD_FILE
echo "CPU-Auslastung       : $CPU_USAGE" | sudo tee -a $MOTD_FILE
echo "Speicherauslastung   : $MEMORY_USAGE" | sudo tee -a $MOTD_FILE
echo "Festplattennutzung   : $DISK_USAGE" | sudo tee -a $MOTD_FILE
echo "Systemlast           : $LOAD_AVERAGE" | sudo tee -a $MOTD_FILE
echo "" | sudo tee -a $MOTD_FILE

echo "Netzwerk:" | sudo tee -a $MOTD_FILE
echo "---------" | sudo tee -a $MOTD_FILE
echo "Interne IP-Adresse   : $IP_ADDRESS" | sudo tee -a $MOTD_FILE
echo "Externe IP-Adresse   : $EXTERNAL_IP" | sudo tee -a $MOTD_FILE
echo "" | sudo tee -a $MOTD_FILE

echo "Systemaktualisierungen:" | sudo tee -a $MOTD_FILE
echo "------------------------" | sudo tee -a $MOTD_FILE
echo "Verfügbare Updates     : $UPDATES" | sudo tee -a $MOTD_FILE
echo "Sicherheitsupdates     : $SECURITY_UPDATES" | sudo tee -a $MOTD_FILE
echo "" | sudo tee -a $MOTD_FILE

echo "Viel Erfolg beim Arbeiten!" | sudo tee -a $MOTD_FILE
