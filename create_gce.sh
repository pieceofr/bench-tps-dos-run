#!/usr/bin/env bash
set -e
declare -a instance_ip
declare -a instance_name
# prepare ENV
echo "imported ENDPOINT : $ENDPOINT"
if [[ ! $ENDPOINT ]];then
	ENDPOINT="http://34.83.161.134"
	echo ENDPOINT env not found use http://34.83.161.134
fi
get_time_after() {
	outcom_in_sec=$(echo ${given_ts} + ${add_secs} | bc) 
}

get_time_before() {
	outcom_in_sec=$(echo ${given_ts} - ${minus_secs} | bc) 
}

download_file() {
	for retry in 0 1
	do
		if [[ $retry -gt 1 ]];then
			break
		fi

		gsutil cp  gs://bench-tps-dos/$file_in_bucket ./

		if [[ ! -f "$file_in_bucket" ]];then
			echo "NO $file_in_bucket found, retry"
		else
			break
		fi
	done
}

create_gce() {
	vm_name=dos-test-`date +%y%m%d-%M-%S`
	project=principal-lane-200702
	img_name=dos-test-220630-2
	zone=asia-east1-b
	machine_type=n2-standard-32
	network_tag=http-server,https-server
	ret_create=$(gcloud beta compute instances create $vm_name \
		--project=$project \
		--source-machine-image=projects/$project/global/machineImages/$img_name \
		--zone=$zone \
		--machine-type=$machine_type \
		--network-interface=network-tier=PREMIUM,subnet=default \
		--maintenance-policy=MIGRATE \
		--service-account=dos-test@principal-lane-200702.iam.gserviceaccount.com \
		--scopes=https://www.googleapis.com/auth/cloud-platform \
		--tags=$network_tag \
		--no-shielded-secure-boot \
		--shielded-vtpm \
		--shielded-integrity-monitoring \
		--format="flattened(name,networkInterfaces[0].accessConfigs[0].natIP)" \
		--reservation-affinity=any)
	echo $ret_create > ret_create.out
	sship=$(sed 's/^.*nat_ip: //g' ret_create.out)
	instance_ip+=($sship)
	echo ip:$sship
	gc_name=$(sed 's/^.*--- name: //g' ret_create.out | sed 's/ nat_ip:.*//g')
	instance_name+=($gc_name)
	echo name:$gc_name
}

### Main ###
echo ----- stage: prepare execute script ------
endpoint_statment="ENDPOINT=$ENDPOINT"
echo endpoint_statment $endpoint_statment 
file_in_bucket=id_ed25519_dos_test
download_file
if [[ ! -f "id_ed25519_dos_test" ]];then
	echo "no id_ed25519_dos_test found"
	exit 1
fi
echo $file_in_bucket is download

if [[ -f "exec-pre-start.sh" ]];then
    rm exec-pre-start.sh
fi

if [[ -f "exec-dos-test.sh" ]];then
    rm exec-dos-test.sh
fi

# generate a exec-pre-start.sh with ENDPOINT env
sed  -e 5a\\$endpoint_statment exec-start-template.sh > exec-pre-start.sh
if [[ ! -f "exec-pre-start.sh" ]];then
	echo "no exec-pre-start.sh found"
	exit 1
fi
echo 'exec  ./start-prepare.sh > start-prepare.log' >> exec-pre-start.sh
sed  -e 5a\\$endpoint_statment exec-start-template.sh > exec-dos-test.sh
if [[ ! -f "exec-dos-test.sh" ]];then
	echo "no exec-dos-test.sh found"
	exit 1
fi
# in order to do none-blocking  run nohup in background
echo 'exec nohup ./start-dos-test.sh > start-dos-test.log 2>start-dos-test.err &' >> exec-dos-test.sh

# instance_ip+=(35.229.243.74 35.229.243.74)

echo ----- stage: create gc instances ------
for i in {1..2}
do
	create_gce
	sleep 5 # avoid too quick build
done
echo instance_ip ${instance_ip[@]}
echo instance_name ${instance_name[@]}
echo ----- stage: pre-build solana ------
sleep 630 # wait for laste  instance ssh ready
for sship in "${instance_ip[@]}"
do
	echo run pre start:$sship
	ssh -i id_ed25519_dos_test -o StrictHostKeyChecking=no sol@$sship 'bash -s' < exec-pre-start.sh
done

echo ----- stage: run benchmark-tps background ------
# Get Time Start
adjust_ts=5
start_time=$(echo `date -u +%s`)
given_ts=$start_time
add_secs=$adjust_ts
get_time_after
start_time2=$outcom_in_sec

for sship in "${instance_ip[@]}"
do
	ssh -i id_ed25519_dos_test -o StrictHostKeyChecking=no sol@$sship 'bash -s' < exec-dos-test.sh
	echo ***run benchmark : $ssip
done

echo ----- stage: wait for benchmark to end ------

sleep 30 # wait for benchmark to finish
### Get Time Stop
adjust_ts=15
stop_time=$(echo `date -u +%s`)
given_ts=$stop_time
minus_secs=$adjust_ts
get_time_before
stop_time2=$outcom_in_sec

echo ----- stage: DOS report ------
if [[ -f "dos-report-env.sh" ]];then
    rm dos-report-env.sh
fi

file_in_bucket=dos-report-env.sh
download_file
if [[ ! -f "dos-report-env.sh" ]];then
	echo "NO dos-report-env.sh found"
	exit 1
fi
echo $file_in_bucket is download

echo "START_TIME=${start_time}" >> dos-report-env.sh
echo "START_TIME2=${start_time2}" >> dos-report-env.sh
echo "STOP_TIME=${stop_time}" >> dos-report-env.sh
echo "STOP_TIME2=${stop_time2}" >> dos-report-env.sh
exec ./dos-report.sh

echo ----- stage: remove gc instances ------
echo instance_name : ${instance_name[@]}
for vm in "${instance_name[@]}"
do
	gcloud compute instances delete $vm
	echo delete $vms
done

#### Memo files #####
## create_gce.sh 
##		Main process. To create gces, prepare environment, run benchmark and generate a report
## exec-start-template.sh
##		a template to generate 2 files. One is for building solana and another is for dos-test
## exec-pre-start.sh
## 		a temporary file generated from exec-start-template.sh. It is send through ssh to evoke start-prepare.sh
## exec-dos-test.sh
##		a temporary file generated from exec-start-template.sh. It is send through ssh to evoke start-dos-test.sh
## dos-report-env.sh 
##		store in bench-tps-dos which contain influx important ENV. It also be appended start-time and stop-time info dynamically.
##		dos-report.sh sources this
## dos-report.sh
##		generate dos test report and send to the slack
## influx_data.sh
##		flux commands. dos-report.sh source this
## id_ed25519_dos_test 
##		store in the bench-tps-dosbucket. It is the key to ssh to the gce
####################