# Auto bench-tps-dos-test
Implementation for
[bench-tps-dos gist](https://gist.github.com/joeaba/aba74e87dcd45c132a1ba2ddcaa2af7c)

## Flow
+ creates NUM_CLIENT gc instances
+ downloads solana and builds solana (option)
+ waits for NUM_CLIENT finishing build (option)
+ starts UDP/QUIC bench-tps dos
+ analyzes data by query influxCloud
+ sends report to slack

## Files
+ dos-run.sh 
    Main process. To create gces, prepare environment, run benchmark and generate a report then send to slack
+ start-build-solana.sh
    This downloads solana and builds solana. It is inside the dynamic created instance. 
+ start-dos-test.sh
    This script runs bench-tps dos test. It is inside the dynamic created instance. 
+ exec-start-build-solana-template.sh 
   use to generate exec-start-build-solana.sh which is used for executing start-build-solana.sh 
+ exec-start-dos-test-template.sh 
   use to generate exec-start-dos-test.sh which is used for executing start-dos-test.sh
+ dos-report-env.sh 
    This script stores in bench-tps-dos bucket. It is downloaded by start-dos-test.sh. It has confidential ENV for start-dos-test.sh
+ dos-report.sh
    This script generates report from influxCloud and send report to slack
+ influx_data.sh
    It stores flux commands. dos-report.sh source this.

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
    TPU_USE_QUIC: "false" (UDP test)
    DURATION:  1800
    TX_COUNT:  1000 for quic / 10000 for udp
    SUSTAINED: "false"