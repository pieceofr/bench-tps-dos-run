#!/usr/bin/env bash
set -ex
# template for testing agent

gsutil cp  gs://bench-tps-dos/id_ed25519_dos_test ./
chmod 600 id_ed25519_dos_test
ssh -i id_ed25519_dos_test -o StrictHostKeyChecking=no sol@34.81.59.225 'bash -s' < exec-pre-start.sh