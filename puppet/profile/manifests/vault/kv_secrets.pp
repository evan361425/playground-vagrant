# Vault key-value secret engine
class profile::vault::kv_secrets (
  Hash             $mount_setting,
  Hash             $policy_setting,
  Optional[String] $cron_name = 'kv-secrets',
  Optional[String] $mount_file = '/etc/vault.d/mount-kv-setting.json',
  Optional[String] $policy_file = '/etc/vault.d/kv-policy.json',
  Optional[String] $log_file = "/var/log/vault/${cron_name}.log",
) {
  package { 'jq':
    ensure => installed,
  }

  $additional_env = {
    'MOUNT_FILE'  => $mount_file,
    'POLICY_FILE' => $policy_file,
  }

  file { "/etc/vault.d/${cron_name}.env":
    ensure  => present,
    owner   => 'vault',
    group   => 'vault',
    content => template('profile/vault/cron.env.erb'),
    require => Package['vault'],
  }

  file { $mount_file:
    ensure  => file,
    owner   => 'vault',
    group   => 'vault',
    content => to_json($mount_setting),
    require => Package['vault'],
  }

  file { $policy_file:
    ensure  => file,
    owner   => 'vault',
    group   => 'vault',
    content => to_json($policy_setting),
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

  file { $log_file:
    ensure  => present,
    owner   => 'vault',
    group   => 'vault',
    mode    => '0644',
    require => Package['vault'],
  }

  cron { $cron_name:
    provider    => 'crontab',
    environment => "CRON_NAME=${cron_name}",
    command     => "/etc/vault.d/kv-checking.sh >> ${log_file} 2>&1",
    user        => 'vault',
    minute      => '*/15',
    require     => [
      File["/etc/vault.d/${cron_name}.env"],
      File['kv-checking-scipt'],
      File[$log_file],
      File[$mount_file],
      File[$policy_file],
    ],
  }
}
