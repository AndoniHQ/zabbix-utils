#!/bin/bash

#Comprobaciones previas
set -eu -o pipefail # Interrumpe la ejecucion cuando haya un error y debugealo

if [ "$EUID" -ne 0 ]
  then echo "Debes ejecutar el comando como root."
  exit
fi

if [[ $# -eq 0 ]] ; then
    echo -e "Debes indicar el nombre del cliente e IP del proxy. Ejemplo:\n"
    echo -e "./install.sh Tesla 192.168.1.217\n"
    exit 0
fi

#Variables
CLIENT=$1
IP=$2
AGENT_CONFIG="/etc/zabbix/zabbix_agentd.conf"

#Acciones
echo -e "\n[*]Acutalizando paquetes...\n"
apt update

echo -e "\n[*]Instalando requisitos...\n"
apt install -y zabbix-agent

echo -e "\n[*]Configurando Zabbix Agent...\n"
sed -i "s/\(Server *= *\).*/\1$IP/" $AGENT_CONFIG && echo -e "\tServer=$IP"
sed -i "s/\(ServerActive *= *\).*/\1$IP/" $AGENT_CONFIG && echo -e "\tServerActive=$IP"
sed -i "s/\(Hostname *= *\).*/\1$CLIENT-Proxmox/" $AGENT_CONFIG && echo -e "\tHostname=$CLIENT-Proxmox"
sed -i '/HostMetadata=/s/^# //' $AGENT_CONFIG
sed -i "s/\(HostMetadata *= *\).*/\1$CLIENT,Linux,Proxmox/" $AGENT_CONFIG && echo -e "\tHostMetadata=$CLIENT,Linux,Proxmox"

echo -e "\n[*]Iniciando servicio zabbix-agent...\n"
service zabbix-agent restart
systemctl enable zabbix-agent