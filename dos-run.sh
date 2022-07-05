#!/usr/bin/env bash
set -ex
declare -a instance_ip
declare -a instance_name
declare -a instance_zone

# prepare ENV
echo "import ENDPOINT : $ENDPOINT"
if [[ ! "$ENDPOINT" ]];then
	echo ENDPOINT env not found, exit
	exit 1
fi

if [[ ! "$NUM_CLIENT" ]];then
	echo NUM_CLIENT env not found, exit
	exit 1
fi

if [[ ! "$SLACK_WEBHOOK" ]];then
	echo WEB_SLACK env not found, exit
	exit 1
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
	img_name=dos-test-220705-no-agent-solana-prebuild-3
	if [[ ! "$zone" ]];then
		zone=asia-east1-b
	fi
	machine_type=n1-standard-32
	network_tag=http-server,https-server
	ret_create=$(gcloud beta compute instances create $vm_name \
		--project=$project \
		--source-machine-image=$img_name \
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
	gc_name=$(sed 's/^.*--- name: //g' ret_create.out | sed 's/ nat_ip:.*//g')
	instance_name+=($gc_name)
	instance_zone+=($zone)
}

### Main ###
echo ----- stage: prepare execute scripts ------
file_in_bucket=id_ed25519_dos_test
download_file

if [[ ! -f "id_ed25519_dos_test" ]];then
	echo "no id_ed25519_dos_test found"
	exit 1
fi
echo id_ed25519_dos_test is download
chmod 600 id_ed25519_dos_test

if [[ -f "exec-pre-start.sh" ]];then
    rm exec-pre-start.sh
fi

if [[ -f "exec-dos-test.sh" ]];then
    rm exec-dos-test.sh
fi

if [[ ! "$BUILD_SOLANA" ]];then
	BUILD_SOLANA="false"
fi
if [[ "$BUILD_SOLANA" == "true" ]];then
	if [[ ! "$CHANNEL" ]];then
		CHANNEL=edge
	fi
	sed  -e 5a\\"export CHANNEL=$CHANNEL" exec-start-template.sh > exec-pre-start.sh
	cat exec-pre-start.sh
	if [[ ! -f "exec-pre-start.sh" ]];then
		echo "no exec-pre-start.sh found"
		exit 1
	fi
	echo 'exec  ./start-build-solana.sh > start-build-solana.log' >> exec-pre-start.sh
	# generate a exec-dos-test.sh
fi
# generate a exec-pre-start.sh
sed  -e 5a\\"export RPC_ENDPOINT=$ENDPOINT" exec-start-template.sh > exec-dos-test.sh
if [[ "$USE_TPU_CLIENT" == "true" ]];then
	 echo "export USE_TPU_CLIENT=true" >> exec-dos-test.sh
else 
	echo "export USE_TPU_CLIENT=false" >> exec-dos-test.sh
fi

if [[ "$TPU_USE_QUIC" == "true" ]];then
	 echo "export TPU_USE_QUIC=true" >> exec-dos-test.sh
else
	 echo "export TPU_USE_QUIC=false" >> exec-dos-test.s
fi

if [[ "$DURATION" ]];then
    echo "export DURATION=$DURATION" >> exec-dos-test.sh
fi

if [[ "$TX_COUNT" ]];then
    echo "export TX_COUNT=$TX_COUNT" >> exec-dos-test.sh
fi

if [[ "$SUSTAINED" ]];then
    echo "export SUSTAINED=$SUSTAINED" >> exec-dos-test.sh
fi

if [[ "$KEYPAIR_FILE" ]];then
    echo "export KEYPAIR_FILE=$KEYPAIR_FILE" >> exec-dos-test.sh
fi

if [[ ! -f "exec-dos-test.sh" ]];then
	echo "no exec-dos-test.sh found"
	exit 1
fi

cat exec-dos-test.sh
# in order to do none-blocking  run nohup in background
echo 'exec nohup ./start-dos-test.sh > start-dos-test.log 2>start-dos-test.err &' >> exec-dos-test.sh

echo ----- stage: create gc instances ------
declare -a available_zone
if [[ ! "$AVAILABLE_ZONE" ]];then
	available_zone=( us-west2-b asia-east1-b asia-northeast1-a )
