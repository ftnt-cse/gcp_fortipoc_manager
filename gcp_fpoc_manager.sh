#!/bin/bash

#User Config:
POD_PASSWORD=""
POD_NAME="(Chamge your POD Name)"

#System config
ID_POS=$(expr 1 + $(echo $POD_NAME | sed 's/[^-]//g' | awk '{ print length }'))
GCLOUD="/snap/bin/gcloud"
TMPF="/tmp/ginstances"
ARG="$1"
RANGE="$2"
DEBUG=0
vacuum_db=0

function usage(){
	cat <<-END

	Usage: $0 COMMAND SCOPE SUBCOMMAND ARGs

	COMMAND list:
	   - status: Displays the status of the FortiPOC PODs
	   - start: Starts (poweron) of the FortiPOC PODs
	   - stop: Stops (poweroff) of the FortiPOC PODs
	   - reset: Ejects then launch the PoC on FortiPOC so VMs status will be reset to initial state
	   - links: Generates HTML list of the PODs
	   - ucinit: Genrates SQL definition of the scoreboard database
	   - list_ids: List the ID of each VM within a POD (IDs are required to power(on|off) selected VMs on PODs)
	   - vm: Performs various actions on individual VMs on each POD, check the sub commands section below 
	        - poweron: power on individual VMs on each POD
	        - poweroff: power off individual VMs on each POD
	   - poweronall: Power on all VMs of each POD
	   - poweroffall: Power off all VMs of each POD

	SCOPE:
	   The scope represents the list of PODs on which the COMMAND will be applied, it is in the format: [X-Y] or [all]: where X-Y represents a range of pods"

	SUBCOMMANDS:
		vm: when the VM command is used, the below subcommands are available:
            - poweron: power on individual VMs on each POD
            - poweroff: power off individual VMs on each POD

	ARGs:
		when SUBCOMMAND is used, ARGs is the csv string passed to the SUBCOMMAND
		poweron|poweroff: ARGs is the list of VMs to poweon or off expressed in a csv format: VM_id_1,VM_id_2,VM_id_3...etc

	Examples:
	   - Get the status of all PODs between 1 and 45:
	      ./pod_tools status 1-45
	   - Get the status of all PODs:
	      ./pod_tools status all
	   - Start PODs 10 to 50:
	      ./pod_tools start 10-50
	   - Stop all pods
	      ./pod_tools stop all 
	   - reset all PODs to initial state:
	      ./pod_tools reset all 
	   - List VM IDs of pod 1
	      ./pod_tools list_ids 1-1
	   - Turn on VMs with IDs: 3,4,5 on PODs 10 to 30
	      ./pod_tools vm 10-30 poweron 3,4,5
	   - Turn off VMs with IDs: 1,2,3,4 on all PODs
	      ./pod_tools vm all poweron 1,2,3,4


	END

	exit 1
}

[ "$#" -lt 2 ] || [ "$#" -gt 4 ] && usage

if [ "$RANGE" != "all" ]
then
x=$(echo $RANGE | cut -d"-" -f1)
y=$(echo $RANGE | cut -d"-" -f2)
fi

#Functions
function list_pods_vm_ids(){
	ADDR="$1"

	if [ -z "${ADDR}" ]; then
	    echo "Usage: $0 list_pods IP_ADDRESS" >&2
	    exit 1
	fi

	URL=https://${ADDR}
	PASSWORD=$POD_PASSWORD
	CURL="curl -v -b '@cookies' -c '@cookies' -k -e ${URL}/"

	${CURL} ${URL}/api/v0/login/ \
		--data-binary '{"username": "admin", "password": "'"${PASSWORD}"'"}' \
		-o login.json.${ADDR} > /dev/null 2>&1
	TOKEN=$(jq -r '."csrf-token"' login.json.${ADDR})
	TOKEN_HEADER=$(jq -r '."csrf-token-http-header"' login.json.${ADDR})

	${CURL} ${URL}/pocs/ -o dashboard.html.${ADDR} > /dev/null 2>&1
	grep -oE  "([0-9]+)/poweron.*on\s+\w+" dashboard.html.${ADDR} | sed "s/poweron', 'Power on//g"
	rm -f login.json.${ADDR} list.json.${ADDR} dashboard.html.${ADDR} ./\'@cookies\'
	exit 0

}

