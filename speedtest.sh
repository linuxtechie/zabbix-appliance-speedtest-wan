#!/usr/bin/env bash
set -e

exec >>	/dev/null
exec 2>&1

log()
{
	echo `date +%y/%m/%d_%H:%M:%S`: $*
}

logn()
{
	echo -n `date +%y/%m/%d_%H:%M:%S`: $*
}


LOCK_FILE="/tmp/speedtest.lock"
METRIC_FILE="/tmp/zabbix_metrics.txt"
WIFI_AP_LIST="/etc/zabbix/script/wifi_ap.lst"
WPA_CLI_CMD="wpa_cli -i wlan0"
WIFI_CONNECTED="OK"
SPEEDTEST="/usr/bin/speedtest --accept-license"
# you.khanorkar.com,ramesh\$h57\$1

dhclinet_release(){
	sudo dhclient -v -r wlan0 > /dev/null 2>&1
}

dhclinet_renew(){
	sudo dhclient -v wlan0 > /dev/null 2>&1
}

wpa_cli_cmd(){
	echo $($WPA_CLI_CMD $*)
}

update_working_wifi(){
	current_wifi_id=$($WPA_CLI_CMD status | awk -F"=" '/^id/ {print $2}')
	current_wifi=$($WPA_CLI_CMD status | awk -F"=" '/^ssid/ {print $2}')
}

wifi_scan(){
	logn "Scanning existing wifi(s)..."
	wpa_cli_cmd scan
}

wifi_wait_network(){
	logn "--> Checking network is ready..."
	wifi_state=$(ip address show wlan0  | awk '/inet / {print $1}')
	attempts=3
	while true
	do
			if [ "$wifi_state" == "inet" ]; then
				break
			fi
			if [ $attempts -eq 0 ]; then
				break
			fi
			sleep 5
			wifi_state=$(ip address show wlan0  | awk '/inet / {print $1}')
			(( attempts-- ))
	done
	if [ "$wifi_state" == "inet" ]; then
		WIFI_CONNECTED="OK"
	else
		WIFI_CONNECTED="NO"
	fi
	echo "Done"
}


revert_original_wifi(){
	status=$($WPA_CLI_CMD select_network $current_wifi_id)
	log "Selecting existing network...$status"
	status=$($WPA_CLI_CMD enable_network $current_wifi_id)
	log "Enabling existing network...$status"
	dhclinet_release
	dhclinet_renew
}

cleanup(){
	rm -f $LOCK_FILE
	rm -f $METRIC_FILE
	revert_original_wifi
	if [ "$wifi_new_id" != "$current_wifi_id" ]; then
		if [ ! -z $wifi_new_id ]; then
			logn "Removing temporary networkid..."
			wpa_cli_cmd remove_network $wifi_new_id
		fi
	fi
	kill -9 $(ps -o pid= --ppid $$) > /dev/null 2>&1
}

run_speedtest_each_ap() {
	#Variable declaration
	local output server_id server_sponsor country location ping download upload

	#Check if argument supplied to function, exec speedtest command and save output
	if [ -z "$1" ]
	then
		output=$($SPEEDTEST -f json)
	else
		output=$($SPEEDTEST -s "$1" -f json)
	fi
	current_wifi=$($WPA_CLI_CMD list_networks | awk '/CURRENT/ {print $2}')

	upload=$(echo "$output" | jq .upload.bandwidth)
	download=$(echo "$output" | jq .download.bandwidth)
	jitter=$(echo "$output" | jq .ping.jitter)
	ping=$(echo "$output" | jq .ping.latency)
	packetLoss=$(echo "$output" | jq .packetLoss | sed 's/"//g')
	isp=$(echo "$output" | jq .isp | sed 's/"//g')
	resultUrl=$(echo "$output" | jq .result.url | sed 's/"//g')
	download=$(($download * 8))
	upload=$(($upload * 8))

	if [ "$current_wifi" != "" ]; then
		uniqueId=$(echo "$current_wifi$isp" | md5sum -z | cut -d' ' -f1)
		discovery_json="{\"data\":[{\"{#SERVERID}\":\"$uniqueId\", \"{#SERVERNAME}\":\"$isp\",  \"{#WIFINAME}\":\"$current_wifi\"}]}"
	else
		uniqueId=$(echo "$isp" | md5sum -z | cut -d' ' -f1)
		discovery_json="{\"data\":[{\"{#SERVERID}\":\"$uniqueId\", \"{#SERVERNAME}\":\"$isp\"}]}"
	fi

	zbx_hostname=$(cat /etc/zabbix/zabbix_agentd.conf | awk -F "=" '/^Hostname=/ { print $2 }')

	echo "$zbx_hostname speedtest.discovery $discovery_json" > $METRIC_FILE
	echo "$zbx_hostname speedtest.upload.server[$uniqueId] $upload" >> $METRIC_FILE
	echo "$zbx_hostname speedtest.download.server[$uniqueId] $download" >> $METRIC_FILE
	echo "$zbx_hostname speedtest.jitter.server[$uniqueId] $jitter" >> $METRIC_FILE
	echo "$zbx_hostname speedtest.ping.server[$uniqueId] $ping" >> $METRIC_FILE
	echo "$zbx_hostname speedtest.packetloss.server[$uniqueId] $packetLoss" >> $METRIC_FILE
	echo "$zbx_hostname speedtest.result.server[$uniqueId] \"$resultUrl\"" >> $METRIC_FILE

	/usr/bin/zabbix_sender -c /etc/zabbix/zabbix_agentd.conf -i $METRIC_FILE > /dev/null 2>&1
	rm -rf $METRIC_FILE
}


