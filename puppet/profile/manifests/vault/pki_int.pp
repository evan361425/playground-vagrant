# Building intermediate CA by Vault
class profile::vault::pki_int (
  Hash             $mount_setting,
  Hash             $pki_setting,
  Array            $pki_clients,
  String           $pki_root_api_addr,
  # optional
  Optional[String] $pki_root_token = '',
  Optional[String] $pki_cert_folder = '/etc/vault.d/certs',
  Optional[String] $cron_name = 'pki-int-checking',
  Optional[String] $log_file = "/var/log/vault/${cron_name}.log",
) {
  file { "/etc/vault.d/${cron_name}.token.env":
    ensure  => file,
    owner   => 'vault',
    group   => 'vault',
    require => Package['vault'],
  }

  $additional_env = {
    'PKI_ROOT_API_ADDR' => $pki_root_api_addr,
    'PKI_ROOT_TOKEN'    => $pki_root_token,
    'PEM_CSR'           => "${pki_cert_folder}/csr.pem",
    'PEM_CERT'          => "${pki_cert_folder}/cert.pem"
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

  file { $additional_env['PEM_CSR']:
    ensure  => file,
    owner   => 'vault',
    group   => 'vault',
    content => '',
    require => File[$pki_cert_folder],
  }

  file { additional_env['PEM_CERT']:
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
