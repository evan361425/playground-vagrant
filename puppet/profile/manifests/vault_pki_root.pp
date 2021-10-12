# Building root CA by Vault
class profile::vault_pki_root (
  Hash             $mount_setting,
  Hash             $pki_setting,
  Hash             $pki_intermediate_policy,
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

  file { '/etc/vault.d/pki-setting.json':
    ensure  => file,
    owner   => 'vault',
    group   => 'vault',
    content => to_json($pki_setting),
    require => Package['vault'],
  }

  file { '/etc/vault.d/pki-intermediate-policy.json':
    ensure  => file,
    owner   => 'vault',
    group   => 'vault',
    content => to_json($pki_intermediate_policy),
    require => Package['vault'],
  }

  file { 'pki-checking-scipt':
    ensure  => present,
    owner   => 'vault',
    group   => 'vault',
    mode    => '0755',
    source  => 'puppet:///modules/profile/vault/pki-root-checking.sh',
    path    => '/etc/vault.d/pki-root-checking.sh',
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
    source  => '/var/log/vault/pki-checking.log',
    require => Package['vault'],
  }

  cron { 'pki-checking':
    provider => 'crontab',
    command  => '/etc/vault.d/pki-root-checking.sh >> /var/log/pki-checking.log 2>&1',
    user     => 'vault',
    minute   => '*/15',
    require  => [
      File['/etc/vault.d/.cron.env'],
      File['pki-checking-scipt'],
      File['log-file'],
    ],
  }
}
