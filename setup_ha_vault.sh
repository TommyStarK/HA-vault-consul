#!/bin/bash

address=("8201" "8202" "8203")
address_first_unsealed=""

check_last_cmd_return_code() {
    if [ $? -ne 0 ]; then
        echo -e "[\033[0;31mHigh-Availability Vault\033[0m] $1. Exiting ..."
        exit 1
    fi
}

initialize_and_unseal_vault() {
    if [ -f ./ha-vault/creds/vault.keys.json ]; then
        echo -e "[\033[0;31mHigh-Availability Vault\033[0m] HA vault seems to be already unsealed. Found 'vault.keys.json' in ha-vault/creds/. Exiting ..."
        exit 1
    fi

    echo -e "[\033[0;32mHigh-Availability Vault\033[0m] Initializing HA Vault ..."
    curl -s --request POST \
        --data '{"secret_shares": 5, "secret_threshold": 3}' \
        "http://$address_first_unsealed/v1/sys/init" > ha-vault/creds/vault.keys.json

    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
        rm ./ha-vault/creds/vault.keys.json
        echo -e "[\033[0;31mHigh-Availability Vault\033[0m] Initialization HA vault failed. Exiting ..."
        exit 1
    fi

    sleep 1

    UNSEAL_KEY_1=$(bash -c "cat ha-vault/creds/vault.keys.json | jq .keys[0]")
    UNSEAL_KEY_2=$(bash -c "cat ha-vault/creds/vault.keys.json | jq .keys[1]")
    UNSEAL_KEY_3=$(bash -c "cat ha-vault/creds/vault.keys.json | jq .keys[2]")

    for i in ${!address[@]}; do
        let nbr="$i+1"
        echo -e "[\033[0;32mHigh-Availability Vault\033[0m] Unsealing vault $nbr ..."

        curl -s -o /dev/null \
        --request POST \
        --data '{"key": '"$UNSEAL_KEY_1"'}' \
        "http://${address[$i]}/v1/sys/unseal"
        check_last_cmd_return_code "Unseal vault $nbr with key: $UNSEAL_KEY_1 failed"

        curl -s -o /dev/null \
            --request POST \
            --data '{"key": '"$UNSEAL_KEY_2"'}' \
            "http://${address[$i]}/v1/sys/unseal"
        check_last_cmd_return_code "Unseal vault $nbr with key: $UNSEAL_KEY_2 failed"
        
        curl -s -o /dev/null \
            --request POST \
            --data '{"key": '"$UNSEAL_KEY_3"'}' \
            "http://${address[$i]}/v1/sys/unseal"
        check_last_cmd_return_code "Unseal vault $nbr with key: $UNSEAL_KEY_3 failed"
    done

}

setup_admin_and_provisioner_policy() {
    if [ ! -f ./ha-vault/creds/vault.keys.json ]; then
        echo -e "[\033[0;31mHigh-Availability Vault\033[0m] HA vault must be initialized and unsealed first. Exiting ..."
        exit 1
    fi

    ROOT_TOKEN=$(bash -c "cat ha-vault/creds/vault.keys.json | jq .root_token")
    ROOT_TOKEN="${ROOT_TOKEN%\"}"
    ROOT_TOKEN="${ROOT_TOKEN#\"}"

    echo -e "[\033[0;32mHigh-Availability Vault\033[0m] Generating admin policy ..."
    curl -s -o /dev/null \
        --header "X-Vault-Token: $ROOT_TOKEN" \
        --request PUT \
        --data @ha-vault/policies/admin.json \
        "http://${address_first_unsealed}/v1/sys/policies/acl/admin"
    check_last_cmd_return_code "Generating admin policy failed"

    echo -e "[\033[0;32mHigh-Availability Vault\033[0m] Generating provisioner policy ..."
    curl -s -o /dev/null \
        --header "X-Vault-Token: $ROOT_TOKEN" \
        --request PUT \
        --data @ha-vault/policies/provisioner.json \
        "http://${address_first_unsealed}/v1/sys/policies/acl/provisioner"
    check_last_cmd_return_code "Generating provisioner policy failed"

    if [ -f ./ha-vault/creds/policy_token.json ]; then
        rm ./ha-vault/creds/policy_token.json
    fi

    echo -e "[\033[0;32mHigh-Availability Vault\033[0m] Generating token attached to admin policy ..."
    curl -s \
        --header "X-Vault-Token: $ROOT_TOKEN" \
        --request POST \
        --data '{ "policies": "admin" }' \
        "http://${address_first_unsealed}/v1/auth/token/create" > ha-vault/creds/policy_token.json

    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
        rm ./ha-vault/creds/policy_token.json
        echo -e "[\033[0;31mHigh-Availability Vault\033[0m] Generating token attached to admin policy failed. Exiting ..."
        exit 1
    fi
}

