# Use consul template for Vault
class profile::vault_cert_generator (
  String $cert_path,
  String $cert_cn,
  String $vault_address,
  String $vault_token,
  # Optional
  Optional[String] $source_folder = '/etc/vault.d/tls',
  Optional[String] $log_file = '/var/log/vault/cert-generator.log',
  Optional[String] $consul_template_version = '0.27.0',
  Optional[String] $http_proxy = "${lookup('profile::vault::http_proxy')}",
  Optional[String] $https_proxy = "${lookup('profile::vault::http_proxy')}",
) {
  package { 'unzip':
    ensure => installed,
  }

  exec { "Create ${source_folder}":
    creates => $source_folder,
    command => "mkdir -p ${source_folder}",
    path    => $::path
  } -> file { $source_folder : }

  $cert_source_ctmpl = "${source_folder}/cert.ctmpl"
  $key_source_ctmpl = "${source_folder}/key.ctmpl"

  file { $cert_source_ctmpl :
    ensure  => present,
    owner   => 'vault',
    group   => 'vault',
    mode    => '0444',
    content => template('profile/vault/cert.ctmpl.erb'),
    require => File[$source_folder]
  }

  file { $key_source_ctmpl :
    ensure  => present,
    owner   => 'vault',
    group   => 'vault',
    mode    => '0444',
    content => template('profile/vault/key.ctmpl.erb'),
    require => File[$source_folder]
  }

  file { $log_file :
    ensure => present,
    owner  => 'vault',
    group  => 'vault',
    mode   => '0644',
  }

  class { 'consul_template':
    http_proxy    => $http_proxy,
    https_proxy   => $https_proxy,
    version       => $consul_template_version,
    config_dir    => '/etc/consul-template',
    pretty_config => true,
    user          => 'vault',
    group         => 'vault',
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
      source      => $cert_source_ctmpl,
      destination => "${source_folder}/cert.pem",
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
      source      => $key_source_ctmpl,
      destination => "${source_folder}/key.pem",
      backup      => true,
      command     => "echo \"$(date +\"%F %T\") - Reload key\" >> ${log_file}",
    },
    require     => [
      File[$log_file],
      File[$key_source_ctmpl]
    ],
  }
}
