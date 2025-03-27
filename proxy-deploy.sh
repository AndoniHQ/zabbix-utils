#!/bin/bash

#Comprobaciones previas
set -eu -o pipefail # Interrumpe la ejecucion cuando haya un error y debugealo

if [ "$EUID" -ne 0 ]
  then echo "Debes ejecutar el comando como root."
  exit
fi

if [[ $# -eq 0 ]] ; then
    echo -e "Debes indicar el nombre del cliente. Ejemplo:\n"
    echo -e "./install.sh Tesla\n"
    exit 0
fi

if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "$VERSION_ID"
else
    echo "No se pudo determinar la versión de Ubuntu."
    exit 1
fi

#Variables
CLIENT=$1
ZABBIX_URL="https://repo.zabbix.com/zabbix/6.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.0-4%2Bubuntu${VERSION_ID}_all.deb"
PROXY_CONFIG="/etc/zabbix/zabbix_proxy.conf"
AGENT_CONFIG="/etc/zabbix/zabbix_agentd.conf"

#Acciones
echo -e "\n[*]Agregando repositorios de Zabbix...\n"
wget "${ZABBIX_URL}" -P /tmp/
dpkg -i /tmp/zabbix-release_6.0-4+ubuntu${VERSION_ID}_all.deb
apt update

echo -e "\n[*]Instalando requisitos...\n"
apt install -y resolvconf wireguard zabbix-proxy-sqlite3 zabbix-agent

echo -e "\n[*]Configurando Wireguard...\n"
mv "${CLIENT}-Proxy.conf" "/etc/wireguard/${CLIENT}.conf"
chmod 600 "/etc/wireguard/${CLIENT}.conf"

echo -e "\n[*]Iniciando servicio VPN...\n"
service wg-quick@$CLIENT start
systemctl enable wg-quick@$CLIENT
sleep 5

echo -e "\n[*]Configurando Zabbix Proxy...\n"
sed -i "s/\(Server *= *\).*/\110.10.10.1/" $PROXY_CONFIG && echo -e "\tServer=10.10.10.1"
sed -i "s/\(Hostname *= *\).*/\1$CLIENT-Proxy/" $PROXY_CONFIG && echo -e "\tHostname=$CLIENT-Proxy"
sed -i "s/\(DBName *= *\).*/\1\/tmp\/zabbix\_proxy\.db/" $PROXY_CONFIG && echo -e "\tDBName=/tmp/zabbix_proxy.db"

echo -e "\n[*]Iniciando servicio zabbix-proxy...\n"
service zabbix-proxy restart
systemctl enable zabbix-proxy

echo -e "\n[*]Configurando Zabbix Agent...\n"
sed -i "s/\(Hostname *= *\).*/\1$CLIENT-Proxy/" $AGENT_CONFIG && echo -e "\tHostname=$CLIENT-Proxy"
sed -i '/HostMetadata=/s/^# //' $AGENT_CONFIG
sed -i "s/\(HostMetadata *= *\).*/\1$CLIENT,Proxy,Linux/" $AGENT_CONFIG && echo -e "\tHostMetadata=$CLIENT,Proxy,Linux"

echo -e "\n[*]Iniciando servicio zabbix-agent...\n"
service zabbix-agent restart
systemctl enable zabbix-agent