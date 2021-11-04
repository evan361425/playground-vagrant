FROM hashicorp/consul-template:latest

COPY root.crt /usr/local/share/ca-certificates/root.crt

USER root

RUN /usr/sbin/update-ca-certificates

ENTRYPOINT ["/usr/bin/env"]

CMD [ "sh", "-c", "consul-template -config=/consul-template/config/config.hcl -vault-addr=$PKI_INT_VAULT_ADDR -vault-token=$PKI_INT_VAULT_TOKEN" ]
