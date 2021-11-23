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
  include profile::vault::root_cert
  include profile::vault::cert_generator
  include profile::vault::secrets
  include profile::vault::transit
  include profile::vault::auth
}

node 'vault.example.com' {
  include profile::vault
  include profile::vault::auth
  include profile::vault::secrets
}
