#!/usr/bin/env sh

set -o errexit

export CHILLBOX_SERVER_NAME=${CHILLBOX_SERVER_NAME}
test -n "${CHILLBOX_SERVER_NAME}" || (echo "ERROR $0: CHILLBOX_SERVER_NAME variable is empty" && exit 1)
echo "INFO $0: Using CHILLBOX_SERVER_NAME '${CHILLBOX_SERVER_NAME}'"

export CHILLBOX_SERVER_PORT=${CHILLBOX_SERVER_PORT}
test -n "${CHILLBOX_SERVER_PORT}" || (echo "ERROR $0: CHILLBOX_SERVER_PORT variable is empty" && exit 1)
echo "INFO $0: Using CHILLBOX_SERVER_PORT '${CHILLBOX_SERVER_PORT}'"

export server_port=$CHILLBOX_SERVER_PORT
sites=$(find /etc/chillbox/sites -type f -name '*.site.json')
for site_json in $sites; do
  slugname=${site_json%.site.json}
  slugname=${slugname#/etc/chillbox/sites/}
  export slugname
  export server_name="$slugname.test"
  export version="$(jq -r '.version' $site_json)"

  eval $(jq -r \
      '.env[] | "export " + .name + "=" + .value' $site_json \
        | envsubst "$(cat /etc/chillbox/env_names | xargs)")

  site_env_names=$(jq -r '.env[] | "$" + .name' /etc/chillbox/sites/$slugname.site.json | xargs)
  site_env_names="$(cat /etc/chillbox/env_names | xargs) $site_env_names"

  template_path=/etc/chillbox/templates/$slugname.nginx.conf.template
  template_file=$(basename $template_path)
  envsubst "${site_env_names}" < $template_path > /etc/nginx/conf.d/${template_file%.template}
done

template_path=/etc/chillbox/templates/chillbox.nginx.conf.template
template_file=$(basename $template_path)
envsubst '$CHILLBOX_SERVER_NAME $CHILLBOX_SERVER_PORT' < $template_path > /etc/nginx/conf.d/${template_file%.template}

