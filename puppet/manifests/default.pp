$hashicorp_apt_key_id = 'E8A032E094D8EB4EA189D270DA418C88A3219F7B';
$hashicorp_apt_key_server = 'hkp://keyserver.ubuntu.com:80';
$aws_region = 'ap-northeast-1';

node 'vault-pki-root.example.com' {
  include profile::vault
  include profile::vault::pki_root
}

node 'vault-pki-int.example.com' {
  include profile::vault
  include profile::vault::pki_int
}

node 'vault-kv.example.com' {
  include profile::vault
  include profile::vault::cert_generator
  include profile::vault::kv_secrets
}
