# Sidecar for connecting to Vault server
class profile::vault_agent (
  Hash  $server,
  Array $sinks,
) {
  file { '/etc/vault_agent':
    ensure => directory,
    owner  => 'vault',
    group  => 'vault',
  }

  file { '/etc/vault_agent/sinks/':
    ensure  => directory,
    owner   => 'vault',
    group   => 'vault',
    require => File['/etc/vault_agent'],
  }
}
