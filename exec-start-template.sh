#!/usr/bin/env bash
source ~/.bashrc
source ~/.profile
cd ~
if [[ -d "bench-tps-dos-run" ]];then
    rm -rf "bench-tps-dos-run"
fi
if [[ -f "start-build-solana.sh" ]];then
    rm -rf "start-build-solana.sh"
fi
if [[ -f "start-dost-test.sh" ]];then
    rm -rf "start-dos-test.sh"
fi
git clone https://github.com/pieceofr/bench-tps-dos-run.git
cp ~/bench-tps-dos-run/start-build-solana.sh .
cp ~/bench-tps-dos-run/start-dos-test.sh .



