# Sidecar for connecting to Vault server
class profile::vault_agent (
  Hash  $server,
  Array $sinks,
) {
  file { '/usr/local/share/ca-certificates/extra':
    ensure => directory,
  }

  file { '/usr/local/share/ca-certificates/extra/vault-pki-root.crt':
    ensure  => present,
    content => '',
    require => File['/usr/local/share/ca-certificates/extra'],
  }
}
