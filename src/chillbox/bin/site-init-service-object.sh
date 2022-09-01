#!/usr/bin/env sh

set -o errexit

bin_dir="$(dirname "$0")"
service_obj="$1"
tmp_artifact="$2"
slugdir="$3"

test -n "${service_obj}" || (echo "ERROR $0: service_obj variable is empty" && exit 1)
echo "INFO $0: Using service_obj '${service_obj}'"

test -n "${tmp_artifact}" || (echo "ERROR $0: tmp_artifact variable is empty" && exit 1)
test -f "${tmp_artifact}" || (echo "ERROR $0: The $tmp_artifact is not a file" && exit 1)
echo "INFO $0: Using tmp_artifact '${tmp_artifact}'"

test -n "${SLUGNAME}" || (echo "ERROR $0: SLUGNAME variable is empty" && exit 1)
echo "INFO $0: Using slugname '${SLUGNAME}'"

test -n "${slugdir}" || (echo "ERROR $0: slugdir variable is empty" && exit 1)
test -d "${slugdir}" || (echo "ERROR $0: slugdir should be a directory" && exit 1)
test -d "$(dirname "${slugdir}")" || (echo "ERROR $0: parent directory of slugdir should be a directory" && exit 1)
echo "INFO $0: Using slugdir '${slugdir}'"

export S3_ARTIFACT_ENDPOINT_URL=${S3_ARTIFACT_ENDPOINT_URL}
test -n "${S3_ARTIFACT_ENDPOINT_URL}" || (echo "ERROR $0: S3_ARTIFACT_ENDPOINT_URL variable is empty" && exit 1)
echo "INFO $0: Using S3_ARTIFACT_ENDPOINT_URL '${S3_ARTIFACT_ENDPOINT_URL}'"

export S3_ENDPOINT_URL=${S3_ENDPOINT_URL}
test -n "${S3_ENDPOINT_URL}" || (echo "ERROR $0: S3_ENDPOINT_URL variable is empty" && exit 1)
echo "INFO $0: Using S3_ENDPOINT_URL '${S3_ENDPOINT_URL}'"

export ARTIFACT_BUCKET_NAME=${ARTIFACT_BUCKET_NAME}
test -n "${ARTIFACT_BUCKET_NAME}" || (echo "ERROR $0: ARTIFACT_BUCKET_NAME variable is empty" && exit 1)
echo "INFO $0: Using ARTIFACT_BUCKET_NAME '${ARTIFACT_BUCKET_NAME}'"

export IMMUTABLE_BUCKET_NAME=${IMMUTABLE_BUCKET_NAME}
test -n "${IMMUTABLE_BUCKET_NAME}" || (echo "ERROR $0: IMMUTABLE_BUCKET_NAME variable is empty" && exit 1)
echo "INFO $0: Using IMMUTABLE_BUCKET_NAME '${IMMUTABLE_BUCKET_NAME}'"

export CHILLBOX_GPG_KEY_NAME=${CHILLBOX_GPG_KEY_NAME}
test -n "${CHILLBOX_GPG_KEY_NAME}" || (echo "ERROR $0: CHILLBOX_GPG_KEY_NAME variable is empty" && exit 1)
echo "INFO $0: Using CHILLBOX_GPG_KEY_NAME '${CHILLBOX_GPG_KEY_NAME}'"

echo "INFO $0: Running site init for service object: ${service_obj}"

# TODO mount tmpfs at /run/tmp/chillbox_secrets

