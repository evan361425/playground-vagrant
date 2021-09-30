# playground-vagrant

The playground for vagrant

**TOC**

- [Puppet](#puppet)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Start vm](#start-vm)
  - [Install vagrant plugin](#install-vagrant-plugin)
  - [Initialize vault](#initialize-vault)
- [Docker](#docker)

## Puppet

### Prerequisites

- virtualbox
- vagrant
- puppet-agent
- librarian-puppet
- make

### Installation

- Puppet-agent

```bash
$ brew cask install puppet-agent-5 pdk
```

- Puppet module

```bash
$ cd puppet
$ librarian-puppet install
```

### Start vm

- Start and login to vm

```bash
$ vagrant up
$ vagrant ssh
```

### Install vagrant plugin

```bash
$ vagrant plugin install vagrant-hostmanager vagrant-hosts vagrant-timezone vagrant-vbguest
```

### Initialize vault

```bash
$ export VAULT_ADDR=http://localhost:8200
$ vault operator init -recovery-shares=1 -recovery-threshold=1
```

## Docker

See details in [docker-engine](docker-engine/README.md)
