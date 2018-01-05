#!/usr/bin/env bash

set -eu

if [ "$VERBOSE" -eq 1 ]; then
  set -x
fi

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$CURRENT_DIR/utils.sh"

default_certbot_args(){
  [ "$VERBOSE" -eq 1 ] && echo "-v" || echo ""
}

save_certbot_cert(){
  local cert_name="$1"
  local cert_src="$certbot_cert_home/$cert_name"
  local cert_dst="$cert_drop_path/$cert_name"

  mkdir -p "$cert_dst/certs" "$cert_dst/private";

  cp -fL "$cert_src/cert.pem" "$cert_dst/certs/cert.rsa.pem";
  cp -fL "$cert_src/chain.pem" "$cert_dst/certs/chain.rsa.pem";
  cp -fL "$cert_src/fullchain.pem" "$cert_dst/certs/fullchain.rsa.pem";
  cp -fL "$cert_src/privkey.pem" "$cert_dst/private/privkey.rsa.pem";
}

build_challenge_mode_args(){
  local mode="$1";
  local args="";

  if [ "$mode" == "webroot" ]; then
    args="--webroot -w $webroot_path"
  fi
  if [ "$mode" == "standalone" ]; then
    args="--standalone"
  fi

  echo $args;
}

issue_or_renew_rsa_cert(){
  local issue_or_renew="$1"
  local domains="$2";
  local cert_name="$3";
  local email="$4";

  local args=$(default_certbot_args)
  local args="$args $(build_challenge_mode_args "$CHALLENGE_MODE")"
  if [ "$STAGING" -eq 1 ]; then
    args="$args --staging";
  fi

  if [ "$issue_or_renew" == "renew" ] && [ "$FORCE_RENEWAL" -eq 1 ]; then
    args="$args --force-renewal";
  else
    args="$args --keep-until-expiring";
  fi

  if [ "$MUST_STAPLE" -eq 1 ]; then
    args="$args --must-staple";
  fi

  certbot certonly \
    --non-interactive \
    --cert-name "$cert_name" \
    -d "$domains" \
    -m "$email" \
    --agree-tos \
    --preferred-challenges http-01 \
    --allow-subset-of-names \
    --rsa-key-size "$RSA_KEY_LENGTH" \
    $args
}

revoke_rsa_cert(){
  local cert_name="$1"
  
  local args=$(default_certbot_args)
  if [ "$STAGING" -eq 1 ]; then
    args="$args --staging";
  fi

  certbot revoke \
    --non-interactive \
    --agree-tos \
    --cert-path "$certbot_cert_home/$cert_name/cert.pem" \
    $args || true
}

delete_rsa_cert(){
  local cert_name="$1"
  
  local args=$(default_certbot_args)
  if [ "$STAGING" -eq 1 ]; then
    args="$args --staging";
  fi

  certbot delete \
    --non-interactive \
    --agree-tos \
    --cert-name "$cert_name" \
    $args || true
}


main() {
  local command="$1"
  local domains="$2";
  local cert_name=${domains//,*/}
  local email="admin@$cert_name";

  if [ "$command" == "issue" ] || [ "$command" == "renew" ]; then
    log "Issue/renew RSA certificate '$cert_name' for domains '$domains'"

    issue_or_renew_rsa_cert "$command" "$domains" "$cert_name" "$email"
    save_certbot_cert "$cert_name"
    change_cert_owner_and_restrict_perms "$cert_name"
  fi

  if [ "$command" == "revoke" ]; then
    log "Revoke RSA certificate '$cert_name' for domains '$domains'"

    revoke_rsa_cert "$cert_name"
  fi

  if [ "$command" == "delete" ]; then
    log "Delete RSA certificate '$cert_name' for domains '$domains' "

    delete_rsa_cert "$cert_name"
    drop_cert "$cert_name" "rsa"
  fi
}

main "$@"