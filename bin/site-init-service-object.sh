#!/usr/bin/env sh

set -o errexit

service_obj="$1"
tmp_artifact="$2"

export service_obj=${service_obj}
test -n "${service_obj}" || (echo "ERROR $0: service_obj variable is empty" && exit 1)
echo "INFO $0: Using service_obj '${service_obj}'"

export tmp_artifact=${tmp_artifact}
test -n "${tmp_artifact}" || (echo "ERROR $0: tmp_artifact variable is empty" && exit 1)
test -f "${tmp_artifact}" || (echo "ERROR $0: The $tmp_artifact is not a file" && exit 1)
echo "INFO $0: Using tmp_artifact '${tmp_artifact}'"

export slugname=${slugname}
test -n "${slugname}" || (echo "ERROR $0: slugname variable is empty" && exit 1)
echo "INFO $0: Using slugname '${slugname}'"

export slugdir=${slugdir}
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

echo "INFO $0: Running site init for service object: ${service_obj}"

# Extract and set shell variables from JSON input
service_name=""
service_lang_template=""
service_handler=""
service_secrets_config=""
eval "$(echo "$service_obj" | jq -r --arg jq_slugname "$slugname" '@sh "
  service_name=\(.name)
  service_lang_template=\(.lang)
  service_handler=\(.handler)
  service_secrets_config=\( if .secrets_config then "/var/lib/chillbox-shared-secrets/\( $jq_slugname )/\( .secrets_config )" else "" end )
  "')"
# Extract just the new service handler directory from the tmp_artifact
cd "$(dirname "$slugdir")"
tar x -z -f "$tmp_artifact" "$slugname/${service_handler}"
chown -R "$slugname":"$slugname" "$slugdir"
# Save the service object for later use when updating or removing the service.
echo "$service_obj" | jq -c '.' > "$slugdir/$service_handler.service_handler.json"

# The 'freeze' variable is set from the environment object if at all. Default to
# empty string.
freeze=""
eval "$(echo "$service_obj" | jq -r '.environment // [] | .[] | "export " + .name + "=\"" + .value + "\""' \
  | envsubst "$(xargs < /etc/chillbox/env_names)")"

cd "$slugdir/${service_handler}"
if [ "${service_lang_template}" = "flask" ]; then

  mkdir -p "/var/lib/${slugname}/${service_handler}"
  chown -R "$slugname":"$slugname" "/var/lib/${slugname}"
  mkdir -p "/var/lib/chillbox-shared-secrets/${slugname}"
  chown -R "$slugname":"$slugname" "/var/lib/chillbox-shared-secrets/${slugname}"
  chmod -R 700 "/var/lib/chillbox-shared-secrets/${slugname}"

  python -m venv .venv
  ./.venv/bin/pip install --disable-pip-version-check --compile -r requirements.txt .

  HOST=localhost \
  FLASK_ENV="development" \
  FLASK_INSTANCE_PATH="/var/lib/${slugname}/${service_handler}" \
  S3_ENDPOINT_URL="$S3_ARTIFACT_ENDPOINT_URL" \
  SECRETS_CONFIG="${service_secrets_config}" \
    ./.venv/bin/flask init-db

  chown -R "$slugname":"$slugname" "/var/lib/${slugname}/"

  # Only for openrc
  mkdir -p /etc/init.d
  cat <<PURR > "/etc/init.d/${slugname}-${service_name}"
#!/sbin/openrc-run
name="${slugname}-${service_name}"
description="${slugname}-${service_name}"
user="$slugname"
group="dev"
supervisor=s6
s6_service_path=/etc/services.d/${slugname}-${service_name}
depend() {
  need s6-svscan net localmount
  after firewall
}
PURR
  chmod +x "/etc/init.d/${slugname}-${service_name}"


  mkdir -p "/etc/services.d/${slugname}-${service_name}"
  cat <<PURR > "/etc/services.d/${slugname}-${service_name}/run"
