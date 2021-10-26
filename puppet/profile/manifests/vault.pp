# Vault base profile
class profile::vault (
  Boolean                    $enable_ui,
  Variant[Hash, Array[Hash]] $listener,
  # encrypted
  Hash                       $seal,
  Hash                       $storage,
  # common
  String                     $api_addr,
  String                     $hashicorp_apt_key_id,
  String                     $hashicorp_apt_key_server,
  String                     $http_proxy,
  String                     $https_proxy,
  # Optional
  Optional[String]           $max_lease_ttl = '768h',
  Optional[Boolean]          $disable_audit = false,
  Optional[String]           $audit_path = 'log',
  Optional[String]           $audit_prefix = '',
  Optional[Hash]             $extra_config = {},
  Optional[Array[String]]    $extra_scripts = [],
) {
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
    max_lease_ttl  => $max_lease_ttl,
    extra_config   => $extra_config,
  }

  file { '/etc/vault.d/.env':
    ensure  => present,
    owner   => 'vault',
    group   => 'vault',
    content => inline_template("http_proxy=${http_proxy}\nhttps_proxy=${https_proxy}\nVAULT_ADDR=${api_addr}"),
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

  file { '/etc/vault.d/initialize.sh':
    ensure => present,
    owner  => 'vault',
    group  => 'vault',
    mode   => '0755',
    source => 'puppet:///modules/profile/vault/initialize.sh',
    path   => '/etc/vault.d/initialize.sh',
  }

  file { '/var/log/vault':
    ensure  => directory,
    owner   => 'vault',
    group   => 'vault',
    require => Package['vault'],
  }

  if ($disable_audit) {
    $audit_setting = ''
  } else {
    $audit_setting = to_json({
      type    => 'file',
      options => {
        file_path => "/var/log/vault/${audit_path}",
        prefix    => $audit_prefix
      }
    })
  }

  file { '/etc/vault.d/audit-setting.json':
    ensure  => present,
    owner   => 'vault',
    group   => 'vault',
    mode    => '0444',
    content => $audit_setting,
    path    => '/etc/vault.d/audit-setting.json',
    require => Package['vault'],
  }

  file { '/etc/vault.d/extra-scripts.json':
    ensure  => present,
    owner   => 'vault',
    group   => 'vault',
    mode    => '0444',
    content => to_json($extra_scripts),
    path    => '/etc/vault.d/extra-scripts.json',
    require => Package['vault'],
  }
}
