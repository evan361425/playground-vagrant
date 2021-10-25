# Vault key-value secret engine
class profile::vault::kv_secrets (
  Array[Hash]      $mount_setting,
  Array[Hash]      $policy_setting,
  Array[Hash]      $client_setting,
  Optional[String] $directory = '/etc/vault.d/kv-secrets',
) {
  file { $directory:
    ensure  => directory,
    owner   => 'vault',
    group   => 'vault',
    require => Package['vault'],
  }

  $additional_env = {
    'MOUNT_SETTING'  => "${directory}/mount-setting.json",
    'POLICY_SETTING' => "${directory}/policy-setting.json",
    'CLIENT_SETTING' => "${directory}/client-setting.json",
  }

  file { "${directory}/.env":
    ensure  => file,
    owner   => 'vault',
    group   => 'vault',
    content => template('profile/vault/cron.env.erb'),
    require => File[$directory],
  }

  file { $additional_env['MOUNT_SETTING']:
    ensure  => file,
    owner   => 'vault',
    group   => 'vault',
    content => to_json($mount_setting),
    require => File[$directory],
  }

  file { $additional_env['POLICY_SETTING']:
    ensure  => file,
    owner   => 'vault',
    group   => 'vault',
    content => to_json($policy_setting),
    require => File[$directory],
  }

  file { $additional_env['CLIENT_SETTING']:
    ensure  => file,
    owner   => 'vault',
    group   => 'vault',
    content => to_json($client_setting),
    require => File[$directory],
  }

  file { "${directory}/initialize.sh":
    ensure  => present,
    owner   => 'vault',
    group   => 'vault',
    mode    => '0755',
    source  => 'puppet:///modules/profile/vault/kv-secrets/initialize.sh',
    path    => "${directory}/initialize.sh",
    require => File[$directory],
  }

  file { "${directory}/generate-tokens.sh":
    ensure  => present,
    owner   => 'vault',
    group   => 'vault',
    mode    => '0755',
    source  => 'puppet:///modules/profile/vault/kv-secrets/generate-tokens.sh',
    path    => "${directory}/generate-tokens.sh",
    require => File[$directory],
  }
}