# Extract and set shell variables from JSON input
service_name=""
service_lang_template=""
service_handler=""
service_secrets_config=""
eval "$(echo "$service_obj" | jq -r --arg jq_slugname "$SLUGNAME" '@sh "
  service_name=\(.name)
  service_lang_template=\(.lang)
  service_handler=\(.handler)
  service_secrets_config=\( .secrets_config // "" )
  "')"

service_secrets_config_file=""
if [ -n "$service_secrets_config" ]; then
  service_secrets_config_file="/run/tmp/chillbox_secrets/$SLUGNAME/$service_handler/$service_secrets_config"
  service_secrets_config_dir="$(dirname "$service_secrets_config_file")"
  mkdir -p "$service_secrets_config_dir"
  chown -R "$SLUGNAME":"$SLUGNAME" "$service_secrets_config_dir"
  chmod -R 700 "$service_secrets_config_dir"

  "$bin_dir/download-and-decrypt-secrets-config.sh" "$SLUGNAME/$service_handler/$service_secrets_config"
fi
# Need to check if this secrets config file was successfully downloaded since it
# might not exist yet.
if [ -n "$service_secrets_config_file" ] && [ ! -e "$service_secrets_config_file" ]; then
  echo "WARNING $0: No service secrets config file was able to be downloaded and decrypted."
fi

# Extract just the new service handler directory from the tmp_artifact
cd "$(dirname "$slugdir")"
tar x -z -f "$tmp_artifact" "$SLUGNAME/${service_handler}"
chown -R "$SLUGNAME":"$SLUGNAME" "$slugdir"
# Save the service object for later use when updating or removing the service.
echo "$service_obj" | jq -c '.' > "$slugdir/$service_handler.service_handler.json"

# The 'freeze' variable is set from the environment object if at all. Default to
# empty string.
freeze=""
eval "$(echo "$service_obj" | jq -r '.environment // [] | .[] | "export " + .name + "=" + (.value | @sh)' \
  | "$bin_dir/envsubst-site-env.sh" -c "/etc/chillbox/sites/$SLUGNAME.site.json")"

cd "$slugdir/${service_handler}"
if [ "${service_lang_template}" = "flask" ]; then

  mkdir -p "/var/lib/${SLUGNAME}/${service_handler}"
  chown -R "$SLUGNAME":"$SLUGNAME" "/var/lib/${SLUGNAME}"

  python -m venv .venv
  ./.venv/bin/pip install --disable-pip-version-check --compile -r requirements.txt .

  HOST=localhost \
  FLASK_ENV="development" \
  FLASK_INSTANCE_PATH="/var/lib/${SLUGNAME}/${service_handler}" \
  S3_ENDPOINT_URL="$S3_ARTIFACT_ENDPOINT_URL" \
  SECRETS_CONFIG="${service_secrets_config_file}" \
    ./.venv/bin/flask init-db \
    || echo "ERROR $0: Failed to run './.venv/bin/flask init-db' for ${SLUGNAME} ${service_handler}."

  chown -R "$SLUGNAME":"$SLUGNAME" "/var/lib/${SLUGNAME}/"

  # Only for openrc
  mkdir -p /etc/init.d
  cat <<PURR > "/etc/init.d/${SLUGNAME}-${service_name}"
#!/sbin/openrc-run
name="${SLUGNAME}-${service_name}"
description="${SLUGNAME}-${service_name}"
user="$SLUGNAME"
group="dev"
supervisor=s6
s6_service_path=/etc/services.d/${SLUGNAME}-${service_name}
depend() {
  need s6-svscan net localmount
  after firewall
}
PURR
  chmod +x "/etc/init.d/${SLUGNAME}-${service_name}"


  mkdir -p "/etc/services.d/${SLUGNAME}-${service_name}"
  cat <<PURR > "/etc/services.d/${SLUGNAME}-${service_name}/run"
#!/usr/bin/execlineb -P
s6-setuidgid $SLUGNAME
cd $slugdir/${service_handler}
PURR
echo "$service_obj" | jq -r '.environment // [] | .[] | "s6-env " + .name + "=" + (.value | @sh)' \
    | "$bin_dir/envsubst-site-env.sh" -c "/etc/chillbox/sites/$SLUGNAME.site.json" \
    >> "/etc/services.d/${SLUGNAME}-${service_name}/run"
  cat <<PURR >> "/etc/services.d/${SLUGNAME}-${service_name}/run"
s6-env HOST=localhost \
s6-env FLASK_ENV=development
s6-env FLASK_INSTANCE_PATH="/var/lib/${SLUGNAME}/${service_handler}"
s6-env SECRETS_CONFIG=${service_secrets_config_file}
s6-env S3_ENDPOINT_URL=${S3_ENDPOINT_URL}
s6-env ARTIFACT_BUCKET_NAME=${ARTIFACT_BUCKET_NAME}
s6-env IMMUTABLE_BUCKET_NAME=${IMMUTABLE_BUCKET_NAME}
./.venv/bin/start
PURR
  chmod +x "/etc/services.d/${SLUGNAME}-${service_name}/run"
  rc-update add "${SLUGNAME}-${service_name}" default

  # The service should only start if no service secrets config file has been
  # defined or if there is one; it should exist.
  # An error isn't thrown here because the service can start later when the
  # secrets config file has been decrypted at a later time.
  if [ -z "${service_secrets_config_file}" ] || [ -e "${service_secrets_config_file}" ]; then
    rc-service "${SLUGNAME}-${service_name}" start
  else
    echo "INFO $0: Skipping call to 'rc-service ${SLUGNAME}-${service_name} start' since no file found at: ${service_secrets_config_file}"
  fi

elif [ "${service_lang_template}" = "chill" ]; then

  # init chill
  # No support for managing tables that are outside of chill for this service.
  # That would be outside of the chillbox contract when using the chill service.
  # Any data that the chill service relies on should be part of the
  # chill-data.yaml that was included when the site artifact was created.
  su -p -s /bin/sh "$SLUGNAME" -c 'chill dropdb'
  su -p -s /bin/sh "$SLUGNAME" -c 'chill initdb'
  su -p -s /bin/sh "$SLUGNAME" -c 'chill load --yaml chill-data.yaml'

  if [ "${freeze}" = "true" ]; then
    echo "INFO $0: freeze - $SLUGNAME $service_name $service_handler"
    su -p -s /bin/sh "$SLUGNAME" -c 'chill freeze'
  else
    echo "INFO $0: dynamic - $SLUGNAME $service_name $service_handler"

    # Only for openrc
    mkdir -p /etc/init.d
    cat <<PURR > "/etc/init.d/${SLUGNAME}-${service_name}"
#!/sbin/openrc-run
name="${SLUGNAME}-${service_name}"
description="${SLUGNAME}-${service_name}"
user="$SLUGNAME"
group="dev"
supervisor=s6
s6_service_path=/etc/services.d/${SLUGNAME}-${service_name}
depend() {
  need s6-svscan net localmount
  after firewall
}
PURR
    chmod +x "/etc/init.d/${SLUGNAME}-${service_name}"

    mkdir -p "/etc/services.d/${SLUGNAME}-${service_name}"

    cat <<MEOW > "/etc/services.d/${SLUGNAME}-${service_name}/run"
#!/usr/bin/execlineb -P
s6-setuidgid "$SLUGNAME"
cd "$slugdir/${service_handler}"
MEOW
echo "$service_obj" | jq -r '.environment // [] | .[] | "s6-env " + .name + "=" + (.value | @sh)' \
      | "$bin_dir/envsubst-site-env.sh" -c "/etc/chillbox/sites/$SLUGNAME.site.json" \
      >> "/etc/services.d/${SLUGNAME}-${service_name}/run"
    cat <<PURR >> "/etc/services.d/${SLUGNAME}-${service_name}/run"
chill serve
PURR

    chmod +x "/etc/services.d/${SLUGNAME}-${service_name}/run"
    command -v rc-update > /dev/null \
      && rc-update add "${SLUGNAME}-${service_name}" default \
      || echo "INFO $0: Skipping call to 'rc-update add ${SLUGNAME}-${service_name} default'"
    command -v rc-service > /dev/null \
      && rc-service "${SLUGNAME}-${service_name}" start \
      || echo "INFO $0: Skipping call to 'rc-service ${SLUGNAME}-${service_name} start'"

  fi

else
  echo "ERROR $0: The service 'lang' template: '${service_lang_template}' is not supported!"
  exit 12
fi
