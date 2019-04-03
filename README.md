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
$ cd img/
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
$ docker stack deploy -c swarm/vault_server1.yaml vault1
$ docker stack deploy -c swarm/vault_server2.yaml vault2
$ docker stack deploy -c swarm/vault_server3.yaml vault3
```

To initialize your HA-vault, just run the following:

```
$ scripts/init.sh
```

A file named `vault.keys.json` holds your root token in the `certs` directory.
You can go to http://localhost:8201/ui and authenticate using the root token.

Now we must enable policies in order to create a user with correct ACL and not use the
root token anymore.

```
$ scripts/setup_policies.sh
```

Then we create an entity user `admin` with the correct ACL:

```
$ scripts/setup_entities_and_groups.sh
```


To enable the PKI engine, run the following:

```
$ scripts/engine/pki/enable.sh
```