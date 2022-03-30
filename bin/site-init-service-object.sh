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
test -d "$(dirname ${slugdir})" || (echo "ERROR $0: parent directory of slugdir should be a directory" && exit 1)
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

echo "INFO $0: Running site init for service object:\n ${service_obj}"

# Extract and set shell variables from JSON input
eval "$(echo $service_obj | jq -r '@sh "
  service_name=\(.name)
  service_lang_template=\(.lang)
  service_handler=\(.handler)
  service_secrets_config=\(.secrets_config)
  "')"
# Extract just the new service handler directory from the tmp_artifact
cd $(dirname $slugdir)
tar x -z -f $tmp_artifact $slugname/${service_handler}
chown -R $slugname:$slugname $slugdir
# Save the service object for later use when updating or removing the service.
echo $service_obj | jq -c '.' > $slugdir/$service_handler.service_handler.json

eval $(echo $service_obj | jq -r '.environment // [] | .[] | "export " + .name + "=\"" + .value + "\""' \
  | envsubst "$(cat /etc/chillbox/env_names | xargs)")

cd $slugdir/${service_handler}
if [ "${service_lang_template}" = "flask" ]; then

  mkdir -p "/var/lib/${slugname}/${service_handler}"
  chown -R $slugname:$slugname "/var/lib/${slugname}"

  python -m venv .venv
  ./.venv/bin/pip install --disable-pip-version-check --compile -r requirements.txt .

  # TODO: init_db only when first installing?
  HOST=localhost \
  FLASK_ENV="development" \
  FLASK_INSTANCE_PATH="/var/lib/${slugname}/${service_handler}" \
  S3_ENDPOINT_URL=$S3_ARTIFACT_ENDPOINT_URL \
  SECRETS_CONFIG=/var/lib/${slugname}/secrets/${service_secrets_config} \
    ./.venv/bin/flask init-db

  chown -R $slugname:$slugname "/var/lib/${slugname}/"

  mkdir -p /etc/services.d/${slugname}-${service_name}
  cat <<PURR > /etc/services.d/${slugname}-${service_name}/run
#!/usr/bin/execlineb -P
s6-setuidgid $slugname
cd $slugdir/${service_handler}
PURR
  echo $service_obj | jq -r '.environment // [] | .[] | "s6-env " + .name + "=\"" + .value + "\""' \
    | envsubst "$(cat /etc/chillbox/env_names | xargs)" \
    >> /etc/services.d/${slugname}-${service_name}/run
  cat <<PURR >> /etc/services.d/${slugname}-${service_name}/run
s6-env HOST=localhost \
s6-env FLASK_ENV=development
s6-env FLASK_INSTANCE_PATH="/var/lib/${slugname}/${service_handler}"
s6-env SECRETS_CONFIG=/var/lib/${slugname}/secrets/${service_secrets_config}
s6-env S3_ENDPOINT_URL=${S3_ENDPOINT_URL}
s6-env ARTIFACT_BUCKET_NAME=${ARTIFACT_BUCKET_NAME}
s6-env IMMUTABLE_BUCKET_NAME=${IMMUTABLE_BUCKET_NAME}
./.venv/bin/start
PURR
elif [ "${service_lang_template}" = "chill" ]; then

  # init chill
  su -p -s /bin/sh $slugname -c 'chill initdb'
  su -p -s /bin/sh $slugname -c 'chill load --yaml chill-data.yaml'

  if [ "${freeze}" = "true" ]; then
    echo 'freeze';
    su -p -s /bin/sh $slugname -c 'chill freeze'
  else
    echo 'dynamic';

    mkdir -p /etc/services.d/${slugname}-${service_name}

    cat <<MEOW > /etc/services.d/${slugname}-${service_name}/run
#!/usr/bin/execlineb -P
s6-setuidgid $slugname
cd $slugdir/${service_handler}
MEOW
    echo $service_obj | jq -r '.environment // [] | .[] | "s6-env " + .name + "=\"" + .value + "\""' \
      | envsubst "$(cat /etc/chillbox/env_names | xargs)" \
      >> /etc/services.d/${slugname}-${service_name}/run
    cat <<PURR >> /etc/services.d/${slugname}-${service_name}/run
chill serve
PURR
  fi

else
  echo "ERROR: The service 'lang' template: '${service_lang_template}' is not supported!"
  exit 12
fi
