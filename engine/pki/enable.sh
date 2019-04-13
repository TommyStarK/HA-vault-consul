
#!/bin/bash

if [ ! -f ./ha-vault/creds/admin_token.json ]; then
    echo "[\033[0;31mHigh-Availability Vault\033[0m] Not found admin_token.json. Exiting ..."
    exit 1
fi

TOKEN=$(bash -c "cat ha-vault/creds/admin_token.json | jq -r '.auth.client_token'")
TOKEN="${TOKEN%\"}"
TOKEN="${TOKEN#\"}"

read -p $'\e[34m>>>\e[0m Provide address (ip:port) of one Vault server of the cluster: ' address
if [ -z "$address" ]; then
    echo -e '[\033[0;31mHigh-Availability Vault\033[0m] Address (ip:port) not provided. Exiting ...'
    exit 1
fi

read -p $'\e[34m>>>\e[0m Set domain name service: ' dns
if [ -z "$dns" ]; then
        echo -e '[\033[0;31mHigh-Availability Vault\033[0m] DNS not provided. Exiting ...'
    exit 1
fi

sleep 0.5

echo -e "[\033[0;32mHigh-Availability Vault\033[0m] Mounting Root PKI engine ..."
curl --header "X-Vault-Token: $TOKEN" \
    --request POST  \
    --data '
    {
        "type":"pki", 
        "config": { 
            "max_lease_ttl":"87600h" 
        }
    }' \
    "http://$address/v1/sys/mounts/pki" | jq && echo ""

root_certificate_authority_config()
{
cat <<EOF
{
    "common_name": "$dns",
    "ttl": "87600h"
}
EOF
}

echo -e "[\033[0;32mHigh-Availability Vault\033[0m] Generating root certificate ..."
curl --header "X-Vault-Token: $TOKEN"  \
    --request POST \
    --data "$(root_certificate_authority_config)" \
    "http://$address/v1/pki/root/generate/internal" \
    | jq -r ".data.certificate" > ha-vault/certs/CA_cert.crt && echo ""

root_ca_crl_urls()
{
cat <<EOF
{
  "issuing_certificates": "http://$address/v1/pki/ca",
  "crl_distribution_points": "http://$address/v1/pki/crl"
}
EOF
}

echo -e "[\033[0;32mHigh-Availability Vault\033[0m] Configure CA and CRL URLs ..."
curl --header "X-Vault-Token: $TOKEN"  \
    --request POST \
    --data "$(root_ca_crl_urls)" \
    "http://$address/v1/pki/config/urls" | jq && echo ""

echo -e "[\033[0;32mHigh-Availability Vault\033[0m] Mounting Intermediate PKI engine ..."
curl --header "X-Vault-Token: $TOKEN" \
    --request POST  \
    --data '
    {
        "type":"pki", 
        "config": { 
            "max_lease_ttl":"43800h" 
        }
    }' \
    "http://$address/v1/sys/mounts/pki_int" | jq && echo ""

intermediate_certificate_authority_config()
{
cat <<EOF
{
    "common_name": "$dns Intermediate Authority",
    "ttl": "43800h"
}
EOF
}

echo -e "[\033[0;32mHigh-Availability Vault\033[0m] Generating intermediate csr ..."
curl --header "X-Vault-Token: $TOKEN" \
    --request POST \
    --data "$(intermediate_certificate_authority_config)" \
    "http://$address/v1/pki_int/intermediate/generate/internal" | jq -r ".data.csr" > ha-vault/certs/intermediate.csr && echo ""

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