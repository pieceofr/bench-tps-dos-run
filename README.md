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
  ENDPOINT: "http://123.123.123.123" 
  CLUSTER_VERSION: "1.10.29" (Option)
  GIT_COMMIT: "7f1fb1455fb571346d0e38129129e99efba2c8a2" (Option)
  NUM_CLIENT: 2
  SLACK_WEBHOOK: "https://hooks.slack.com/services/XXXXX/xxxxxx/xxxxxxx"
  DURATION: 1800 (Option)
  TX_COUNT: 2000 (Option)
  TEST_TYPE: "QUIC" (Option)
  KEYPAIR_FILE: "large-keypairs.yaml" (Option)
```
+ Must have ENDPOINT / NUM_CLIENT / SLACK_WEBHOOK
+ Default Type is QUIC with DURATION=1800 and TX_COUNT=2000. Use KEYPAIR_FILE=large-keypairs.yaml
+ If GIT_COMMIT / CLUSTER_VERSION is not provided, the report show NA