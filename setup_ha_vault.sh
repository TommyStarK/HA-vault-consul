#!/bin/bash

address=("8201" "8202" "8203")
address_first_unsealed=""

check_last_cmd_return_code() {
    if [ $? -ne 0 ]; then
        echo -e "[\033[0;31mHigh-Availability Vault\033[0m] setup HA vault failed. Exiting ..."
        exit 1
    fi
}

initialize_and_unseal_vault() {
    if [ -f ./ha-vault/creds/vault.keys.json ]; then
        echo -e "[\033[0;31mHigh-Availability Vault\033[0m] HA vault seems to be already unsealed. Found 'vault.keys.json' in ha-vault/creds/"
        echo -e "[\033[0;31mHigh-Availability Vault\033[0m] Exiting ..."
        exit 1
    fi

    echo -e "[\033[0;32mHigh-Availability Vault\033[0m] Initializing HA Vault ..."
    curl --request POST \
        --data '{"secret_shares": 5, "secret_threshold": 3}' \
        "http://$address_first_unsealed/v1/sys/init" > ha-vault/creds/vault.keys.json > /dev/null 2>&1

    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
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

        curl \
        --request POST \
        --data '{"key": '"$UNSEAL_KEY_1"'}' \
        "http://${address[$i]}/v1/sys/unseal" > /dev/null 2>&1
        check_last_cmd_return_code

        curl \
            --request POST \
            --data '{"key": '"$UNSEAL_KEY_2"'}' \
            "http://${address[$i]}/v1/sys/unseal" > /dev/null 2>&1
        check_last_cmd_return_code
        
        curl \
            --request POST \
            --data '{"key": '"$UNSEAL_KEY_3"'}' \
            "http://${address[$i]}/v1/sys/unseal" > /dev/null 2>&1
        check_last_cmd_return_code
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
    curl --header "X-Vault-Token: $ROOT_TOKEN" \
        --request PUT \
        --data @ha-vault/policies/admin.json \
        "http://${address_first_unsealed}/v1/sys/policies/acl/admin" > /dev/null 2>&1
    check_last_cmd_return_code

    echo -e "[\033[0;32mHigh-Availability Vault\033[0m] Generating provisioner policy ..."
    curl --header "X-Vault-Token: $ROOT_TOKEN" \
        --request PUT \
        --data @ha-vault/policies/provisioner.json \
        "http://${address_first_unsealed}/v1/sys/policies/acl/provisioner" > /dev/null 2>&1
    check_last_cmd_return_code

    echo -e "[\033[0;32mHigh-Availability Vault\033[0m] Generating token attached to admin policy ..."
    curl --header "X-Vault-Token: $ROOT_TOKEN" \
        --request POST \
        --data '{ "policies":"admin" }' \
        "http://${address_first_unsealed}/v1/auth/token/create" > ha-vault/creds/policy_token.json > /dev/null 2>&1
    
    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
        echo -e "[\033[0;31mHigh-Availability Vault\033[0m] Generating token attached to admin policy failed. Exiting ..."
        exit 1
    fi
}

enabling_user_password_auth_engine_and_admin_entity() {
    if [ ! -f ./ha-vault/creds/vault.keys.json ]; then
        echo -e "[\033[0;31mHigh-Availability Vault\033[0m] Not found 'policy_token.json' attached to admin policy. Exiting ..."
        exit 1
    fi

    TOKEN=$(bash -c "cat ha-vault/creds/policy_token.json | jq -r '.auth.client_token'")
    TOKEN="${TOKEN%\"}"
    TOKEN="${TOKEN#\"}"

    sleep 0.5

    echo -e "[\033[0;32mHigh-Availability Vault\033[0m] Enabling user/password auth engine ..."
    curl --header "X-Vault-Token: $TOKEN" \
        --request POST \
        --data '{"type": "userpass"}' \
        "http://$address_first_unsealed/v1/sys/auth/userpass" > /dev/null 2>&1
    check_last_cmd_return_code
    echo ""
    
    echo -e "\033[0;34m>>>\033[0m Set password for admin entity ('admin' by default): "
    read -s psswd && echo
    if [ -z "$psswd" ]; then
        psswd="admin"
    fi

    psswd_handler() {
        cat <<EOF
{
  "password": "$psswd", "policies": "admin"
}
EOF
    }

    echo -e "[\033[0;32mHigh-Availability Vault\033[0m] Creating entity 'admin' ..."
    curl --header "X-Vault-Token: $TOKEN" \
        --request POST \
        --data "$(psswd_handler)" \
        "http://$address_first_unsealed/v1/auth/userpass/users/admin" > /dev/null 2>&1
    check_last_cmd_return_code

    echo -e "[\033[0;32mHigh-Availability Vault\033[0m] Registering 'admin' as new entity ..."
    curl --header "X-Vault-Token: $TOKEN" \
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
        "http://$address_first_unsealed/v1/identity/entity" > /dev/null 2>&1
    check_last_cmd_return_code
    
    psswd_to_payload() {
        cat <<EOF
{
  "password": "$psswd"
}
EOF
    }

    echo -e "[\033[0;32mHigh-Availability Vault\033[0m] Login as 'admin' ..."
    curl --request POST \
        --data "$(psswd_to_payload)" \
        "http://$address_first_unsealed/v1/auth/userpass/login/admin" > ha-vault/creds/admin_token.json > /dev/null 2>&1
    
    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
        echo -e "[\033[0;31mHigh-Availability Vault\033[0m] Login as admin failed. Exiting ..."
        exit 1
    fi
}


for ((i=0; i<${#address[@]}; i++)); do
    let nbr="$i+1"
    read -p $'\e[34m>>>\e[0m Set host (ip) for Vault server n°'"$nbr"' (localhost by default): ' host
    if [ -z "$host" ]; then
        address[$i]="127.0.0.1:${address[$i]}"
    else
        address[$i]="$host:${address[$i]}"
    fi
done

address_first_unsealed=${address[0]} && echo ""
initialize_and_unseal_vault
setup_admin_and_provisioner_policy
enabling_user_password_auth_engine_and_admin_entity
exit 0