#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"
bin_dir="$(dirname "$0")"

export CHILLBOX_SERVER_NAME="${CHILLBOX_SERVER_NAME}"
test -n "${CHILLBOX_SERVER_NAME}" || (echo "ERROR $0: CHILLBOX_SERVER_NAME variable is empty" && exit 1)
echo "INFO $0: Using CHILLBOX_SERVER_NAME '${CHILLBOX_SERVER_NAME}'"

export CHILLBOX_SERVER_PORT="${CHILLBOX_SERVER_PORT}"
test -n "${CHILLBOX_SERVER_PORT}" || (echo "ERROR $0: CHILLBOX_SERVER_PORT variable is empty" && exit 1)
echo "INFO $0: Using CHILLBOX_SERVER_PORT '${CHILLBOX_SERVER_PORT}'"

export SERVER_PORT=$CHILLBOX_SERVER_PORT

# shellcheck disable=SC2016
var_curly_regex='${.\+}'

fallback_nginx_conf() {
  nginx_conf="$1"
  test -n "$nginx_conf" || (echo "ERROR $script_name fallback_nginx_conf" >&2 && exit 1)
  if [ -f "/etc/nginx/conf.d/$nginx_conf.bak" ]; then
    echo "INFO $script_name Switching back to previous /etc/nginx/conf.d/$nginx_conf"
    cp "/etc/nginx/conf.d/$nginx_conf" "/etc/nginx/conf.d/$nginx_conf.failed"
    mv "/etc/nginx/conf.d/$nginx_conf.bak" "/etc/nginx/conf.d/$nginx_conf"
    echo "INFO $script_name Please review failed configuration file /etc/nginx/conf.d/$nginx_conf.failed"
  else
    rm -f "/etc/nginx/conf.d/$nginx_conf"
  fi
}

sites=$(find /etc/chillbox/sites -type f -name '*.site.json')
for site_json in $sites; do
  SLUGNAME="$(basename "$site_json" .site.json)"
  export SLUGNAME
  SERVER_NAME="$(jq -r '.server_name' "$site_json")"
  export SERVER_NAME
  VERSION="$(jq -r '.version' "$site_json")"
  export VERSION

  template_path="/etc/chillbox/templates/$SLUGNAME.nginx.conf.template"
  slugname_nginx_conf="$(basename "$template_path" ".template")"

  if [ -f "/etc/nginx/conf.d/$slugname_nginx_conf" ]; then
    cp "/etc/nginx/conf.d/$slugname_nginx_conf" "/etc/nginx/conf.d/$slugname_nginx_conf.bak"
  fi

  "$bin_dir/envsubst-site-env.sh" -c "/etc/chillbox/sites/$SLUGNAME.site.json" \
    < "$template_path" > "/etc/nginx/conf.d/$slugname_nginx_conf"

  if [ -n "$(grep "$var_curly_regex" "/etc/nginx/conf.d/$slugname_nginx_conf" || printf "")" ]; then
    echo "ERROR $script_name: Not all env variables were replaced from $template_path" >&2
    grep -H -n "$var_curly_regex" "/etc/nginx/conf.d/$slugname_nginx_conf"
    fallback_nginx_conf "$slugname_nginx_conf"
  fi

  if nginx -t; then
    if [ -f "/etc/nginx/conf.d/$slugname_nginx_conf" ]; then
      echo "INFO $script_name Passed test of nginx configuration"
    fi
  else
    echo "ERROR $script_name: Failed test of nginx configuration after updating /etc/nginx/conf.d/$slugname_nginx_conf from $template_path." >&2
    fallback_nginx_conf "$slugname_nginx_conf"
  fi

  # Do a sanity check to make sure nginx conf is still good.
  nginx -t

done

template_path=/etc/chillbox/templates/chillbox.nginx.conf.template
chillbox_nginx_conf="$(basename "$template_path" ".template")"

if [ -f "/etc/nginx/conf.d/$chillbox_nginx_conf" ]; then
  cp "/etc/nginx/conf.d/$chillbox_nginx_conf" "/etc/nginx/conf.d/$chillbox_nginx_conf.bak"
fi

# shellcheck disable=SC2016
envsubst '$CHILLBOX_SERVER_NAME $CHILLBOX_SERVER_PORT' < "$template_path" > "/etc/nginx/conf.d/$chillbox_nginx_conf"


if [ -n "$(grep "$var_curly_regex" "/etc/nginx/conf.d/$chillbox_nginx_conf" || printf "")" ]; then
  echo "ERROR $script_name: Not all env variables were replaced from $template_path" >&2
  grep -H -n "$var_curly_regex" "/etc/nginx/conf.d/$chillbox_nginx_conf"
  fallback_nginx_conf "$chillbox_nginx_conf"
fi

if nginx -t; then
  if [ -f "/etc/nginx/conf.d/$chillbox_nginx_conf" ]; then
    echo "INFO $script_name Passed test of nginx configuration"
  fi
else
  echo "ERROR $script_name: Failed test of nginx configuration after updating /etc/nginx/conf.d/$chillbox_nginx_conf from $template_path." >&2
  fallback_nginx_conf "$chillbox_nginx_conf"
fi

# Do a sanity check to make sure nginx conf is still good.
nginx -t
