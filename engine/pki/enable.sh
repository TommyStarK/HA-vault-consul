
#!/bin/bash

check_last_cmd_return_code() {
    if [ $? -ne 0 ]; then
        echo "[\033[0;31mHigh-Availability Vault\033[0m] Mounting PKI engine failed. Exiting ..."
        exit 1
    fi
}

if [ ! -f ./ha-vault/creds/admin_token.json ]; then
    echo "[\033[0;31mHigh-Availability Vault\033[0m] Not found admin_token.json. Exiting ..."
    exit 1
fi

TOKEN=$(bash -c "cat ha-vault/creds/admin_token.json | jq -r '.auth.client_token'")
TOKEN="${TOKEN%\"}"
TOKEN="${TOKEN#\"}"

read -p $'\e[34m>>>\e[0m Provide address (ip:port) of one Vault server of the cluster: ' address
if [ -z "$address" ]; then
    echo "[\033[0;31mHigh-Availability Vault\033[0m] Address (ip:port) not provided. Exiting ..."
    exit 1
fi

read -p $'\e[34m>>>\e[0m Set domain name service: ' dns
if [ -z "$dns" ]; then
        echo "[\033[0;31mHigh-Availability Vault\033[0m] DNS not provided. Exiting ..."
    exit 1
fi

sleep 0.5

echo "[\033[0;32mHigh-Availability Vault\033[0m] Mounting Root PKI engine ..."
curl -s -o /dev/null \
    --header "X-Vault-Token: $TOKEN" \
    --request POST  \
    --data '
    {
        "type":"pki", 
        "config": { 
            "max_lease_ttl":"87600h" 
        }
    }' \
    "http://$address/v1/sys/mounts/pki"
check_last_cmd_return_code

root_certificate_authority_config()
{
cat <<EOF
{
    "common_name": "$dns",
    "ttl": "87600h"
}
EOF
}

if [ -f ./ha-vault/certs/CA_cert.crt ]; then
    echo "[\033[0;31mHigh-Availability Vault\033[0m] Found CA root certificate. PKI engine already mounted. Exiting ..."
    exit 1
fi

echo "[\033[0;32mHigh-Availability Vault\033[0m] Generating CA root certificate ..."
curl -s --header "X-Vault-Token: $TOKEN"  \
    --request POST \
    --data "$(root_certificate_authority_config)" \
    "http://$address/v1/pki/root/generate/internal" \
    | jq -r ".data.certificate" > ha-vault/certs/CA_cert.crt

if [ "${PIPESTATUS[0]}" -ne 0 ]; then
    rm ./ha-vault/certs/CA_cert.crt
    echo "[\033[0;31mHigh-Availability Vault\033[0m] Failed to generate CA root certificate. Exiting ..."
    exit 1
fi

root_ca_crl_urls()
{
cat <<EOF
{
  "issuing_certificates": "http://$address/v1/pki/ca",
  "crl_distribution_points": "http://$address/v1/pki/crl"
}
EOF
}

echo "[\033[0;32mHigh-Availability Vault\033[0m] Configure CA and CRL URLs ..."
curl -s \
    -o /dev/null \
    --header "X-Vault-Token: $TOKEN"  \
    --request POST \
    --data "$(root_ca_crl_urls)" \
    "http://$address/v1/pki/config/urls"
check_last_cmd_return_code

echo "[\033[0;32mHigh-Availability Vault\033[0m] Mounting Intermediate PKI engine ..."
curl -s -o /dev/null --header "X-Vault-Token: $TOKEN" \
    --request POST  \
    --data '
    {
        "type":"pki", 
        "config": { 
            "max_lease_ttl":"43800h" 
        }
    }' \
    "http://$address/v1/sys/mounts/pki_int"
check_last_cmd_return_code

intermediate_certificate_authority_config()
{
cat <<EOF
{
    "common_name": "$dns Intermediate Authority",
    "ttl": "43800h"
}
EOF
}

if [ -f ./ha-vault/certs/intermediate.csr ]; then
    echo "[\033[0;31mHigh-Availability Vault\033[0m] Found CA intermediate csr. PKI intermediate engine already mounted. Exiting ..."
    exit 1
fi

echo "[\033[0;32mHigh-Availability Vault\033[0m] Generating intermediate csr ..."
curl -s --header "X-Vault-Token: $TOKEN" \
    --request POST \
    --data "$(intermediate_certificate_authority_config)" \
    "http://$address/v1/pki_int/intermediate/generate/internal" | jq -r ".data.csr" > ha-vault/certs/intermediate.csr

if [ "${PIPESTATUS[0]}" -ne 0 ]; then
    rm ./ha-vault/certs/intermediate.csr
    echo "[\033[0;31mHigh-Availability Vault\033[0m] Failed to generate intermediate CA csr. Exiting ..."
    exit 1
fi



# 
# WORK IN PROGRESS 
# 


# sleep 0.5

# intermediate_csr_as_payload()
# {
# # | tr -d '\\n\r'
# # | sed -e 's/\\n/\n/g')
# cat <<EOF
# {
#   "csr": "$(cat certs/intermediate.csr | sed -e 's/\\n//g')",
#   "format": "pem_bundle",
#   "ttl": "43800h"
# }
# EOF
# }

# intermediate_csr_as_payload | tee /dev/tty | jq -c

# echo "[\033[0;32mHigh-Availability Vault\033[0m] Siging intermediate certificate with root certificate ..."
# curl --header "X-Vault-Token: $TOKEN" \
#     --header "Content-Type: application/json" \
#     --request POST \
#     --data "$(intermediate_csr_as_payload)" \
#     http://127.0.0.1:8201/v1/pki/root/sign-intermediate | jq .
# echo ""

# jg -r ".data.certificate" > certs/intermediate.cert.pem


# intermediate_certificate_as_payload()
# {
# cat <<EOF
# {
#   "certificate": "$(cat certs/intermediate.cert.pem)"
# }
# EOF
# }

# echo "[\033[0;32mHigh-Availability Vault\033[0m] Setting signed certificate to intermediate CA ..."
# curl --header "X-Vault-Token: $TOKEN" \
#     --request POST \
#     --data "$(intermediate_certificate_as_payload)" \
#     https://127.0.0.1:8201/v1/pki_int/intermediate/set-signed
# echo ""

# example_role_payload()
# {
# cat <<EOF
# {
#   "allowed_domains": "$DNS",
#   "allow_subdomains": true,
#   "max_ttl": "720h"
# }
# EOF
# }

# echo "[\033[0;32mHigh-Availability Vault\033[0m] Creating a role to allow issuing certificate to subdomains *.$DNS ..."
# curl --header "X-Vault-Token: $TOKEN" \
#     --request POST \
#     --data "$(example_role_payload)" \
#     http://127.0.0.1:8201/v1/pki_int/roles/example-dot-com
# echo ""
