# Certificate authentication
class profile::vault::auth (
  Array[Hash] $mount_setting,
  Optional[Array[Hash]] $policy_setting = [],
) {
  $directory = '/etc/vault.d/auth'

  file { $directory:
    ensure  => directory,
    owner   => 'vault',
    group   => 'vault',
    require => Package['vault'],
  }

  $additional_env = {
    'MOUNT_SETTING' => "${directory}/mount-setting.json",
    'POLICY_SETTING' => "${directory}/policy-setting.json",
  }

  file { "${directory}/.env":
    ensure  => file,
    owner   => 'vault',
    group   => 'vault',
    content => template('profile/vault/.env.erb'),
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

  file { "${directory}/initialize.sh":
    ensure  => present,
    owner   => 'vault',
    group   => 'vault',
    mode    => '0755',
    source  => 'puppet:///modules/profile/vault/auth/initialize.sh',
    path    => "${directory}/initialize.sh",
    require => File[$directory],
  }
}
