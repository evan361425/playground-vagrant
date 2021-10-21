# Building root CA by Vault
class profile::vault::pki_root (
  Hash             $mount_setting,
  Hash             $pki_setting,
  Optional[String] $cron_name = 'pki-root-checking',
  Optional[String] $log_file = "/var/log/vault/${cron_name}.log",
) {
  file { "/etc/vault.d/${cron_name}.token.env":
    ensure  => file,
    owner   => 'vault',
    group   => 'vault',
    require => Package['vault'],
  }

  file { "/etc/vault.d/${cron_name}.env":
    ensure  => file,
    owner   => 'vault',
    group   => 'vault',
    content => template('profile/vault/cron.env.erb'),
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

  file { 'pki-checking-scipt':
    ensure  => present,
    owner   => 'vault',
    group   => 'vault',
    mode    => '0755',
    source  => 'puppet:///modules/profile/vault/pki-root-checking.sh',
    path    => "/etc/vault.d/${cron_name}.sh",
    require => Package['vault'],
  }

  file { $log_file:
    ensure  => file,
    owner   => 'vault',
    group   => 'vault',
    mode    => '0644',
    require => Package['vault'],
  }

  cron { $cron_name:
    provider    => 'crontab',
    environment => "CRON_NAME=${cron_name}",
    command     => "/etc/vault.d/${cron_name}.sh >> ${log_file} 2>&1",
    user        => 'vault',
    minute      => '*/15',
    require     => [
      File[$log_file],
      File['pki-checking-scipt'],
    ],
  }
}
