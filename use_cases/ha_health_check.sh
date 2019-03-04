#!/bin/bash
for (( i=1; i<4; i++ ))
do  
    echo -e "[\033[0;32mHigh-Availability Vault\033[0m] Health check Vault $i ...\n"
    curl "http://127.0.0.1:820$i/v1/sys/health" | jq
    echo -e '\n'
done
