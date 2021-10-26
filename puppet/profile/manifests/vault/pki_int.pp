# Building intermediate CA by Vault
class profile::vault::pki_int (
  Hash             $mount_setting,
  Hash             $pki_setting,
  Array            $pki_clients,
  String           $pki_root_api_addr,
  Optional[String] $directory = '/etc/vault.d/pki-int',
) {
  file { $directory:
    ensure  => directory,
    owner   => 'vault',
    group   => 'vault',
    require => Package['vault'],
  }

  $additional_env = {
    'MOUNT_SETTING'       => "${directory}/mount-setting.json",
    'PKI_SETTING'         => "${directory}/pki-setting.json",
    'CSR_FILE'            => "${directory}/csr.pem",
    'CERT_FILE'           => "${directory}/cert.pem",
    'PKI_CLIENTS_FILE'    => "${directory}/clients.json",
    'PKI_ROOT_TOKEN_FILE' => "${directory}/pki-root.token.env",
    'PKI_ROOT_API_ADDR'   => $pki_root_api_addr,
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

  file { $additional_env['PKI_CLIENTS_FILE']:
    ensure  => file,
    owner   => 'vault',
    group   => 'vault',
    content => to_json($pki_clients),
    require => File[$directory],
  }

  file { $additional_env['CSR_FILE']:
    ensure  => file,
    owner   => 'vault',
    group   => 'vault',
    require => File[$directory],
  }

  file { $additional_env['CERT_FILE']:
    ensure  => file,
    owner   => 'vault',
    group   => 'vault',
    require => File[$directory],
  }

  file { $additional_env['PKI_ROOT_TOKEN_FILE']:
    ensure  => file,
    owner   => 'vault',
    group   => 'vault',
    require => File[$directory],
  }

  file { "${directory}/initialize.sh":
    ensure  => present,
    owner   => 'vault',
    group   => 'vault',
    mode    => '0755',
    source  => 'puppet:///modules/profile/vault/pki-int/initialize.sh',
    path    => "${directory}/initialize.sh",
    require => File[$directory],
  }

  file { "${directory}/generate-tokens.sh":
    ensure  => present,
    owner   => 'vault',
    group   => 'vault',
    mode    => '0755',
    source  => 'puppet:///modules/profile/vault/pki-int/generate-tokens.sh',
    path    => "${directory}/generate-tokens.sh",
    require => File[$directory],
  }
}
