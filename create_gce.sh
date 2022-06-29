#!/usr/bin/env bash
vm_name=dos-test-`date +%y%m%d-%M`
project=principal-lane-200702
img_name=dos-test-220629-1
zone=asia-east1-b
machine_type=n2-standard-32
network_tag=http-server,https-server
if [[ ! $ENDPOINT ]];then
	ENDPOINT="http://34.83.161.134"
	echo ENDPOINT env not found use http://34.83.161.134
fi
echo ENDPOINT $ENDPOINT
printf -v meta_script "%s\n%s\n%s\n" \
			'#!/usr/bin/env bash
			## Input Env
			echo $(pwd) > startup_path.out
			echo "endpoint : $ENPOINT" >> startup_path.out' \
			"export RPC_ENDPOINT=$ENDPOINT" \
			'echo "rpc_endpoint : $RPC_ENDPOINT" >> startup_path.out
			export DURATION=600
			export TX_COUNT=2000
			exec ./start.sh > start.log'

gcloud beta compute instances create $vm_name \
	--project=$project \
	--source-machine-image=projects/$project/global/machineImages/$img_name \
	--zone=$zone \
	--machine-type=$machine_type \
	--network-interface=network-tier=PREMIUM,subnet=default \
	--maintenance-policy=MIGRATE \
	--service-account=dos-test@principal-lane-200702.iam.gserviceaccount.com \
	--scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append \
	--tags=$network_tag \
	--create-disk=auto-delete=yes,boot=yes,device-name=validator-template-for-eng,image=projects/ubuntu-os-pro-cloud/global/images/ubuntu-pro-2004-focal-v20211216,mode=rw,size=1024,type=projects/tour-de-sol/zones/asia-east1-b/diskTypes/pd-ssd \
	--no-shielded-secure-boot \
	--shielded-vtpm \
	--shielded-integrity-monitoring \
	--reservation-affinity=any \
    --metadata=startup-script=$meta_script
