node 'vault-pki-root.example.com' {
  include profile::vault
  include profile::vault::pki_root
}

node 'vault-pki-int.example.com' {
  include profile::vault
  include profile::vault::pki_int
}

node 'vault-kv.example.com' {
  include profile::vault_root_cert
  include profile::vault
  include profile::vault::cert_generator
  include profile::vault::kv_secrets
}
