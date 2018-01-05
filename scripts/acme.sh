#!/usr/bin/env bash

set -eu

if [ "$VERBOSE" -eq 1 ]; then
  set -x
fi

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$CURRENT_DIR/utils.sh"

default_acme_args(){
  [ "$VERBOSE" -eq 1 ] && echo "--debug" || echo ""
}

save_acme_cert(){
  local cert_name="$1"
  local cert_dst="$cert_drop_path/$cert_name"

  mkdir -p "$cert_dst/certs" "$cert_dst/private";

  acme.sh \
    --install-cert -d "$cert_name" \
    --ecc \
    --cert-file "$cert_dst/certs/cert.ecc.pem" \
    --ca-file "$cert_dst/certs/chain.ecc.pem" \
    --fullchain-file "$cert_dst/certs/fullchain.ecc.pem" \
    --key-file "$cert_dst/private/privkey.ecc.pem"
}

build_domains_args(){
  local domains="$1"

  echo "$domains" | awk 'BEGIN {RS=","; ORS=" "} { print "-d",$0}'
}

build_challenge_mode_args(){
  local mode="$1";
  local args="";

  if [ "$mode" == "webroot" ]; then
    args="-w $webroot_path"
  fi
  if [ "$mode" == "standalone" ]; then
    args="--standalone"
  fi

  echo $args;
}

issue_esdca_cert(){
  local domains="$1";
  local cert_name="$2";
  local email="$3";

  local args=$(default_acme_args)
  local args="$args $(build_domains_args "$domains")"
  args="$args $(build_challenge_mode_args "$CHALLENGE_MODE")"
  if [ "$STAGING" -eq 1 ]; then
    args="$args --staging";
  fi

  if [ "$MUST_STAPLE" -eq 1 ]; then
    args="$args --ocsp-must-staple";
  fi

  set +e
  acme.sh \
    --issue \
    --ecc \
    --keylength "$ECDSA_KEY_LENGTH" \
    $args

  local retval=$?;
  if [ "$retval" -ne 2 ] && [ "$retval" -ne 0 ]; then
    log "Issue failed for unknown reasons. acme.sh error code: $retval" >&2
    exit $retval;
  fi

  set -e
}

renew_ecdsa_cert(){
  local domains="$1";
  local cert_name="$2";

  local args=$(default_acme_args)
  local args="$args $(build_domains_args "$domains")"
  args="$args $(build_challenge_mode_args "$CHALLENGE_MODE")"
  if [ "$STAGING" -eq 1 ]; then
    args="$args --staging";
  fi
  if [ "$FORCE_RENEWAL" -eq 1 ]; then 
    args="$args --force";
  fi
  
  if [ "$MUST_STAPLE" -eq 1 ]; then
    args="$args --ocsp-must-staple";
  fi

  set +e
  acme.sh \
    --renew \
    --ecc \
    --keylength "$ECDSA_KEY_LENGTH" \
    $args

  local retval=$?;
  if [ "$retval" -ne 2 ] && [ "$retval" -ne 0 ]; then
    log "Renew failed for unknown reasons. acme.sh error code: $retval" >&2
    exit $retval;
  fi

  set -e
}

revoke_ecdsa_cert(){
  local cert_name="$1";

  local args=$(default_acme_args)
  local args="$args -d $cert_name"
  if [ "$STAGING" -eq 1 ]; then
    args="$args --staging";
  fi

  acme.sh \
    --revoke \
    --ecc \
    $args || true
}

delete_ecdsa_cert(){
  local cert_name="$1";

  local args=$(default_acme_args)
  local args="$args -d $cert_name"
  if [ "$STAGING" -eq 1 ]; then
    args="$args --staging";
  fi

  acme.sh \
    --remove \
    --ecc \
    $args || true

  rm -rf "$acme_cert_home/${cert_name}_ecc"
}

main() {
  local command="$1"
  local domains="$2";
  local cert_name=${domains//,*/}
  local email="admin@$cert_name";

  if [ "$command" == "issue" ]; then
    log "Issue ECDSA certificate '$cert_name' for domains '$domains'"

    issue_esdca_cert "$domains" "$cert_name" "$email"
    save_acme_cert "$cert_name"
    change_cert_owner_and_restrict_perms "$cert_name"
  fi

  if [ "$command" == "renew" ]; then
    log "Renew ECDSA certificate '$cert_name' for domains '$domains'"

    renew_ecdsa_cert "$domains" "$cert_name"
    save_acme_cert "$cert_name"
    change_cert_owner_and_restrict_perms "$cert_name"
  fi

  if [ "$command" == "revoke" ]; then
    log "Revoke ECDSA certificate '$cert_name'"

    revoke_ecdsa_cert "$cert_name"
  fi

  if [ "$command" == "delete" ]; then
    log "Delete ECDSA certificate '$cert_name'"

    delete_ecdsa_cert "$cert_name"
    drop_cert "$cert_name" "ecc"
  fi
}

main "$@"