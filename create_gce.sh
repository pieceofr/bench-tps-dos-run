#!/usr/bin/env bash

vm_name=dos-test-1
project=principal-lane-200702
img_name=dos-test-220629
zone=asia-east1-b
machine_type=n1-standard-32
network_tag=http-server,https-server
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
    --metadata=startup-script='#!/usr/bin/env bash
## Input Env
export RPC_ENDPOINT="http://34.83.161.134"
export DURATION=600
export TX_COUNT=2000
exec $HOME/start.sh'
