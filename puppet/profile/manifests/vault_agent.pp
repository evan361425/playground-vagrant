# Sidecar for connecting to Vault server
class profile::vault_agent (
  String                     $role_id,
  String                     $secret_id,
) {
  file { '/etc/vault/.role-id-file':
    ensure  => present,
    owner   => 'vault',
    group   => 'vault',
    mode    => '0640',
    content => inline_template($role_id),
    require => Package['vault'],
  }

  file { '/etc/vault/.secret-id-file':
    ensure  => present,
    owner   => 'vault',
    group   => 'vault',
    mode    => '0640',
    content => inline_template($secret_id),
    require => Package['vault'],
  }
}
