
#!/bin/bash

ROOT_TOKEN=$(bash -c "cat certs/vault.keys.json | jq .root_token")
ROOT_TOKEN="${ROOT_TOKEN%\"}"
ROOT_TOKEN="${ROOT_TOKEN#\"}"

sleep 0.5

generate_adming_policy() {
cat <<EOF
{
  "policy": "# PKI\npath \"pki/*\"\n{\n  capabilities = [\"create\", \"read\", \"update\", \"delete\", \"list\", \"sudo\"]\n}\n\n# PKI intermediary\npath \"pki_int/*\"\n{\n  capabilities = [\"create\", \"read\", \"update\", \"delete\", \"list\", \"sudo\"]\n}\n\n# Identity\npath \"identity/*\"\n{\n  capabilities = [\"create\", \"read\", \"update\", \"delete\", \"list\", \"sudo\"]\n}\n\n# Manage auth methods broadly across Vault\npath \"auth/*\"\n{\n  capabilities = [\"create\", \"read\", \"update\", \"delete\", \"list\", \"sudo\"]\n}\n\n# Create, update, and delete auth methods\npath \"sys/auth/*\"\n{\n  capabilities = [\"create\", \"update\", \"delete\", \"sudo\"]\n}\n\n# List auth methods\npath \"sys/auth\"\n{\n  capabilities = [\"read\"]\n}\n\n# List existing policies\npath \"sys/policies/acl\"\n{\n  capabilities = [\"read\"]\n}\n\n# Create and manage ACL policies \npath \"sys/policies/acl/*\"\n{\n  capabilities = [\"create\", \"read\", \"update\", \"delete\", \"list\", \"sudo\"]\n}\n\n# List, create, update, and delete key/value secrets\npath \"secret/*\"\n{\n  capabilities = [\"create\", \"read\", \"update\", \"delete\", \"list\", \"sudo\"]\n}\n\n# Manage secret engines\npath \"sys/mounts/*\"\n{\n  capabilities = [\"create\", \"read\", \"update\", \"delete\", \"list\", \"sudo\"]\n}\n\n# List existing secret engines.\npath \"sys/mounts\"\n{\n  capabilities = [\"read\"]\n}\n\n# Read health checks\npath \"sys/health\"\n{\n  capabilities = [\"read\", \"sudo\"]\n}"
}
EOF
}

echo "[\033[0;32mHigh-Availability Vault\033[0m] Generating admin policy ..."
# Create admin policy
curl --header "X-Vault-Token: $ROOT_TOKEN" \
    --request PUT \
    --data "$(generate_adming_policy)" \
    http://127.0.0.1:8201/v1/sys/policies/acl/admin |jq .
echo ""

sleep 0.5

generate_provisioner_policy() {
cat <<EOF
{
  "policy": "# Manage auth methods broadly across Vault\npath \"auth/*\"\n{\n  capabilities = [\"create\", \"read\", \"update\", \"delete\", \"list\", \"sudo\"]\n}\n\n# Create, update, and delete auth methods\npath \"sys/auth/*\"\n{\n  capabilities = [\"create\", \"update\", \"delete\", \"sudo\"]\n}\n\n# List auth methods\npath \"sys/auth\"\n{\n  capabilities = [\"read\"]\n}\n\n# List existing policies\npath \"sys/policies/acl\"\n{\n  capabilities = [\"read\"]\n}\n\n# Create and manage ACL policies via API & UI\npath \"sys/policies/acl/*\"\n{\n  capabilities = [\"create\", \"read\", \"update\", \"delete\", \"list\", \"sudo\"]\n}\n\n# List, create, update, and delete key/value secrets\npath \"secret/*\"\n{\n  capabilities = [\"create\", \"read\", \"update\", \"delete\", \"list\"]\n}"
}
EOF
}

echo "[\033[0;32mHigh-Availability Vault\033[0m] Generating provisioner policy ..."
# Create provisioner policy
curl --header "X-Vault-Token: $ROOT_TOKEN" \
    --request PUT \
    --data "$(generate_provisioner_policy)" \
    http://127.0.0.1:8201/v1/sys/policies/acl/provisioner | jq .
echo ""

# Create token
curl --header "X-Vault-Token: $ROOT_TOKEN" \
    --request POST \
    --data '{ "policies":"admin" }' \
    http://127.0.0.1:8201/v1/auth/token/create | jq . > certs/policy_token.json