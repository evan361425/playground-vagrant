# encoding: utf-8
# -*- mode: ruby -*-
# vi: set ft=ruby :
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure("2") do |config|
    # Vagrant-hostmanager
    config.hostmanager.enabled = true
    config.hostmanager.manage_host = true
    config.hostmanager.manage_guest = true
    config.hostmanager.include_offline = true

    # Box selection
    config.vm.box = 'ubuntu/xenial64'

    # Puppet initialization
    config.vm.provision "shell", path: "./scripts/bootstrap.sh"
    config.vm.synced_folder "puppet/data", "/tmp/vagrant-puppet/data"

    # Puppet global setting
    config.vm.provision :puppet do |puppet|
        puppet.manifests_path = "puppet/manifests"
        puppet.module_path = "puppet/modules"
        puppet.hiera_config_path = "puppet/hiera.yaml"
        puppet.working_directory = "/tmp/vagrant-puppet"
        puppet.options = "--verbose"
    end

    config.vm.define "vault-pki-root" do |root|
        root.vm.hostname = "vault-pki-root.example.com"
        root.vm.network "private_network", ip: "192.168.56.11"
    end

    config.vm.define "vault-pki-int" do |interm|
        interm.vm.hostname = "vault-pki-int.example.com"
        interm.vm.network "private_network", ip: "192.168.56.12"
    end

    config.vm.define "vault-kv" do |kv|
        kv.vm.hostname = "vault-kv.example.com"
        kv.vm.network "private_network", ip: "192.168.56.13"
    end

    config.vm.define "vault" do |kv|
        kv.vm.hostname = "vault.example.com"
        kv.vm.network "private_network", ip: "192.168.56.14"
    end
end
