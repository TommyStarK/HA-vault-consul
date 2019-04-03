
#!/bin/bash

TOKEN=$(bash -c "cat certs/policy_token.json | jq -r '.auth.client_token'")
TOKEN="${TOKEN%\"}"
TOKEN="${TOKEN#\"}"
rm certs/policy_token.json

sleep 0.5

echo "[\033[0;32mHigh-Availability Vault\033[0m] Enabling user/password secret engine"
curl --header "X-Vault-Token: $TOKEN" \
    --request POST \
    --data '{"type": "userpass"}' \
    http://127.0.0.1:8201/v1/sys/auth/userpass |jq .
echo ""

sleep 0.5

echo "[\033[0;32mHigh-Availability Vault\033[0m] Creating user 'admin' ..."
curl --header "X-Vault-Token: $TOKEN" \
    --request POST \
    --data '{"password": "admin", "policies": "admin"}' \
    http://127.0.0.1:8201/v1/auth/userpass/users/admin |jq .
echo ""

sleep 0.5

admin_entity_payload() {
cat <<EOF
{
  "name": "admin",
  "metadata": {
    "organization": "IBM",
    "team": "Admin"
  },
  "policies": ["admin"]
}
EOF
}

echo "[\033[0;32mHigh-Availability Vault\033[0m] Registering 'admin' as new entity ..."
curl --header "X-Vault-Token: $TOKEN" \
    --request POST \
    --data "$(admin_entity_payload)" \
    http://127.0.0.1:8201/v1/identity/entity |jq .
echo ""

sleep 0.5

echo "[\033[0;32mHigh-Availability Vault\033[0m] Login as 'admin' ..."
curl --request POST \
    --data '{"password": "admin"}' \
    http://127.0.0.1:8201/v1/auth/userpass/login/admin |jq . > certs/user_token.json
echo ""
