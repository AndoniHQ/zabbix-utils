#!/bin/bash

#Comprobaciones previas
set -eu -o pipefail # Interrumpe la ejecucion cuando haya un error y debugealo
sudo -n true
test $? -eq 0 || exit 1 "Debes tener privilegios sudo para ejecutar este script"

if [[ $# -eq 0 ]] ; then
    echo -e "Debes indicar el nombre del cliente. Ejemplo:\n"
    echo -e "./install.sh Tesla\n"
    exit 0
fi

#Variables
CLIENT=$1
ZABBIX_URL="https://repo.zabbix.com/zabbix/6.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.0-4%2Bubuntu22.04_all.deb"
PROXY_CONFIG="/etc/zabbix/zabbix_proxy.conf"
AGENT_CONFIG="/etc/zabbix/zabbix_agentd.conf"

#Acciones
echo -e "\n[*]Agregando repositorios de Zabbix...\n"
sudo wget "${ZABBIX_URL}" -P /tmp/
sudo dpkg -i /tmp/zabbix-release_6.0-4+ubuntu22.04_all.deb
sudo apt update

echo -e "\n[*]Instalando requisitos...\n"
sudo apt install -y resolvconf wireguard zabbix-proxy-sqlite3 zabbix-agent

echo -e "\n[*]Configurando Wireguard...\n"
sudo mv "${CLIENT}-Proxy.conf" "/etc/wireguard/${CLIENT}.conf"
sudo chmod 600 "/etc/wireguard/${CLIENT}.conf"

echo -e "\n[*]Iniciando servicio VPN...\n"
sudo service wg-quick@$CLIENT start
sudo systemctl enable wg-quick@$CLIENT
sleep 5

echo -e "\n[*]Configurando Zabbix Proxy...\n"
sudo sed -i "s/\(Server *= *\).*/\110.10.10.1/" $PROXY_CONFIG && echo -e "\tServer=10.10.10.1"
sudo sed -i "s/\(Hostname *= *\).*/\1$CLIENT-Proxy/" $PROXY_CONFIG && echo -e "\tHostname=$CLIENT-Proxy"
sudo sed -i "s/\(DBName *= *\).*/\1\/tmp\/zabbix\_proxy\.db/" $PROXY_CONFIG && echo -e "\tDBName=/tmp/zabbix_proxy.db"

echo -e "\n[*]Iniciando servicio zabbix-proxy...\n"
sudo service zabbix-proxy restart
sudo systemctl enable zabbix-proxy

echo -e "\n[*]Configurando Zabbix Agent...\n"
sudo sed -i "s/\(Hostname *= *\).*/\1$CLIENT-Proxy/" $AGENT_CONFIG && echo -e "\tHostname=$CLIENT-Proxy"
sudo sed -i '/HostMetadata=/s/^# //' $AGENT_CONFIG
sudo sed -i "s/\(HostMetadata *= *\).*/\1$CLIENT,Proxy,Linux/" $AGENT_CONFIG && echo -e "\tHostMetadata=$CLIENT,Proxy,Linux"

echo -e "\n[*]Iniciando servicio zabbix-agent...\n"
sudo service zabbix-agent restart
sudo systemctl enable zabbix-agent