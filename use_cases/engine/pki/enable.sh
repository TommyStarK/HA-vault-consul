
#!/bin/bash

DNS="example.com"
ROOT_TOKEN=$(bash -c "cat vault.keys.json | jq .root_token")
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

# root_certificate_authority_config()
# {
# cat <<EOF
# {
#     "common_name": "$DNS",
#     "ttl": "87600h"
# }
# EOF
# }

# root_ca_crl_urls()
# {
# cat <<EOF
# {
#   "issuing_certificates": "http://127.0.0.1:8201/v1/pki/ca",
#   "crl_distribution_points": "http://127.0.0.1:8201/v1/pki/crl"
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

# echo "[\033[0;32mHigh-Availability Vault\033[0m] Generating root certificate ..."
# curl --header "X-Vault-Token: $ROOT_TOKEN"  \
#     --request POST \
#     --data "$(root_certificate_authority_config)" \
#     http://127.0.0.1:8201/v1/pki/root/generate/internal \
#     | jq -r ".data.certificate" > CA_cert.crt
# echo "\n"

# sleep 0.5

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
#     http://127.0.0.1:8201/v1/pki_int/intermediate/generate/internal | jq -r ".data.csr" > intermediate.csr
# echo "\n"

sleep 0.5

payload_intermediate_cert()
{
cat <<EOF
{
  "csr": $(cat intermediate.csr),
  "format": "pem_bundle",
  "ttl": "43800h"
}
EOF
}

echo "$(payload_intermediate_cert)"
echo ""


echo "[\033[0;32mHigh-Availability Vault\033[0m] Siging intermediate certificate with root certificate ..."
curl --header "X-Vault-Token: $ROOT_TOKEN" \
    --request POST \
    --data "$(payload_intermediate_cert)" \
    http://127.0.0.1:8201/v1/pki/root/sign-intermediate | jq -r '.data.certificate' > intermediate.cert.pem
echo "\n"


# tee payload-signed.json <<EOF
# {
#   "certificate": "$(cat intermediate.cert.pem)"
# }
# EOF

# curl --header "X-Vault-Token: $ROOT_TOKEN" \
#     --request POST \
#     --data @payload-signed.json \
#     https://127.0.0.1:8201/v1/pki_int/intermediate/set-signed