enabling_user_password_auth_engine_and_admin_entity() {
    if [ ! -f ./ha-vault/creds/policy_token.json ]; then
        echo -e "[\033[0;31mHigh-Availability Vault\033[0m] Not found 'policy_token.json' attached to admin policy. Exiting ..."
        exit 1
    fi

    TOKEN=$(bash -c "cat ha-vault/creds/policy_token.json | jq -r '.auth.client_token'")
    TOKEN="${TOKEN%\"}"
    TOKEN="${TOKEN#\"}"

    sleep 0.5

    echo -e "[\033[0;32mHigh-Availability Vault\033[0m] Enabling user/password auth engine ..."
    curl -s -o /dev/null \
        --header "X-Vault-Token: $TOKEN" \
        --request POST \
        --data '{ "type": "userpass" }' \
        "http://$address_first_unsealed/v1/sys/auth/userpass"
    check_last_cmd_return_code "Enabling user/password auth engine failed"
    
    echo
    echo -e "\033[0;34m>>>\033[0m Set password for admin entity ('admin' by default): "
    read -s psswd && echo
    if [ -z "$psswd" ]; then
        psswd="admin"
    fi

    echo -e "[\033[0;32mHigh-Availability Vault\033[0m] Creating entity 'admin' ..."
    curl -s \
        -o /dev/null \
        --header "X-Vault-Token: $TOKEN" \
        --request POST \
        --data '
        {
            "password": "'"$psswd"'", 
            "policies": "admin"
        }
        ' \
        "http://$address_first_unsealed/v1/auth/userpass/users/admin"
    check_last_cmd_return_code "Creating 'admin' entity failed"

    echo -e "[\033[0;32mHigh-Availability Vault\033[0m] Registering 'admin' as new entity ..."
    curl -s -o /dev/null \
        --header "X-Vault-Token: $TOKEN" \
        --request POST \
        --data '
        {
            "name": "admin",
            "metadata": {
                "team": "Admin"
            },
            "policies": ["admin"]
        }
        ' \
        "http://$address_first_unsealed/v1/identity/entity"
    check_last_cmd_return_code "Registering 'admin' as new entity failed"
    
    if [ -f ./ha-vault/creds/admin_token.json ]; then
        rm ./ha-vault/creds/admin_token.json
    fi

    echo -e "[\033[0;32mHigh-Availability Vault\033[0m] Login as 'admin' ..."
    curl -s --request POST \
        --data '
        {
            "password": "'"$psswd"'"
        }
        ' \
        "http://$address_first_unsealed/v1/auth/userpass/login/admin" > ha-vault/creds/admin_token.json

    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
        rm ./ha-vault/creds/admin_token.json
        echo -e "[\033[0;31mHigh-Availability Vault\033[0m] Login as admin failed. Exiting ..."
        exit 1
    fi
}

echo
for ((i=0; i<${#address[@]}; i++)); do
    let nbr="$i+1"
    read -p $'\e[34m>>>\e[0m Set host (ip) for Vault server n°'"$nbr"' (127.0.0.1 by default): ' host
    if [ -z "$host" ]; then
        address[$i]="127.0.0.1:${address[$i]}"
    else
        address[$i]="$host:${address[$i]}"
    fi
done
echo

address_first_unsealed=${address[0]}
initialize_and_unseal_vault
setup_admin_and_provisioner_policy
enabling_user_password_auth_engine_and_admin_entity
exit 0