function run_pod_start_stop(){
	COMMAND="$1"
	ADDR="$2"
	VM_LIST="$3"

	if [ -z "${ADDR}" ] || [ -z "${COMMAND}" ]; then
	    echo "Usage: $0 COMMAND(poweron|poweroff) IP_ADDRESS" >&2
	    exit 1
	fi

	URL=https://${ADDR}
	PASSWORD=$POD_PASSWORD
	CURL="curl -v -b '@cookies' -c '@cookies' -k -e ${URL}/"

	${CURL} ${URL}/api/v0/login/ \
		--data-binary '{"username": "admin", "password": "'"${PASSWORD}"'"}' \
		-o login.json.${ADDR} > /dev/null 2>&1
	TOKEN=$(jq -r '."csrf-token"' login.json.${ADDR})
	TOKEN_HEADER=$(jq -r '."csrf-token-http-header"' login.json.${ADDR})

	${CURL} ${URL}/pocs/ -o dashboard.html.${ADDR} > /dev/null 2>&1
	eval $(awk '/csrfmiddlewaretoken/ {print $4}' dashboard.html.${ADDR})

	for vm in $(echo $VM_LIST | sed "s/,/ /g")
	do
	echo "$COMMAND VM id: $vm"
	${CURL} ${URL}/pocs/poc/cmd/device/$vm/$COMMAND -H "${TOKEN_HEADER}=${TOKEN}" --data csrfmiddlewaretoken=${value}  > /dev/null 2>&1
	sleep 2				
	done

	rm -f login.json.${ADDR} list.json.${ADDR} dashboard.html.${ADDR} ./\'@cookies\'

}

function run_pod_start_stop_all(){
	COMMAND="$1"
	ADDR="$2"

	if [ -z "${ADDR}" ] || [ -z "${COMMAND}" ]; then
	    echo "Usage: $0 COMMAND(start|stop) IP_ADDRESS" >&2
	    exit 1
	fi

	URL=https://${ADDR}
	PASSWORD=$POD_PASSWORD
	CURL="curl -v -b '@cookies' -c '@cookies' -k -e ${URL}/"

	${CURL} ${URL}/api/v0/login/ \
		--data-binary '{"username": "admin", "password": "'"${PASSWORD}"'"}' \
		-o login.json.${ADDR}  > /dev/null 2>&1
	TOKEN=$(jq -r '."csrf-token"' login.json.${ADDR})
	TOKEN_HEADER=$(jq -r '."csrf-token-http-header"' login.json.${ADDR})

	${CURL} ${URL}/pocs/ -o dashboard.html.${ADDR}  > /dev/null 2>&1
	eval $(awk '/csrfmiddlewaretoken/ {print $4}' dashboard.html.${ADDR})
	#

	${CURL} ${URL}/pocs/poc/cmd/$COMMAND -H "${TOKEN_HEADER}=${TOKEN}" --data csrfmiddlewaretoken=${value}  > /dev/null 2>&1
	rm -fv login.json.${ADDR} list.json.${ADDR} dashboard.html.${ADDR} ./\'@cookies\'

}

function run_pod_launch(){
	ADDR="$1"
	if [ -z "${ADDR}" ]; then
	    echo "ERROR: must specify instance hostname or IP address" >&2
	    exit 1
	fi

	URL=https://${ADDR}
	PASSWORD=$POD_PASSWORD
	CURL="curl -v -b '@cookies' -c '@cookies' -k -e ${URL}/"

	${CURL} ${URL}/api/v0/login/ \
		--data-binary '{"username": "admin", "password": "'"${PASSWORD}"'"}' \
		-o login.json.${ADDR}  > /dev/null 2>&1
	TOKEN=$(jq -r '."csrf-token"' login.json.${ADDR})
	TOKEN_HEADER=$(jq -r '."csrf-token-http-header"' login.json.${ADDR})

	# start the first PoC we pick, else you must hardcode the number
	${CURL} ${URL}/api/v0/poc/list -o list.json.${ADDR}  > /dev/null 2>&1
	POC=$(jq -r '.pocs | keys [0]' list.json.${ADDR})

	${CURL} ${URL}/pocs/ -o dashboard.html.${ADDR}  > /dev/null 2>&1
	eval $(awk '/csrfmiddlewaretoken/ {print $4}' dashboard.html.${ADDR})
	#echo "launch ${TOKEN_HEADER}=${TOKEN} on $ADDR"
	${CURL} ${URL}/pocs/poc/cmd/launch \
		-H "${TOKEN_HEADER}=${TOKEN}" \
		--data poc=${POC} --data csrfmiddlewaretoken=${value}  > /dev/null 2>&1
	rm -f login.json.${ADDR} list.json.${ADDR} dashboard.html.${ADDR} ./\'@cookies\'

}

