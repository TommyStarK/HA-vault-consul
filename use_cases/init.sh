#!/bin/bash

curl --request POST --data '{"secret_shares": 5, "secret_threshold": 3}' http://127.0.0.1:8201/v1/sys/init | jq  > vault.keys.json

cat vault.keys.json
