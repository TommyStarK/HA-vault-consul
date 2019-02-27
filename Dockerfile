FROM consul:latest as c
COPY ./consul/agent/client/config.json /consul/config_template.json

FROM vault:latest as v
COPY ./config/vault.hcl /vault/config_template.hcl

FROM alpine:latest
COPY ./vault_node_startup.sh /
COPY --from=c /consul /consul
COPY --from=c /bin/consul /bin/consul
COPY --from=v /vault /vault
COPY --from=v /bin/vault /bin/vault

RUN apk update \
    && apk add bash \
    && mkdir -p /vault/config \
    && chmod 755 /bin/consul \
    && chmod 755 /bin/vault \
    && chmod +x /vault_node_startup.sh

CMD ["/vault_node_startup.sh"]
