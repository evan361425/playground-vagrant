# Vault transit secret engine
class profile::vault::transit (
  Array[Hash] $keys_setting,
) {
  $directory = '/etc/vault.d/secrets'

  file { "${directory}/transit-keys-setting.json":
    ensure  => file,
    owner   => 'vault',
    group   => 'vault',
    content => to_json($keys_setting),
    require => File[$directory],
  }

  file { "${directory}/initialize-transit.sh":
    ensure  => present,
    owner   => 'vault',
    group   => 'vault',
    mode    => '0755',
    source  => 'puppet:///modules/profile/vault/secrets/initialize-transit.sh',
    path    => "${directory}/initialize-transit.sh",
    require => File[$directory],
  }
}
