
#!/bin/bash

ROOT_TOKEN=$(bash -c "cat certs/vault.keys.json | jq .root_token")
ROOT_TOKEN="${ROOT_TOKEN%\"}"
ROOT_TOKEN="${ROOT_TOKEN#\"}"

sleep 0.5

