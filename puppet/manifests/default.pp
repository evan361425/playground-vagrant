$hashicorp_apt_key_id = 'E8A032E094D8EB4EA189D270DA418C88A3219F7B';
$hashicorp_apt_key_server = 'hkp://keyserver.ubuntu.com:80';
$aws_region = 'ap-northeast-1';

node 'vault-pki-root.example.com' {
  include apt

  include profile::vault

  class { 'profile::vault_pki_root':
    root_token    => lookup('vault_pki_root_root_token'),
    recovery_keys => lookup('vault_pki_root_recovery_keys'),
    mount_setting => {
      type   => 'pki',
      config => {
        max_lease_ttl => '1d'
      }
    },
    pki_setting   => {
      common_name => 'Vault Root CA',
      ttl         => '1d'
    },
  }
}

node 'vault-pki-int.example.com' {
  include apt

  include profile::vault

  class { 'profile::vault_pki_int':
    root_token        => lookup('vault_pki_int_root_token'),
    recovery_keys     => lookup('vault_pki_int_recovery_keys'),
    mount_setting     => {
      type   => 'pki',
      config => {
        max_lease_ttl => '1h'
      }
    },
    pki_setting       => {
      common_name => 'Vault Intermediate CA',
      ttl         => '930s'
    },
    pki_clients       => [
      {
        name               => 'encrypt-service',
        allowed_domains    => 'encrypt-service.com',
        allow_subdomains   => true,
        allow_glob_domains => true,
        max_ttl            => '10m',
        ttl                => '8m'
      },
      {
        name            => 'encrypt-service-client',
        allowed_domains => 'encrypt-service-client.com',
        max_ttl         => '5m',
        ttl             => '3m'
      }
    ],
    pki_root_api_addr => 'http://vault-pki-root.example.com:8200',
  }
}

node 'vault-kv.example.com' {
  include apt

  include profile::vault

  class { 'profile::vault_cert_generator' :
    cert_puppet_source_ctmpl => 'puppet:///modules/profile/consul_template/kv-cert.ctmpl',
    key_puppet_source_ctmpl  => 'puppet:///modules/profile/consul_template/kv-key.ctmpl',
    cert_source_ctmpl        => 'cert.ctmpl',
    cert_destination         => 'cert.pem',
    key_source_ctmpl         => 'key.ctmpl',
    key_destination          => 'key.pem',
    vault_address            => 'http://vault-pki-int.example.com:8200',
    vault_token              => lookup('vault_pki_int_root_token')
  }

  class { 'profile::vault_kv':
    root_token     => lookup('vault_kv_root_token'),
    recovery_keys  => lookup('vault_kv_recovery_keys'),
    mount_setting  => {
      type    => 'kv',
      path    => 'develop',
      options => {
        version => '2'
      }
    },
    policy_setting => {
      name => 'develop-secret-reader-policy',
      path => {
        'develop/*'             => {
          'capabilities' => ['read']
        }
      }
    }
  }
}
