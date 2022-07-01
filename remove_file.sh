#!/usr/bin/env bash
if [[ -f "dos-report-env.sh" ]];then
    rm dos-report-env.sh
	echo "dos-report-env.sh removed"
fi
if [[ -f "exec-dos-test.sh" ]];then
    rm exec-dos-test.sh
	echo "exec-dos-test.sh removed"
fi
if [[ -f "exec-pre-start.sh" ]];then
    rm exec-pre-start.sh
	echo "exec-pre-start.sh removed"
fi
if [[ -f "id_ed25519_dos_test" ]];then
    rm id_ed25519_dos_test
	echo "id_ed25519_dos_test removed"
fi

if [[ -f "query.result" ]];then
    rm query.result
	echo "query.result removed"
fi
if [[ -f "ret_create.out" ]];then
    rm ret_create.out
	echo "ret_create.out removed"
fi