$GCLOUD compute instances list --filter="name~'.*$POD_NAME\d+'"  --format="csv[no-heading](NAME,EXTERNAL_IP,STATUS,INTERNAL_IP)" | sort -t- -k"$ID_POS"  -n -o $TMPF

[ $? -ne 0 ] && echo "Command failed, couldn't fetch instance list from GCP" && exit 1


total_instances=$(wc -l $TMPF|cut -d" " -f1)

[ $RANGE == "all" ] && x=1 && y=$total_instances

[ $x -gt $y ] || [ $y -gt $total_instances ] && echo "Error: X cannot be greater than Y nor Y greater than total instance count ($total_instances)" && exit 1

while IFS= read -ra line
do
	instance_name=$(echo $line | cut -d"," -f1)
	instance_num=$(echo $instance_name | grep -o -E '\-[0-9]+$' |cut -d"-" -f2)
	instance_pip=$(echo $line | cut -d"," -f2)
	instance_status=$(echo $line | cut -d"," -f3)
	instance_iip=$(echo $line | cut -d"," -f4)
	if [ $RANGE != "all" ]
	then
		[ $instance_num -lt $x ] || [ $instance_num -gt $y ] && continue
	fi

	if [ $DEBUG -eq 1 ]
	then
		echo "total instance count $total_instances"
		echo "name $instance_name"
		echo "num $instance_num"
		echo "pip $instance_pip"
		echo "stat $instance_status"
		echo "X $x"
		echo "Y $y"
	fi



	case "$ARG" in
			list_ids)
				if [ "$instance_status" == "RUNNING" ];
				then
					echo "VM IDs on $instance_pip"
					list_pods_vm_ids $instance_pip
				fi
				;;
			start)
				if [ "$instance_status" == "TERMINATED" ];
				then
					echo "$instance_name is down, starting it up..."
					$GCLOUD compute instances start $instance_name --zone europe-west1-b &
					echo "$instance_name started__________________________________________________________________________________________________"
				fi
				;;

			stop)
				if [ "$instance_status" == "RUNNING" ];
				then
					echo "$instance_name is running, shutting it down..."
					$GCLOUD compute instances stop $instance_name --zone europe-west1-b &
					echo "$instance_name shutdown__________________________________________________________________________________________________"
				fi
				;;
			 
			reset)
				if [ "$instance_status" == "RUNNING" ];
				then
					echo "$instance_name is running, resetting..."
					run_pod_launch $instance_pip
				fi
				;;

			status)
				[ -z "$instance_pip" ] && instance_pip="\t\t"
				echo -e "$instance_num ,Name: $instance_name ,Private IP: $instance_iip ,Public IP: $instance_pip ,Status: $instance_status"
				;;

			links)
				[ "$instance_status" == "TERMINATED" ] && continue
				echo "<tr>"
				echo "<td>Pod $instance_num</td>"
				echo "<td><a href=https://$instance_pip>https://$instance_pip</a></td>"
				echo "</tr>"
				;;

			dbinit)
				[ "$instance_status" == "TERMINATED" ] && continue
				if [ $vacuum_db = 0 ]
				then
					echo "DELETE FROM score_history;"
					echo "VACUUM;"
					echo "DELETE FROM score;"
					echo "VACUUM;"
					vacuum_db=1
				fi
				echo "INSERT INTO score(ID,stage,super,fortigate,timestamp,step,score) VALUES ($instance_num,'Starting','$instance_pip:10406','$instance_iip:10402',datetime('now','localtime'),0,0);"
				;;	

			vm)
				[ "$instance_status" == "TERMINATED" ] && continue
				echo "$3 VMs $4 on $instance_pip"
				run_pod_start_stop $3 $instance_pip $4
				;;


			poweronall)
				[ "$instance_status" == "TERMINATED" ] && continue
				echo "Booting up VMs VM on $instance_pip"
				run_pod_start_stop_all start $instance_pip
				;;

			poweroffall)
				[ "$instance_status" == "TERMINATED" ] && continue
				echo "Powering down VMs on $instance_pip"
				run_pod_start_stop_all stop $instance_pip
				;;
			*)
				usage

	esac

done < "$TMPF"