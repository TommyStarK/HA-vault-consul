#!/bin/bash

which jq

UNSEAL_KEY_1=`cat vault.keys.json | jq .keys[0]`
UNSEAL_KEY_2=$(cat vault.keys.json | jq .keys[1])
UNSEAL_KEY_3=$(cat vault.keys.json | jq .keys[2])
ROOT_TOKEN=$(cat vault.keys.json | jq .root_token)

echo $UNSEAL_KEY_1
echo $UNSEAL_KEY_2
echo $UNSEAL_KEY_3
echo $ROOT_TOKEN