execute_speedtest_check(){
	wifi_wait_network
	if [ "$WIFI_CONNECTED" == "OK" ]; then
		logn "--> Executing SpeedTest Check..."
		run_speedtest_each_ap
		echo "Done"
	else
		log "--> Network is not connected."
	fi
}

wifi_set_ap(){
	logn "--> Creating SSID Entry..."
	$WPA_CLI_CMD set_network $wifi_new_id ssid \"$1\"
}

wifi_set_pw(){
	logn "--> Creating PW Entry..."
	$WPA_CLI_CMD set_network $wifi_new_id psk "\"$1\""
}

connect_wifi_test() {
	line=$1
	wifi_args=(${line//,/ })
	wifi_ap=${wifi_args[0]}
	wifi_pw=${wifi_args[1]}
	# if [ "$wifi_ap" != "$target_wifi" ]; then
	#   return
	# fi
	log "Processing: $wifi_ap"
	dhclinet_release
	wifi_new_id=$($WPA_CLI_CMD add_network)
	wifi_set_ap "$wifi_ap"
	wifi_set_pw "$wifi_pw"
	logn "--> Creating Enable Entry..."
	wpa_cli_cmd enable_network $wifi_new_id
	logn "--> Creating Select Entry..."
	wpa_cli_cmd select_network $wifi_new_id
	dhclinet_renew
	# sudo systemctl restart dhcpcd
	execute_speedtest_check
	logn "--> Remove SSID Entry..."
	wpa_cli_cmd remove_network $wifi_new_id
	unset wifi_new_id
	sleep 1
}


check_wifi_configured(){
	if [ "$1" = "$current_wifi" ]; then
		revert_original_wifi
		execute_speedtest_check
		return
	fi
	target_wifi=$1
	while IFS= read -r line
	do
		connect_wifi_test "$line"
	done < $WIFI_AP_LIST
}


check_each_wifi_configured(){
	while IFS= read -r line
	do
		connect_wifi_test "$line"
	done < $WIFI_AP_LIST
}

process_all_wifi(){
	# Lock
	if [ -e "${LOCK_FILE}" ] && kill -0 `cat ${LOCK_FILE}`; 
	then
		log "A speedtest is already running"
		exit 2
	fi
	echo $$ > ${LOCK_FILE}

	check_each_wifi_configured $wifi
	log "Check completed."
}

# process_all_scanned_wifi(){
# 	# Lock
# 	if [ -e "$LOCK_FILE" ]
# 	then
# 		log "A speedtest is already running"
# 		exit 2
# 	fi
# 	touch "$LOCK_FILE"
#
#   for wifi in $($WPA_CLI_CMD scan_results | grep -v 'signal' | awk '{print $5}'); do
#     log "Checking $wifi..."
#     check_wifi_configured $wifi
#   done
# }

trap cleanup EXIT HUP INT QUIT PIPE TERM

display_help() {
	echo "Usage with this parameters"
	echo
	echo "                          Run the speedtest collector with default setting (best server)"
	echo "   -l xxx                 Run the speedtest collector on the server with id xxx"
	echo "   -a, --all              Run the speedtest collector on the all servers listed in array and the best server"
	echo "   -g, --get-all          Get all server on which run the speedtest with -a"
	echo "   -h, --help             View this help"
	echo
}

# Save current working wifi
update_working_wifi

if [ $# -eq 0 ] || [ $# -eq 1 ]
then
	case "$1" in
		-f|--force)
			rm -rf "$LOCK_FILE"
			process_all_wifi
			;;
		-h|--help)
			display_help
			;;
		*)
			# process_all_scanned_wifi
      process_all_wifi
			;;
	esac
elif [ $# -eq 2 ]
then
	if [ $1 = "-l" ]
	then
		SPEETEST_SERVER=$2
		# process_all_scanned_wifi
    process_all_wifi
	fi
fi
