#!/usr/bin/env sh
apt-get install gnupg1 apt-transport-https dirmngr
export INSTALL_KEY=379CE192D401AB61
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys $INSTALL_KEY
echo "deb https://ookla.bintray.com/debian generic main" | tee  /etc/apt/sources.list.d/speedtest.list
apt-get update
apt-get -y install speedtest zabbix-sender
speedtest --accept-license
cd /root
wget https://raw.githubusercontent.com/tbutsch/zabbix-appliance-speedtest-wan/master/speedtest.sh
wget https://raw.githubusercontent.com/tbutsch/zabbix-appliance-speedtest-wan/master/speedtest.service
wget https://raw.githubusercontent.com/tbutsch/zabbix-appliance-speedtest-wan/master/speedtest.timer
wget https://raw.githubusercontent.com/tbutsch/zabbix-appliance-speedtest-wan/master/speedtest.conf
mkdir /etc/zabbix/script
chmod 777 /etc/zabbix/script
cp ./speedtest.sh /etc/zabbix/script/
chmod +x /etc/zabbix/script/speedtest.sh
cp ./speedtest.conf /etc/zabbix/zabbix_agentd.conf.d/
cp ./speedtest.conf /etc/zabbix/zabbix_agentd.d/
cp speedtest.service speedtest.timer /etc/systemd/system
systemctl enable --now speedtest.timer
service zabbix-agent restart
rm speedtest.sh
rm speedtest.service
rm speedtest.timer
rm speedtest.conf
rm installer.sh
