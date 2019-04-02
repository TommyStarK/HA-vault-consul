#!//bin/bash
export ADVERTISE_ADDR=$(awk 'END{print $1}' /etc/hosts)
export BIND_ADDR=$ADVERTISE_ADDR
export VAULT_ADDR="http://${BIND_ADDR}:8200"

# fill template and dump consul config
sed -e "s/\${node_name}/"$NODE_NAME"/" \
    -e "s/\${datacenter}/"$DATACENTER"/" \
    -e "s/\${advertise_addr}/"$ADVERTISE_ADDR"/"  \
    -e "s/\${bind_addr}/"$BIND_ADDR"/"  \
    -e "s/\${join1}/"$JOIN1"/"  \
    -e "s/\${join2}/"$JOIN2"/"  \
    -e "s/\${join3}/"$JOIN3"/"  \
    /consul/config_template.json > /consul/config/config.json

# boot consul-agent in client mode in order to join our cluster
consul agent -config-file=/consul/config/config.json &

# fill template and dump vault config
sed -e "s/\${cluster_addr}/"$BIND_ADDR"/" \
    -e "s/\${api_addr}/"$BIND_ADDR"/"  \
    -e "s/\${cluster_addr}/"$BIND_ADDR"/" \
    /vault/config_template.hcl > /vault/config/vault.hcl

echo "export VAULT_ADDR=${VAULT_ADDR}" > /root/.bashrc

# start vault node
vault server -config=/vault/config/vault.hcl --log-level=debug
