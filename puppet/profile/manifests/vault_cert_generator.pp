# Use consul template for Vault
class profile::vault_cert_generator (
  String $cert_puppet_source_ctmpl,
  String $key_puppet_source_ctmpl,
  String $cert_source_ctmpl,
  String $cert_destination,
  String $key_source_ctmpl,
  String $key_destination,
  String $vault_address,
  String $vault_token,
  # Optional
  Optional[String] $source_folder = '/etc/vault.d/tls',
  Optional[String] $log_file = '/etc/consul-template/process.log',
  Optional[String] $version = '0.27.0',
  Optional[String] $https_proxy = '',
  Optional[String] $http_proxy = '',
) {
  package { 'unzip':
    ensure => installed,
  }

  exec { "Create ${source_folder}":
    creates => $source_folder,
    command => "mkdir -p ${source_folder}",
    path    => $::path
  } -> file { $source_folder : }

  file { $cert_source_ctmpl :
    ensure  => present,
    owner   => 'vault',
    group   => 'vault',
    mode    => '0755',
    source  => $cert_puppet_source_ctmpl,
    path    => "${source_folder}/${cert_source_ctmpl}",
    require => File[$source_folder]
  }

  file { $key_source_ctmpl :
    ensure  => present,
    owner   => 'vault',
    group   => 'vault',
    mode    => '0755',
    source  => $key_puppet_source_ctmpl,
    path    => "${source_folder}/${key_source_ctmpl}",
    require => File[$source_folder]
  }

  file { $log_file :
    ensure => present,
    owner  => 'vault',
    group  => 'vault',
    mode   => '0755',
  }

  class { 'consul_template':
    http_proxy    => $http_proxy,
    https_proxy   => $https_proxy,
    version       => $version,
    config_dir    => '/etc/consul-template',
    pretty_config => true,
    group         => 'vault',
    user          => 'vault',
    config_hash   => {
      vault => {
        address     => $vault_address,
        token       => $vault_token,
        renew_token => true,

        retry       => {
          attempts => 1,
          backoff  => '250ms'
        }
      }
    }
  }

  consul_template::watch { 'vault_cert':
    config_hash => {
      perms       => '0644',
      source      => "${source_folder}/${cert_source_ctmpl}",
      destination => "${source_folder}/${cert_destination}",
      backup      => true,
      command     => "echo \"$(date +\"%F %T\") - Reload certificate\" >> ${log_file}",
    },
    require     => [
      File[$log_file],
      File[$cert_source_ctmpl],
    ],
  }

  consul_template::watch { 'vault_key':
    config_hash => {
      perms       => '0644',
      source      => "${source_folder}/${key_source_ctmpl}",
      destination => "${source_folder}/${key_destination}",
      backup      => true,
      command     => "echo \"$(date +\"%F %T\") - Reload key\" >> ${log_file}",
    },
    require     => [
      File[$log_file],
      File[$key_source_ctmpl]
    ],
  }
}