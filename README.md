# HA-vault-consul
High availability Vault using Consul as backend storage.

## Prerequisites

- [Docker](https://docs.docker.com)

## Disclaimer

The source code herein is not production ready. It is meant to understand, learn and manipulate Vault to manage secrets.

It is a simple implementation of the following guide:
* https://learn.hashicorp.com/vault/operations/ops-vault-ha-consul

## Usage

We will use `docker swarm` to deploy our **High Availability** Vault with consul as backend storage.

First, we need to build the images:

```
$ cd ha-vault/
$ docker build . -t vault_server
$ cd consul/
$ docker build . -t consul_server
$ cd ../..
```

Now we have to initialize our swarm cluster:

```
$ docker swarm init
```

We are now running a manager node and so we can deploy our stack:

```
$ docker stack deploy -c stack/vault_server1.yaml vault1
$ docker stack deploy -c stack/vault_server2.yaml vault2
$ docker stack deploy -c stack/vault_server3.yaml vault3
```

To setup your HA-vault, just run the following:

```
$ setup_ha_vault.sh
```

This script will perform the following:

- Vault initialization
- Vault unseal
- Setup an admin policy
- Setup a provisioner policy
- Enable user/password auth engine
- Create **admin** entity attached to admin policy
- Log as admin to retrieve a valid token

> You can now go to http://localhost:8201/ui and authenticate as **admin**.

### PKI engine

A convenient script will help to you to easily mount a `PKI` engine on your HA Vault.
To do so, run:


```
$ ./engine/pki/enable.sh
```

:warning: You must run an initialized, unsealed and setup HA vault before being able to mount a `PKI` engine.

You will have to provide an address (ip:port) of one member of the cluster, as well as a dns.
