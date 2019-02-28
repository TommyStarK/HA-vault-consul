# HA-vault-consul
High availability Vault using Consul as backend storage.

## Prerequisites

- [Docker](https://docs.docker.com)

## Disclaimer

The source code herein is not production ready. It is meant to understand, learn and manipulate Vault to manage secrets.

## Usage

This docker-compose file aims to spawn easily an **High Availability** Vault using a Consul cluster as backend storage for
**demo purposes only**.

It is a simple implementation of the following guide:
* https://learn.hashicorp.com/vault/operations/ops-vault-ha-consul

```
$ docker-compose up
```
