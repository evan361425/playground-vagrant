pid_file = "vault-agent/pid"
exit_after_auth = false

vault {
  ca_cert = "certs/ca.crt"
  client_cert = "certs/client.crt"
  client_key = "certs/client.key"
  // tls_min_version = "tls13"
  retry {
    num_retries = 0
  }
}

auto_auth {
  method "cert" {
    name = "localhost"
    ca_cert = "certs/ca.crt"
    client_cert = "certs/client.crt"
    client_key = "certs/client.key"
  }

  sink "file" {
    config {
      path = "vault-agent/token.txt"
    }
  }
}

cache {
  use_auto_auth_token = true
}

listener "tcp" {
  address = "localhost:8100"
  tls_disable = true
}