else
	available_zone=( $AVAILABLE_ZONE )
fi

for i in $(seq 1 $NUM_CLIENT)
do
	if [[ $count -ge ${#available_zone[@]} ]];then
    	count=0
    fi 
	zone=${available_zone[$count]}
	create_gce
	let count+=1
	echo "gc instance is created in $zone"
	sleep 60 # avoid too quick build
done


echo "instance_ip ${instance_ip[@]}"
echo "instance_name ${instance_name[@]}"
echo "instance_zone ${instance_zone[@]}"
if [[ "$BUILD_SOLANA" == "true" ]];then
	echo ----- stage: pre-build solana ------
	for sship in "${instance_ip[@]}"
	do
		echo run pre start:$sship
		ret_pre_build=$(ssh -i id_ed25519_dos_test -o StrictHostKeyChecking=no sol@$sship 'bash -s' < exec-pre-start.sh)
	done
fi
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
	ret_benchmark=$(ssh -i id_ed25519_dos_test -o StrictHostKeyChecking=no sol@$sship 'bash -s' < exec-dos-test.sh)
done

echo ----- stage: wait for benchmark to end ------
sleep_time=$(echo "$DURATION+10" | bc)
sleep $sleep_time

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

## PASS ENV
if [[ ! "$TPU_USE_QUIC" ]];then
	TPU_USE_QUIC="false"
fi
if [[ "$TPU_USE_QUIC" == "true" ]];then
	echo "TEST_TYPE=QUIC" >> dos-report-env.sh
else 
	echo "TEST_TYPE=UDP" >> dos-report-env.sh
fi
if [[ "$GIT_COMMIT" ]];then
	echo "GIT_COMMIT=$GIT_COMMIT" >> dos-report-env.sh
fi
if [[ "$CLUSTER_VERSION" ]];then
	echo "CLUSTER_VERSION=$CLUSTER_VERSION" >> dos-report-env.sh
fi
echo "NUM_CLIENT=$NUM_CLIENT" >> dos-report-env.sh
if [[ ! "$KEYPAIR_FILE" ]];then # use default
    KEYPAIR_FILE=large-keypairs.yaml
fi
echo "KEYPAIR_FILE=$KEYPAIR_FILE" >> dos-report-env.sh
if [[ ! "$DURATION" ]];then
	DURATION=1800
fi
echo "DURATION=$DURATION" >> dos-report-env.sh
if [[ ! "$TX_COUNT" ]];then
	if [[ "$TPU_USE_QUIC" == "true" ]];then
		TX_COUNT=2000
	else 
		TX_COUNT=10000
	fi
fi
echo "TX_COUNT=$TX_COUNT" >> dos-report-env.sh

if [[ "$TPU_USE_QUIC" == "true" ]];then
	THREAD_BATCH_SLEEP_MS=10
else 
	THREAD_BATCH_SLEEP_MS=1
fi
echo "THREAD_BATCH_SLEEP_MS=$THREAD_BATCH_SLEEP_MS" >> dos-report-env.sh

if [[ ! "$SUSTAINED" ]];then
    SUSTAINED="false"
fi
echo "SUSTAINED=$SUSTAINED" >> dos-report-env.sh
echo "SLACK_WEBHOOK=$SLACK_WEBHOOK" >> dos-report-env.sh
echo "START_TIME=${start_time}" >> dos-report-env.sh
echo "START_TIME2=${start_time2}" >> dos-report-env.sh
echo "STOP_TIME=${stop_time}" >> dos-report-env.sh
echo "STOP_TIME2=${stop_time2}" >> dos-report-env.sh
cat dos-report-env.sh
ret_dos_report=$(exec ./dos-report.sh)
echo $ret_dos_report
echo ----- stage: remove gc instances ------
echo "instance_name : ${instance_name[@]}"
echo "instance_zone : ${instance_zone[@]}"
for idx in "${!instance_name[@]}"
do
	gcloud compute instances delete --quiet ${instance_name[$idx]} --zone=${instance_zone[$idx]}
	echo delete $vms
done

