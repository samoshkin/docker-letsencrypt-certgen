FROM certbot/certbot

ENV \
  DOMAINS="" \
  RSA_ENABLED=1 \
  ECDSA_ENABLED=1 \
  ECDSA_KEY_LENGTH=ec-256 \
  RSA_KEY_LENGTH=2048 \
  CHALLENGE_MODE=standalone \
  STAGING=1 \
  FORCE_RENEWAL=0 \
  SSL_GROUP_ID=1337 \
  VERBOSE=0

# internal variables not intended for override
ENV \
  PATH="${PATH}:/root/.acme.sh" \
  CERT_HOME=/etc/acme \
  LE_CONFIG_HOME=/etc/acme

# Install acme.sh client
RUN apk add --update curl openssl socat bash \
  && curl -s https://get.acme.sh | sh \
  && rm -rf /var/cache/apk/*

COPY scripts /le-certgen/scripts
COPY entrypoint.sh /le-certgen/entrypoint.sh

VOLUME /var/ssl
VOLUME /var/acme_challenge_webroot
VOLUME /etc/letsencrypt
VOLUME /etc/acme

EXPOSE 80

ENTRYPOINT ["/le-certgen/entrypoint.sh"]
