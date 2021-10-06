$hashicorp_apt_key_id = 'E8A032E094D8EB4EA189D270DA418C88A3219F7B';
$hashicorp_apt_key_server = 'hkp://keyserver.ubuntu.com:80';
$api_addr = 'http://0.0.0.0:8200';
$aws_region = 'ap-northeast-1';

node 'vault-pki-root.example.com' {
  include apt

  class { 'profile::vault':
    enable_ui                => true,
    http_proxy               => '',
    https_proxy              => '',
    api_addr                 => $api_addr,
    hashicorp_apt_key_id     => $hashicorp_apt_key_id,
    hashicorp_apt_key_server => $hashicorp_apt_key_server,
    seal                     => {
      awskms             => {
        region     => $aws_region,
        kms_key_id => lookup('kms_key_id'),
        access_key => lookup('access_key'),
        secret_key => lookup('secret_key'),
      }
    },
    storage                  => {
      dynamodb           => {
        ha_enabled => true,
        region     => $aws_region,
        table      => 'evan-vault-pki-root',
        access_key => lookup('access_key'),
        secret_key => lookup('secret_key'),
      }
    },
    listener                 => {
      tcp                => {
        address     => '0.0.0.0:8200',
        tls_disable => 1
      }
    },
    extra_config             =>{
      service_registration => {
        consul             => {
          address => '0.0.0.0:8500',
          service => 'vault-pki-root'
        }
      }
    }
  }

  class { 'profile::vault_pki_root':
    recovery_keys           => lookup('vault_pki_root_recovery_keys'),
    mount_setting           => {
      type   => 'pki',
      config => {
        max_lease_ttl => '1h'
      }
    },
    pki_setting             => {
      common_name => 'Vault Root CA',
      ttl         => '1h'
    },
    pki_intermediate_policy => {
      path                          => {
        'pki/root/sign-intermediate' => {
          'capabilities' => ['create', 'update']
        },
        'auth/token/renew-self'      => {
          'capabilities' => ['create', 'update']
        },
      }
    }
  }
}

node 'vault-pki-int.example.com' {
  include apt
  class { 'profile::vault':
    enable_ui                => true,
    http_proxy               => '',
    https_proxy              => '',
    api_addr                 => $api_addr,
    hashicorp_apt_key_id     => $hashicorp_apt_key_id,
    hashicorp_apt_key_server => $hashicorp_apt_key_server,
    seal                     => {
      awskms             => {
        region     => $aws_region,
        kms_key_id => lookup('kms_key_id'),
        access_key => lookup('access_key'),
        secret_key => lookup('secret_key'),
      }
    },
    storage                  => {
      dynamodb           => {
        ha_enabled => true,
        region     => $aws_region,
        table      => 'evan-vault-pki-int',
        access_key => lookup('access_key'),
        secret_key => lookup('secret_key'),
      }
    },
    listener                 => {
      tcp                => {
        address     => '0.0.0.0:8200',
        tls_disable => 1
      }
    },
    extra_config             =>{
      service_registration => {
        consul             => {
          address => '0.0.0.0:8500',
          service => 'vault-pki-int'
        }
      }
    }
  }

  class { 'profile::vault_pki_int':
    recovery_keys                    => lookup('vault_pki_int_recovery_keys'),
    mount_setting                    => {
      type   => 'pki',
      config => {
        max_lease_ttl => '1h'
      }
    },
    pki_setting                      => {
      common_name => 'Vault Intermediate CA',
      ttl         => '1h'
    },
    pki_encrypt_service              => {
      allowed_domains    => 'encrypt-service.com',
      allow_subdomains   => true,
      allow_glob_domains => true,
      generate_lease     => true,
      max_ttl            => '2m',
      ttl                => '1m'
    },
    encrypt_service_policy           => {
      path                          => {
        'pki/issue/encrypt-service' => {
          'capabilities' => ['create', 'update']
        },
        'auth/token/renew-self'     => {
          'capabilities' => ['create', 'update']
        },
      }
    },
    encrypt_service_generator_policy => {
      path                                  => {
        'auth/token/create/encrypt-service'  => {
          'capabilities' => ['create', 'update']
        },
        'auth/token/renew-self'              => {
          'capabilities' => ['create', 'update']
        },
        'pki/intermediate/set-signed'        => {
          'capabilities' => ['create', 'update']
        },
        'pki/intermediate/generate/internal' => {
          'capabilities' => ['create', 'update']
        },
      }
    },
    pki_root_api_addr                => 'http://vault-pki-root.example.com:8200',
    pki_root_token_file              => '/etc/vault.d/ROOT_TOKEN',
    pki_root_cn                      => 'Vault Root CA'
  }
}

node 'vault-kv.example.com' {
  include apt
  class { 'profile::vault':
    enable_ui                => true,
    http_proxy               => '',
    https_proxy              => '',
    api_addr                 => $api_addr,
    hashicorp_apt_key_id     => $hashicorp_apt_key_id,
    hashicorp_apt_key_server => $hashicorp_apt_key_server,
    seal                     => {
      awskms             => {
        region     => $aws_region,
        kms_key_id => lookup('kms_key_id'),
        access_key => lookup('access_key'),
        secret_key => lookup('secret_key'),
      }
    },
    storage                  => {
      dynamodb           => {
        ha_enabled => true,
        region     => $aws_region,
        table      => 'evan-vault-kv',
        access_key => lookup('access_key'),
        secret_key => lookup('secret_key'),
      }
    },
    listener                 => {
      tcp                => {
        address     => '0.0.0.0:8200',
        tls_disable => 1
      }
    },
    extra_config             => {}
  }

  class { 'profile::vault_kv':
    recovery_keys                  => lookup('vault_kv_recovery_keys'),
    mount_setting                  => {
      type    => 'kv',
      options => {
        version => '2'
      }
    },
    secret_client_policy           => {
      path => {
        'develop/*'             => {
          'capabilities' => ['read']
        }
      }
    },
    secret_client_generator_policy => {
      path => {
        'auth/token/create/secret-client' => {
          'capabilities' => ['create', 'update']
        },
        'auth/token/renew-self'           => {
          'capabilities' => ['create', 'update']
        },
      }
    }
  }
}
