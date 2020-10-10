#!/usr/bin/env sh
apt-get update
apt-get -y install speedtest-cli
speedtest --simple
cd /root
wget https://raw.githubusercontent.com/tbutsch/zabbix-appliance-speedtest-wan/master/speedtest.sh
wget https://raw.githubusercontent.com/tbutsch/zabbix-appliance-speedtest-wan/master/speedtest.service
wget https://raw.githubusercontent.com/tbutsch/zabbix-appliance-speedtest-wan/master/speedtest.timer
mkdir /etc/zabbix/script
chmod 777 /etc/zabbix/script
cp ./speedtest.sh /etc/zabbix/script/
chmod +x /etc/zabbix/script/speedtest.sh
cp ./speedtest.conf /etc/zabbix/zabbix_agentd.conf.d/
cp speedtest.service speedtest.timer /etc/systemd/system
systemctl enable --now speedtest.timer
service zabbix-agent restart
rm speedtest.sh
rm speedtest.service
rm speedtest.timer
rm installer.sh
