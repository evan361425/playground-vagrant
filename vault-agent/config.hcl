pid_file = "pidfile"

vault {
  address = "https://vault-kv.example.com:8200"
  ca_cert = "certs/ca.crt"
  client_cert = "certs/client.crt"
  client_key = "certs/client.key"
  tls_server_name = "vault-kv.example.com"
  retry {
    num_retries = 2
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
    config = {
      path = "token.txt"
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
