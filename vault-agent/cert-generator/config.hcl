"consul" = {
  "address" = "localhost:8500"
}

"vault" = {
  "renew_token" = true

  "retry" = {
    "attempts" = 1

    "backoff" = "250ms"
  }
}

"template" = {
  "source" = "/consul-template/config/templates/cert.ctmpl"

  "destination" = "/consul-template/config/certs/client.crt"

  "backup" = false
}

"template" = {
  "source" = "/consul-template/config/templates/redis.ctmpl"

  "destination" = "/consul-template/config/certs/redis/client.crt"

  "backup" = false
}
