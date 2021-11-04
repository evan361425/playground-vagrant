FROM vault:latest

COPY root.crt /usr/local/share/ca-certificates/root.crt

USER root

RUN /usr/sbin/update-ca-certificates

# Overwrite default entry point (vault server -dev)
ENTRYPOINT ["/usr/bin/env"]

EXPOSE 8100

CMD [ "sh", "-c", "vault agent -config=/vault/config/config.hcl -address=$VAULT_ADDR" ]
