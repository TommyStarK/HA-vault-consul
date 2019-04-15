#!/bin/bash

check_last_cmd_return_code() {
    if [ $? -ne 0 ]; then
        echo -e "[\033[0;31mHigh-Availability Vault\033[0m] $1. Exiting ..."
        exit 1
    fi
}

if [ ! -f ./ha-vault/creds/admin_token.json ]; then
    echo -e "[\033[0;31mHigh-Availability Vault\033[0m] Not found admin_token.json. Exiting ..."
    exit 1
fi

TOKEN=$(bash -c "cat ha-vault/creds/admin_token.json | jq -r '.auth.client_token'")
TOKEN="${TOKEN%\"}"
TOKEN="${TOKEN#\"}"

read -p $'\e[34m>>>\e[0m Provide address (ip:port) of one Vault server of the cluster ('127.0.0.1:8201' by default): ' address
if [ -z "$address" ]; then
    address="127.0.0.1:8201"
fi

read -p $'\e[34m>>>\e[0m Set domain name service: ' dns
if [ -z "$dns" ]; then
    echo -e "[\033[0;31mHigh-Availability Vault\033[0m] DNS not provided. Exiting ..."
    exit 1
fi

sleep 0.5

echo -e "[\033[0;32mHigh-Availability Vault\033[0m] Mounting Root PKI engine ..."
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
check_last_cmd_return_code "Mounting root PKI engine failed"

if [ -f ./ha-vault/certs/CA_cert.crt ]; then
    echo -e "[\033[0;31mHigh-Availability Vault\033[0m] Found CA root certificate. PKI engine already mounted. Exiting ..."
    exit 1
fi

echo -e "[\033[0;32mHigh-Availability Vault\033[0m] Generating CA root certificate ..."
curl -s --header "X-Vault-Token: $TOKEN"  \
    --request POST \
    --data '
    {
        "common_name": "'"$dns"'",
        "ttl": "87600h"
    }
    ' \
    "http://$address/v1/pki/root/generate/internal" \
    | jq -r ".data.certificate" > ha-vault/certs/CA_cert.crt

if [ "${PIPESTATUS[0]}" -ne 0 ]; then
    rm ./ha-vault/certs/CA_cert.crt
    echo -e "[\033[0;31mHigh-Availability Vault\033[0m] Failed to generate CA root certificate. Exiting ..."
    exit 1
fi

echo -e "[\033[0;32mHigh-Availability Vault\033[0m] Configure CA and CRL URLs ..."
curl -s \
    -o /dev/null \
    --header "X-Vault-Token: $TOKEN"  \
    --request POST \
    --data '
    {
        "issuing_certificates": "http://'"$address"'/v1/pki/ca",
        "crl_distribution_points": "http://'"$address"'/v1/pki/crl"
    }
    ' \
    "http://$address/v1/pki/config/urls"
check_last_cmd_return_code "Configuration of CA/CRL urls failed"

echo -e "[\033[0;32mHigh-Availability Vault\033[0m] Mounting Intermediate PKI engine ..."
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
check_last_cmd_return_code "Mounting intermediate PKI engine failed"

if [ -f ./ha-vault/certs/intermediate.csr ]; then
    echo -e "[\033[0;31mHigh-Availability Vault\033[0m] Found CA intermediate csr. PKI intermediate engine already mounted. Exiting ..."
    exit 1
fi

echo -e "[\033[0;32mHigh-Availability Vault\033[0m] Generating intermediate csr ..."
curl -s --header "X-Vault-Token: $TOKEN" \
    --request POST \
    --data '
    {
        "common_name": "'"$dns"' Intermediate Authority",
        "ttl": "43800h"
    }
    ' \
    "http://$address/v1/pki_int/intermediate/generate/internal" | jq -r ".data.csr" > ha-vault/certs/intermediate.csr

if [ "${PIPESTATUS[0]}" -ne 0 ]; then
    rm ./ha-vault/certs/intermediate.csr
    echo -e "[\033[0;31mHigh-Availability Vault\033[0m] Failed to generate intermediate CA csr. Exiting ..."
    exit 1
fi

csr_pem_to_json() {
    input=$1
    crt_json=""
    while IFS= read -r var
    do
        if [ "${var}" = "-----END CERTIFICATE REQUEST-----" ]; then
            crt_json="${crt_json}${var}"
        else
            crt_json="${crt_json}${var}\n"
        fi
    done < "$input"
}

csr_pem_to_json ha-vault/certs/intermediate.csr

echo -e "[\033[0;32mHigh-Availability Vault\033[0m] Signing intermediate certificate with root certificate ..."
curl -s --header "X-Vault-Token: $TOKEN" \
    --header "Content-Type: application/json" \
    --request POST \
    --data '
    {
        "csr": "'"${crt_json}"'",
        "format": "pem_bundle",
        "ttl": "43800h"
    }' \
    "http://$address/v1/pki/root/sign-intermediate" \
    | jq -r ".data.certificate" > ha-vault/certs/intermediate.cert.pem

if [ "${PIPESTATUS[0]}" -ne 0 ]; then
    rm ./ha-vault/certs/intermediate.cert.pem
    echo -e "[\033[0;31mHigh-Availability Vault\033[0m] Failed to sign intermediate CA certificate. Exiting ..."
    exit 1
fi

crt_pem_to_json() {
    input=$1
    crt_json=""
    while IFS= read -r var
    do
        if [ "${var}" = "-----END CERTIFICATE-----" ]; then
            crt_json="${crt_json}${var}"
        else
            crt_json="${crt_json}${var}\n"
        fi
    done < "$input"
}

crt_pem_to_json ha-vault/certs/intermediate.cert.pem

echo -e "[\033[0;32mHigh-Availability Vault\033[0m] Setting signed certificate to intermediate CA ..."
curl -s \
    -o /dev/null \
    --header "X-Vault-Token: $TOKEN" \
    --request POST \
    --data '
    {
    "certificate": "'"$crt_json"'"
    }' \
    "http://$address/v1/pki_int/intermediate/set-signed" 
check_last_cmd_return_code "Setting signed certificate to intermediate CA failed"

read -p $'\e[34m>>>\e[0m Set endpoint to issue certificate: ' endpoint
if [ -z "$endpoint" ]; then
    echo -e "[\033[0;31mHigh-Availability Vault\033[0m] Endpoint not provided. Exiting ..."
    exit 1
fi

echo -e "[\033[0;32mHigh-Availability Vault\033[0m] Creating a role to allow issuing certificate to subdomains *.$dns ..."
curl -s -o /dev/null \
    --header "X-Vault-Token: $TOKEN" \
    --request POST \
    --data '
    {
        "allowed_domains": "'"$DNS"'",
        "allow_subdomains": true,
        "max_ttl": "720h"
    }
    ' \
    "http://$address/v1/pki_int/roles/$endpoint"
check_last_cmd_return_code "Creation of role to allow issuing certificate to subdomains *.$dns failed"