#!/usr/bin/execlineb -P
s6-setuidgid $slugname
cd $slugdir/${service_handler}
PURR
  echo "$service_obj" | jq -r '.environment // [] | .[] | "s6-env " + .name + "=\"" + .value + "\""' \
    | envsubst "$(xargs < /etc/chillbox/env_names)" \
    >> "/etc/services.d/${slugname}-${service_name}/run"
  cat <<PURR >> "/etc/services.d/${slugname}-${service_name}/run"
s6-env HOST=localhost \
s6-env FLASK_ENV=development
s6-env FLASK_INSTANCE_PATH="/var/lib/${slugname}/${service_handler}"
s6-env SECRETS_CONFIG=${service_secrets_config}
s6-env S3_ENDPOINT_URL=${S3_ENDPOINT_URL}
s6-env ARTIFACT_BUCKET_NAME=${ARTIFACT_BUCKET_NAME}
s6-env IMMUTABLE_BUCKET_NAME=${IMMUTABLE_BUCKET_NAME}
./.venv/bin/start
PURR
  chmod +x "/etc/services.d/${slugname}-${service_name}/run"
  rc-update add "${slugname}-${service_name}" default

  # The service should only start if no service secrets config file has been
  # defined or if there is one; it should exist.
  # An error isn't thrown here because the service can start later when the
  # secrets config file has been decrypted at a later time.
  if [ -z "${service_secrets_config}" ] || [ -e "${service_secrets_config}" ]; then
    rc-service "${slugname}-${service_name}" start
  else
    echo "INFO $0: Skipping call to 'rc-service ${slugname}-${service_name} start' since no file found at: ${service_secrets_config}"
  fi

elif [ "${service_lang_template}" = "chill" ]; then

  # init chill
  su -p -s /bin/sh "$slugname" -c 'chill initdb'
  su -p -s /bin/sh "$slugname" -c 'chill load --yaml chill-data.yaml'

  if [ "${freeze}" = "true" ]; then
    echo 'freeze';
    su -p -s /bin/sh "$slugname" -c 'chill freeze'
  else
    echo 'dynamic';

    # Only for openrc
    mkdir -p /etc/init.d
    cat <<PURR > "/etc/init.d/${slugname}-${service_name}"
#!/sbin/openrc-run
name="${slugname}-${service_name}"
description="${slugname}-${service_name}"
user="$slugname"
group="dev"
supervisor=s6
s6_service_path=/etc/services.d/${slugname}-${service_name}
depend() {
  need s6-svscan net localmount
  after firewall
}
PURR
    chmod +x "/etc/init.d/${slugname}-${service_name}"

    mkdir -p "/etc/services.d/${slugname}-${service_name}"

    cat <<MEOW > "/etc/services.d/${slugname}-${service_name}/run"
#!/usr/bin/execlineb -P
s6-setuidgid "$slugname"
cd "$slugdir/${service_handler}"
MEOW
    echo "$service_obj" | jq -r '.environment // [] | .[] | "s6-env " + .name + "=\"" + .value + "\""' \
      | envsubst "$(xargs < /etc/chillbox/env_names)" \
      >> "/etc/services.d/${slugname}-${service_name}/run"
    cat <<PURR >> "/etc/services.d/${slugname}-${service_name}/run"
chill serve
PURR

    chmod +x "/etc/services.d/${slugname}-${service_name}/run"
    command -v rc-update > /dev/null \
      && rc-update add "${slugname}-${service_name}" default \
      || echo "Skipping call to 'rc-update add ${slugname}-${service_name} default'"
    command -v rc-service > /dev/null \
      && rc-service "${slugname}-${service_name}" start \
      || echo "Skipping call to 'rc-service ${slugname}-${service_name} start'"

  fi

else
  echo "ERROR: The service 'lang' template: '${service_lang_template}' is not supported!"
  exit 12
fi
