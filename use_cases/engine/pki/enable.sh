
#!/bin/bash

DNS="example.com"
ROOT_TOKEN=$(bash -c "cat certs/vault.keys.json | jq .root_token")
ROOT_TOKEN="${ROOT_TOKEN%\"}"
ROOT_TOKEN="${ROOT_TOKEN#\"}"

sleep 0.5

# pki_engine_config()
# {
# cat <<EOF
# {
#     "type":"pki", 
#     "config": { 
#         "max_lease_ttl":"87600h" 
#     }
# }
# EOF
# }

# echo "[\033[0;32mHigh-Availability Vault\033[0m] Mounting Root PKI engine ..."
# curl --header "X-Vault-Token: $ROOT_TOKEN" \
#     --request POST  \
#     --data "$(pki_engine_config)" \
#     http://127.0.0.1:8201/v1/sys/mounts/pki | jq
# echo "\n"

# sleep 0.5

# root_certificate_authority_config()
# {
# cat <<EOF
# {
#     "common_name": "$DNS",
#     "ttl": "87600h"
# }
# EOF
# }

# echo "[\033[0;32mHigh-Availability Vault\033[0m] Generating root certificate ..."
# curl --header "X-Vault-Token: $ROOT_TOKEN"  \
#     --request POST \
#     --data "$(root_certificate_authority_config)" \
#     http://127.0.0.1:8201/v1/pki/root/generate/internal \
#     | jq -r ".data.certificate" > certs/CA_cert.crt
# echo "\n"

# sleep 0.5

# root_ca_crl_urls()
# {
# cat <<EOF
# {
#   "issuing_certificates": "http://127.0.0.1:8201/v1/pki/ca",
#   "crl_distribution_points": "http://127.0.0.1:8201/v1/pki/crl"
# }
# EOF
# }

# echo "[\033[0;32mHigh-Availability Vault\033[0m] Configure CA and CRL URLs ..."
# curl --header "X-Vault-Token: $ROOT_TOKEN"  \
#     --request POST \
#     --data "$(root_ca_crl_urls)" \
#     http://127.0.0.1:8201/v1/pki/config/urls
# echo "\n"

# sleep 0.5

# pki_engine_intermediate_config()
# {
# cat <<EOF
# {
#     "type":"pki", 
#     "config": { 
#         "max_lease_ttl":"43800h" 
#     }
# }
# EOF
# }

# echo "[\033[0;32mHigh-Availability Vault\033[0m] Mounting Intermediate PKI engine ..."
# curl --header "X-Vault-Token: $ROOT_TOKEN" \
#     --request POST  \
#     --data "$(pki_engine_intermediate_config)" \
#     http://127.0.0.1:8201/v1/sys/mounts/pki_int | jq
# echo "\n"

# sleep 0.5

# intermediate_certificate_authority_config()
# {
# cat <<EOF
# {
#     "common_name": "$DNS Intermediate Authority",
#     "ttl": "43800h"
# }
# EOF
# }

# echo "[\033[0;32mHigh-Availability Vault\033[0m] Generating intermediate csr ..."
# curl --header "X-Vault-Token: $ROOT_TOKEN" \
#     --request POST \
#     --data "$(intermediate_certificate_authority_config)" \
#     http://127.0.0.1:8201/v1/pki_int/intermediate/generate/internal | jq -r ".data.csr" > certs/intermediate.csr
# echo "\n"

sleep 0.5

intermediate_csr_as_payload()
{
# | tr -d '\\n\r'
# | sed -e 's/\\n/\n/g')
cat <<EOF
{
  "csr": "$(cat certs/intermediate.csr | sed -e 's/\\n//g')",
  "format": "pem_bundle",
  "ttl": "43800h"
}
EOF
}

intermediate_csr_as_payload | tee /dev/tty | jq -c

echo "[\033[0;32mHigh-Availability Vault\033[0m] Siging intermediate certificate with root certificate ..."
curl --header "X-Vault-Token: $ROOT_TOKEN" \
    --header "Content-Type: application/json" \
    --request POST \
    --data "$(intermediate_csr_as_payload)" \
    http://127.0.0.1:8201/v1/pki/root/sign-intermediate | jq .
echo "\n"

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
# curl --header "X-Vault-Token: $ROOT_TOKEN" \
#     --request POST \
#     --data "$(intermediate_certificate_as_payload)" \
#     https://127.0.0.1:8201/v1/pki_int/intermediate/set-signed
# echo "\n"

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
# curl --header "X-Vault-Token: $ROOT_TOKEN" \
#     --request POST \
#     --data "$(example_role_payload)" \
#     http://127.0.0.1:8201/v1/pki_int/roles/example-dot-com
# echo "\n"