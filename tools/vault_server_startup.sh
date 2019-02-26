#!//bin/bash
sed -e "s/\${cluster_addr}/"$BIND_ADDR"/" \
    -e "s/\${api_addr}/"$BIND_ADDR"/"  \
    -e "s/\${cluster_addr}/"$BIND_ADDR"/" \
    /vault/config_template.hcl > /vault/config/vault.hcl
vault server -config=/vault/config/vault.hcl --log-level=debug