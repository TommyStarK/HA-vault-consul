#!/bin/bash

echo -e '[\033[0;32mHigh-Availability Vault\033[0m] Initializing HA Vault ...'
curl --request POST --data '{"secret_shares": 5, "secret_threshold": 3}' http://127.0.0.1:8201/v1/sys/init | jq  > vault.keys.json
echo -e '\n'

UNSEAL_KEY_1=$(bash -c "cat vault.keys.json | jq .keys[0]")
UNSEAL_KEY_2=$(bash -c "cat vault.keys.json | jq .keys[1]")
UNSEAL_KEY_3=$(bash -c "cat vault.keys.json | jq .keys[2]")

for (( i=1; i<4; i++ ))
do  
  echo -e "[\033[0;32mHigh-Availability Vault\033[0m] Unsealing Vault $i ..."
  curl \
    --request POST \
    --data '{"key": '"$UNSEAL_KEY_1"'}' \
    "http://127.0.0.1:820$i/v1/sys/unseal" > /dev/null 2>&1

  curl \
    --request POST \
    --data '{"key": '"$UNSEAL_KEY_2"'}' \
    "http://127.0.0.1:820$i/v1/sys/unseal" > /dev/null 2>&1

  curl \
    --request POST \
    --data '{"key": '"$UNSEAL_KEY_3"'}' \
    "http://127.0.0.1:820$i/v1/sys/unseal" > /dev/null 2>&1

 echo -e "[\033[0;32mHigh-Availability Vault\033[0m] Health check Vault $i ..."
 curl "http://127.0.0.1:820$i/v1/sys/health" | jq
 echo -e '\n'
done
