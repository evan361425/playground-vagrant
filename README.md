# playground-vagrant

The playground for vagrant

<!-- TOC -->

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Start vm](#start-vm)
- [Install vagrant plugin](#install-vagrant-plugin)

<!-- /TOC -->

## Prerequisites

- virtualbox
- vagrant
- puppet-agent
- librarian-puppet
- make

## Installation

- Puppet-agent

```bash
$ brew cask install puppet-agent-5 pdk
```

- Puppet module

```bash
$ cd puppet
$ librarian-puppet install
```

## Start vm

- Start and login to vm

```bash
$ vagrant up
$ vagrant ssh
```

## Install vagrant plugin

```bash
$ vagrant plugin install vagrant-hostmanager vagrant-hosts vagrant-timezone vagrant-vbguest
```
