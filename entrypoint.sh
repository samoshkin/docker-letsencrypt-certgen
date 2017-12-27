#!/usr/bin/env bash

set -eu

if [ "$VERBOSE" -eq 1 ]; then
  set -x
fi

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$CURRENT_DIR/scripts/utils.sh"

export webroot_path="/var/acme_challenge_webroot"
export cert_drop_path="/var/ssl"
export certbot_cert_home="/etc/letsencrypt/live"
export acme_cert_home="$CERT_HOME"

main(){
  local command="$1"

  case "$command" in
    issue|revoke|renew|delete ) ;;
    noop|* )
      log "noop or unknown command: $command. Do nothing"
      exit 0;
      ;;
  esac

  if [ -z "$DOMAINS" ]; then
    log "No domains specified. Use $DOMAIN variable" >&2
    exit 129;
  fi
  local domains_list=$([ -r "$DOMAINS" ] && cat "$DOMAINS" || echo "$DOMAINS");

  log "Execute command: $command"
  log "Domains:\n\n $domains_list\n"
  log "Using 'certbot' client to handle RSA certificate. RSA_ENABLED: $RSA_ENABLED. Key length: $RSA_KEY_LENGTH"
  log "Using 'acme.sh' client to handle ECDSA certificate. ECDSA_ENABLED: $ECDSA_ENABLED. Key length: $ECDSA_KEY_LENGTH"

  printf '%s' "$domains_list" | while read -r domain || [[ -n "$domain" ]]; do
    [ "$RSA_ENABLED" -eq 1 ] && "$CURRENT_DIR/scripts/certbot.sh" "$command" "$domain" || true
    [ "$ECDSA_ENABLED" -eq 1 ] && "$CURRENT_DIR/scripts/acme.sh" "$command" "$domain" || true
  done

  chown -R root:$SSL_GROUP_ID "$cert_drop_path"

  log "Check out following path for certificates and keys: $cert_drop_path"
}

main "$@"