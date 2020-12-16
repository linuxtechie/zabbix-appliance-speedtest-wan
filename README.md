# Install:

Step 1: Install Speedtest itself

```bash
apt-get install gnupg1 apt-transport-https dirmngr
export INSTALL_KEY=379CE192D401AB61
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys $INSTALL_KEY
echo "deb https://ookla.bintray.com/debian generic main" | tee  /etc/apt/sources.list.d/speedtest.list
apt-get update
apt-get -y install speedtest
```

Test if it work!
```bash
~$ speedtest --simple
```
Step 2: Create folder for scripts and copy files.
```bash
~$ sudo mkdir /etc/zabbix/script
```
and change premissions to 777
```bash
~$ sudo chmod 777 /etc/zabbix/script
```
copy speedtest.sh to zabbix script folder
```bash
~$ sudo cp ./speedtest.sh /etc/zabbix/script/
```
and make it executable
```bash
~$ sudo chmod +x /etc/zabbix/script/speedtest.sh
```
copy speedtest.conf to zabbix_agentd.conf.d folder
```bash
~$ sudo cp ./speedtest.conf /etc/zabbix/zabbix_agentd.conf.d/
```
copy speedtest.service and speedtest.timer to /etc/systemd/system
```bash
~$ sudo cp speedtest.service speedtest.timer /etc/systemd/system
```
and enable timer:
```bash
~$ sudo systemctl enable --now speedtest.timer
```
Step 3: Import template_speedtest.xml to Zabbix server

Step 4: **INPORTANT** restart zabbix agent
```bash
~$ sudo service zabbix-agent restart
```
