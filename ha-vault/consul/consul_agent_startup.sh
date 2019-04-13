#!/bin/bash
export ADVERTISE_ADDR=$(awk 'END{print $1}' /etc/hosts);
export BIND_ADDR=$ADVERTISE_ADDR;
sed -e "s/\${node_name}/"$NODE_NAME"/" \
    -e "s/\${datacenter}/"$DATACENTER"/" \
    -e "s/\${advertise_addr}/"$ADVERTISE_ADDR"/"  \
    -e "s/\${bind_addr}/"$BIND_ADDR"/"  \
    -e "s/\${join1}/"$JOIN1"/"  \
    -e "s/\${join2}/"$JOIN2"/"  \
    -e "s/\${join3}/"$JOIN3"/"  \
    /consul/config_template.json > /consul/config/config.json
consul agent -config-file=/consul/config/config.json
