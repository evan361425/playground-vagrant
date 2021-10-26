# Building root CA by Vault
class profile::vault::pki_root (
  Hash             $mount_setting,
  Hash             $pki_setting,
  Optional[String] $directory = '/etc/vault.d/pki-root',
) {
  file { $directory:
    ensure  => directory,
    owner   => 'vault',
    group   => 'vault',
    require => Package['vault'],
  }

  $additional_env = {
    'MOUNT_SETTING' => "${directory}/mount-setting.pem",
    'PKI_SETTING'   => "${directory}/pki-setting.pem",
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

  file { $additional_env['PKI_SETTING']:
    ensure  => file,
    owner   => 'vault',
    group   => 'vault',
    content => to_json($pki_setting),
    require => File[$directory],
  }

  file { "${directory}/initialize.sh":
    ensure  => present,
    owner   => 'vault',
    group   => 'vault',
    mode    => '0755',
    source  => 'puppet:///modules/profile/vault/pki-root/initialize.sh',
    path    => "${directory}/initialize.sh",
    require => File[$directory],
  }

  file { "${directory}/generate-token.sh":
    ensure  => present,
    owner   => 'vault',
    group   => 'vault',
    mode    => '0755',
    source  => 'puppet:///modules/profile/vault/pki-root/generate-token.sh',
    path    => "${directory}/generate-token.sh",
    require => File[$directory],
  }
}
