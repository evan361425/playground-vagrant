# Building intermediate CA by Vault
class profile::vault_pki_int (
  Hash             $mount_setting,
  Hash             $pki_setting,
  Hash             $pki_encrypt_service,
  Hash             $encrypt_service_policy,
  Hash             $encrypt_service_generator_policy,
  String           $pki_root_api_addr,
  String           $pki_root_cn,
  # optional
  Optional[String] $pki_root_token_file = '',
  Optional[String] $recovery_keys = '',
  Optional[String] $api_addr = 'http://0.0.0.0:8200',
) {

  package { 'jq':
    ensure => installed,
  }

  file { '/etc/vault.d/.cron.env':
    ensure  => file,
    owner   => 'vault',
    group   => 'vault',
    content => inline_template("VAULT_RECOVERY_KEYS=${recovery_keys}\nVAULT_API_ADDR=${api_addr}\nPKI_ROOT_API_ADDR=${$pki_root_api_addr}\nPKI_ROOT_TOKEN_FILE=${$pki_root_token_file}\nPKI_ROOT_CN=\"${$pki_root_cn}\""),
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

  file { '/etc/vault.d/pki-encrypt-service.json':
    ensure  => file,
    owner   => 'vault',
    group   => 'vault',
    content => to_json($pki_encrypt_service),
    require => Package['vault'],
  }

  file { '/etc/vault.d/encrypt-service-policy.json':
    ensure  => file,
    owner   => 'vault',
    group   => 'vault',
    content => to_json($encrypt_service_policy),
    require => Package['vault'],
  }

  file { '/etc/vault.d/encrypt-service-generator-policy.json':
    ensure  => file,
    owner   => 'vault',
    group   => 'vault',
    content => to_json($encrypt_service_generator_policy),
    require => Package['vault'],
  }

  file { '/etc/vault.d/INTERMEDIATE_CSR.pem':
    ensure  => file,
    owner   => 'vault',
    group   => 'vault',
    content => inline_template(''),
    require => Package['vault'],
  }

  file { '/etc/vault.d/INTERMEDIATE_CERT.pem':
    ensure  => file,
    owner   => 'vault',
    group   => 'vault',
    content => inline_template(''),
    require => Package['vault'],
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

  file { 'token-checking-scipt':
    ensure => present,
    owner  => 'vault',
    group  => 'vault',
    mode   => '0755',
    source => 'puppet:///modules/profile/vault/token-checking.sh',
    path   => '/etc/vault.d/token-checking.sh',
  }

  file { 'generate-root-token-scipt':
    ensure => present,
    owner  => 'vault',
    group  => 'vault',
    mode   => '0755',
    source => 'puppet:///modules/profile/vault/generate-root-token.sh',
    path   => '/etc/vault.d/generate-root-token.sh',
  }

  file { '/etc/vault.d/pki-checking.log':
    ensure  => file,
    owner   => 'vault',
    group   => 'vault',
    mode    => '0644',
    require => Package['vault'],
  }

  cron { 'pki-checking':
    provider => 'crontab',
    command  => '/etc/vault.d/pki-int-checking.sh >> /etc/vault.d/pki-checking.log 2>&1',
    user     => 'vault',
    minute   => '*/15',
    require  => [
      File['/etc/vault.d/.cron.env'],
      File['pki-checking-scipt'],
      File['/etc/vault.d/pki-checking.log'],
    ],
  }

  # consul_template::watch { 'renew-token':
  #   config_hash => {
  #     perms       => '0644',
  #     source      => '/etc/consul_template/token.ctmpl',
  #     destination => '/etc/consul_template/haproxy.cfg',
  #     backup      => true,
  #     command     => 'systemctl reload haproxy',
  #   },
  #   require     => File['/etc/haproxy/haproxy.ctmpl'],
  # }
}
