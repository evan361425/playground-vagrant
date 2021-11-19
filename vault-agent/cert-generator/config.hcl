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
  "source" = "/consul-template/templates/cert.ctmpl"

  "destination" = "/consul-template/certs/ca.crt"

  "backup" = false
}
