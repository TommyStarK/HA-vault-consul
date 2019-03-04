#!/bin/bash

echo -e '[\033[0;32mHigh-Availability Vault\033[0m] Initializing HA Vault ...\n'
curl --request POST --data '{"secret_shares": 5, "secret_threshold": 3}' http://127.0.0.1:8201/v1/sys/init | jq  > vault.keys.json
echo -e '\n'
