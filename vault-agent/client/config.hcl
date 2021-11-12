pid_file = "client/pid"
exit_after_auth = false

vault {
  ca_cert = "cert-generator/certs/ca.crt"
  client_cert = "cert-generator/certs/client.crt"
  client_key = "cert-generator/certs/client.key"
  tls_min_version = "tls13"
  retry {
    num_retries = 0
  }
}

auto_auth {
  method "cert" {
    name = "localhost"
    ca_cert = "cert-generator/certs/ca.crt"
    client_cert = "cert-generator/certs/client.crt"
    client_key = "cert-generator/certs/client.key"
  }

  sink "file" {
    config {
      path = "client/token.txt"
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
