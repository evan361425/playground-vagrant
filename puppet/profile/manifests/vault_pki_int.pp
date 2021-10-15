# Building intermediate CA by Vault
class profile::vault_pki_int (
  Hash             $mount_setting,
  Hash             $pki_setting,
  Array            $pki_clients,
  String           $pki_root_api_addr,
  # optional
  Optional[String] $pki_root_token = '',
  Optional[String] $pki_cert_folder = '/etc/vault.d/certs',
  Optional[String] $root_token = '',
  Optional[String] $recovery_keys = '',
) {

  package { 'jq':
    ensure => installed,
  }

  file { '/etc/vault.d/.cron.env':
    ensure  => file,
    owner   => 'vault',
    group   => 'vault',
    content => inline_template("VAULT_RECOVERY_KEYS=${recovery_keys}
VAULT_API_ADDR=${lookup('profile::vault::api_addr')}
VAULT_ROOT_TOKEN=${root_token}
PKI_ROOT_API_ADDR=${pki_root_api_addr}
PKI_ROOT_TOKEN=${pki_root_token}
PEM_CSR=${pki_cert_folder}/INTERMEDIATE_CSR.pem
PEM_CERT=${pki_cert_folder}/INTERMEDIATE_CERT.pem"),
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

  file { '/etc/vault.d/pki-clients.json':
    ensure  => file,
    owner   => 'vault',
    group   => 'vault',
    content => to_json($pki_clients),
    require => Package['vault'],
  }

  file { $pki_cert_folder:
    ensure  => directory,
    owner   => 'vault',
    group   => 'vault',
    require => Package['vault'],
  }

  file { "${pki_cert_folder}/INTERMEDIATE_CSR.pem":
    ensure  => file,
    owner   => 'vault',
    group   => 'vault',
    content => '',
    require => File[$pki_cert_folder],
  }

  file { "${pki_cert_folder}/INTERMEDIATE_CERT.pem":
    ensure  => file,
    owner   => 'vault',
    group   => 'vault',
    content => '',
    require => File[$pki_cert_folder],
  }

  file { 'pki-checking-scipt':
    ensure  => present,
    owner   => 'vault',
    group   => 'vault',
    mode    => '0755',
    source  => 'puppet:///modules/profile/vault/pki-int-checking.sh',
    path    => '/etc/vault.d/pki-int-checking.sh',
    require => [
      Package['vault'],
      Package['jq'],
    ],
  }

  file { '/var/log/vault/pki-checking.log':
    ensure  => file,
    owner   => 'vault',
    group   => 'vault',
    mode    => '0644',
    require => Package['vault'],
  }

  cron { 'pki-checking':
    provider => 'crontab',
    command  => '/etc/vault.d/pki-int-checking.sh >> /var/log/vault/pki-checking.log 2>&1',
    user     => 'vault',
    minute   => '*/15',
    require  => [
      File['/etc/vault.d/.cron.env'],
      File['pki-checking-scipt'],
      File['/var/log/vault/pki-checking.log'],
    ],
  }
}
