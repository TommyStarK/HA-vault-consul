#!/bin/bash

UNSEAL_KEY_1=$(bash -c "cat vault.keys.json | jq .keys[0]")
UNSEAL_KEY_2=$(bash -c "cat vault.keys.json | jq .keys[1]")
UNSEAL_KEY_3=$(bash -c "cat vault.keys.json | jq .keys[2]")

for (( i=1; i<4; i++ ))
do  
  echo -e "[\033[0;32mHigh-Availability Vault\033[0m] Unsealing Vault $i ...\n"
  curl \
    --request POST \
    --data '{"key": '"$UNSEAL_KEY_1"'}' \
    "http://127.0.0.1:820$i/v1/sys/unseal" | jq

  curl \
    --request POST \
    --data '{"key": '"$UNSEAL_KEY_2"'}' \
    "http://127.0.0.1:820$i/v1/sys/unseal" | jq

  curl \
    --request POST \
    --data '{"key": '"$UNSEAL_KEY_3"'}' \
    "http://127.0.0.1:820$i/v1/sys/unseal" | jq
  echo -e '\n'
done
