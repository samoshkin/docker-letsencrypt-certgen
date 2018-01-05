FROM certbot/certbot:v0.20.0

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
  MUST_STAPLE=0 \
  VERBOSE=0

# internal variables not intended for override
ENV \
  PATH="${PATH}:/root/.acme.sh" \
  CERT_HOME=/etc/acme \
  LE_CONFIG_HOME=/etc/acme

# Install acme.sh client
RUN apk add --update curl openssl socat bash \
  && curl -s https://raw.githubusercontent.com/Neilpang/acme.sh/7b8a82ce90c29cb50e88a33a3b61ca0f08469f64/acme.sh | INSTALLONLINE=1 sh \
  && rm -rf /var/cache/apk/*

COPY scripts /le-certgen/scripts
COPY entrypoint.sh /le-certgen/entrypoint.sh

VOLUME /var/ssl
VOLUME /var/acme_challenge_webroot
VOLUME /etc/letsencrypt
VOLUME /etc/acme

EXPOSE 80

ENTRYPOINT ["/le-certgen/entrypoint.sh"]
