# Auto bench-tps-dos-test

## Files in the scripts
+ create_gce.sh 
    Main process. To create gces, prepare environment, run benchmark and generate a report
+ exec-start-template.sh
    a template to generate 2 files. One is for building solana and another is for dos-test
+ exec-pre-start.sh
    a temporary file generated from exec-start-template.sh. It is send through ssh to evoke start-prepare.sh
+ exec-dos-test.sh
    a temporary file generated from exec-start-template.sh. It is send through ssh to evoke start-dos-test.sh
+ dos-report-env.sh 
    store in bench-tps-dos which contain influx important ENV. It also be appended start-time and stop-time info dynamically.  dos-report.sh sources this
+ dos-report.sh
    generate dos test report and send to the slack
+ influx_data.sh
    flux commands. dos-report.sh source this
+ id_ed25519_dos_test 
    store in the bench-tps-dosbucket. It is the key to ssh to the gce

## Flow
+ create NUM_CLIENT gc instances
+ download solana and build solana
+ wait for NUM_CLIENT finishing build
+ start bench-tps 
+ analyzes data by query influx cloud
+ send report to slack

## ENV in buildkite
```
  BUILD_SOLANA: "false"
  AVAILABLE_ZONE: "us-west2-b asia-east1-b asia-northeast1-a"
  ENDPOINT: "http://123.123.123.123"
  CLUSTER_VERSION: "1.10.29"
  GIT_COMMIT: "7f1fb1455fb571346d0e38129129e99efba2c8a2"
  NUM_CLIENT: 2
  SLACK_WEBHOOK: ""
  USE_TPU_CLIENT: "true"
  TPU_USE_QUIC: "true"
  DURATION: 1800
  TX_COUNT: 1000
  SUSTAINED: "true"
  KEYPAIR_FILE: "xxxxx.yaml"
```
+ Must have ENDPOINT / NUM_CLIENT / SLACK_WEBHOOK 
+ Default 
    USE_TPU_CLIENT: "false"
    TPU_USE_QUIC: "false" (udp test)
    DURATION:  1800
    TX_COUNT:  1000 for quic / 10000 for udp
    SUSTAINED: "false"

+ If GIT_COMMIT / CLUSTER_VERSION is not provided, the report show NA