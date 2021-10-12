# Building key/vaule secrets manager
class profile::vault_kv (
  Hash             $mount_setting,
  Hash             $secret_client_policy,
  Hash             $secret_client_generator_policy,
  # optional
  Optional[String] $recovery_keys = '',
  Optional[String] $api_addr = 'http://0.0.0.0:8200',
) {

  package { 'jq':
    ensure => installed,
  }

  file { '/etc/vault.d/.cron.env':
    ensure  => file,
    owner   => 'vault',
    group   => 'vault',
    content => inline_template("VAULT_RECOVERY_KEYS=${recovery_keys}\nVAULT_API_ADDR=${api_addr}"),
    require => Package['vault'],
  }

  file { '/etc/vault.d/mount-setting.json':
    ensure  => file,
    owner   => 'vault',
    group   => 'vault',
    content => to_json($mount_setting),
    require => Package['vault'],
  }

  file { '/etc/vault.d/secret-client-policy.json':
    ensure  => file,
    owner   => 'vault',
    group   => 'vault',
    content => to_json($secret_client_policy),
    require => Package['vault'],
  }

  file { '/etc/vault.d/secret-client-generator-policy.json':
    ensure  => file,
    owner   => 'vault',
    group   => 'vault',
    content => to_json($secret_client_generator_policy),
    require => Package['vault'],
  }

  file { 'kv-checking-scipt':
    ensure  => present,
    owner   => 'vault',
    group   => 'vault',
    mode    => '0755',
    source  => 'puppet:///modules/profile/vault/kv-checking.sh',
    path    => '/etc/vault.d/kv-checking.sh',
    require => [
      Package['vault'],
      Package['jq'],
    ],
  }

  file { 'log-file':
    ensure  => file,
    owner   => 'vault',
    group   => 'vault',
    mode    => '0644',
    source  => '/var/log/vault/kv-checking.log',
    require => Package['vault'],
  }

  cron { 'vault-checking':
    provider => 'crontab',
    command  => '/etc/vault.d/kv-checking.sh >> /etc/vault.d/process.log 2>&1',
    user     => 'vault',
    minute   => '*/15',
    require  => [
      File['/etc/vault.d/.cron.env'],
      File['kv-checking-scipt'],
      File['log-file'],
    ],
  }
}
