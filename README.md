# GCP FortiPOC Manager
It's a quick tool to manage FortiPOC instances (PODs) on GCP during workshops
## Quick start:
- Download the script
- Open it and set the FortiPOC password
- Set the PODs base name (exp: if the pods are called: FortiGate-Workshop-2020q4-XX, use : POD_NAME="FortiGate-Workshop-2020q4-")
- Configure gcloud cli on the machine where you will run the script

Usage: ./gcp_fpoc_manager.sh [COMMAND] [SCOPE] [SUBCOMMAND] [ARGs]

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
	      ./gcp_fpoc_manager.sh status 1-45
	   - Get the status of all PODs:
	      ./gcp_fpoc_manager status all
	   - Start PODs 10 to 50:
	      ./gcp_fpoc_manager start 10-50
	   - Stop all pods
	      ./gcp_fpoc_manager stop all 
	   - reset all PODs to initial state:
	      ./gcp_fpoc_manager reset all 
	   - List VM IDs of pod 1
	      ./gcp_fpoc_manager list_ids 1-1
	   - Turn on VMs with IDs: 3,4,5 on PODs 10 to 30
	      ./gcp_fpoc_manager vm 10-30 poweron 3,4,5
	   - Turn off VMs with IDs: 1,2,3,4 on all PODs
	      ./gcp_fpoc_manager vm all poweron 1,2,3,4
