# AES Vault server
class profile::vault (
  Boolean                    $enable_ui,
  Variant[Hash, Array[Hash]] $listener,
  # encrypted
  Hash                       $seal,
  Hash                       $storage,
  String                     $root_token,
  # common
  String                     $api_addr,
  String                     $hashicorp_apt_key_id,
  String                     $hashicorp_apt_key_server,
  String                     $http_proxy,
  String                     $https_proxy,
  # Optional
  Optional[Hash]             $extra_config = {},
  Optional[String]           $recovery_keys = '',
) {
  package { 'apt':
    ensure => installed,
  }

  apt::key { 'vault-gpg-key-with-proxy':
    id      => $hashicorp_apt_key_id,
    server  => $hashicorp_apt_key_server,
    options => "http-proxy=\"${http_proxy}\"",
    before  => Exec['add-hashicorp-repository'],
  }

  exec { 'add-hashicorp-repository':
    provider => 'shell',
    user     => 'root',
    command  => "export https_proxy=${https_proxy} && export http_proxy=${http_proxy} && /usr/bin/apt-add-repository \"deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main\" && /usr/bin/apt-get update -qq",
    before   => Class['vault'],
  }

  class { 'vault':
    install_method => 'repo',
    enable_ui      => $enable_ui,
    api_addr       => $api_addr,
    seal           => $seal,
    storage        => $storage,
    listener       => $listener,
    extra_config   => $extra_config,
  }

  file { '/etc/vault.d/.env':
    ensure  => present,
    owner   => 'vault',
    group   => 'vault',
    content => inline_template("http_proxy=${http_proxy}\nhttps_proxy=${https_proxy}"),
    require => Package['vault'],
  }

  file_line { 'add-environment-file':
    path              => '/usr/lib/systemd/system/vault.service',
    match_for_absence => true,
    match             => '^EnvironmentFile',
    line              => 'EnvironmentFile=/etc/vault.d/.env',
    after             => '^\[Service\]$',
    require           => [
      Package['vault'],
      File['/etc/vault.d/.env'],
    ],
  }

  file_line { 'use-generated-config':
    path    => '/usr/lib/systemd/system/vault.service',
    match   => '^ExecStart=\/usr\/bin\/vault\ server\ \-config=\/etc\/vault\.d\/vault\.hcl',
    line    => 'ExecStart=/usr/bin/vault server -config=/etc/vault/config.json',
    require => [
      Package['vault'],
      File['/etc/vault.d/.env'],
      File_line['add-environment-file'],
    ],
    notify  => Service['vault'],
  }

  file { 'renew-token-scipt':
    ensure => present,
    owner  => 'vault',
    group  => 'vault',
    mode   => '0755',
    source => 'puppet:///modules/profile/vault/renew-token.sh',
    path   => '/etc/vault.d/renew-token.sh',
  }

  file { 'generate-root-token-scipt':
    ensure => present,
    owner  => 'vault',
    group  => 'vault',
    mode   => '0755',
    source => 'puppet:///modules/profile/vault/generate-root-token.sh',
    path   => '/etc/vault.d/generate-root-token.sh',
  }

  file { '/var/log/vault':
    ensure  => directory,
    owner   => 'vault',
    group   => 'vault',
    require => Package['vault'],
  }
}
