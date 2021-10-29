pid_file = "/vault/config/pid"

vault {
  ca_cert = "/vault/certs/ca.crt"
  client_cert = "/vault/certs/client.crt"
  client_key = "/vault/certs/client.key"
  retry {
    num_retries = 2
  }
}

auto_auth {
  method "cert" {
    name = "localhost"
    ca_cert = "/vault/certs/ca.crt"
    client_cert = "/vault/certs/client.crt"
    client_key = "/vault/certs/client.key"
  }

  sink "file" {
    config = {
      path = "/vault/config/token.txt"
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
