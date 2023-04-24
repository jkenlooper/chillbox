#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"
bin_dir="$(dirname "$0")"
service_obj="$1"
tmp_artifact="$2"
slugdir="$3"

test -n "${service_obj}" || (echo "ERROR $script_name: service_obj variable is empty" && exit 1)
echo "INFO $script_name: Using service_obj '${service_obj}'"

test -n "${tmp_artifact}" || (echo "ERROR $script_name: tmp_artifact variable is empty" && exit 1)
test -f "${tmp_artifact}" || (echo "ERROR $script_name: The $tmp_artifact is not a file" && exit 1)
echo "INFO $script_name: Using tmp_artifact '${tmp_artifact}'"

test -n "${SLUGNAME}" || (echo "ERROR $script_name: SLUGNAME variable is empty" && exit 1)
echo "INFO $script_name: Using slugname '${SLUGNAME}'"

test -n "${slugdir}" || (echo "ERROR $script_name: slugdir variable is empty" && exit 1)
test -d "${slugdir}" || (echo "ERROR $script_name: slugdir should be a directory" && exit 1)
test -d "$(dirname "${slugdir}")" || (echo "ERROR $script_name: parent directory of slugdir should be a directory" && exit 1)
echo "INFO $script_name: Using slugdir '${slugdir}'"

export S3_ENDPOINT_URL=${S3_ENDPOINT_URL}
test -n "${S3_ENDPOINT_URL}" || (echo "ERROR $script_name: S3_ENDPOINT_URL variable is empty" && exit 1)
echo "INFO $script_name: Using S3_ENDPOINT_URL '${S3_ENDPOINT_URL}'"

test -n "$AWS_PROFILE" || (echo "ERROR $script_name: No AWS_PROFILE set." && exit 1)

export ARTIFACT_BUCKET_NAME=${ARTIFACT_BUCKET_NAME}
test -n "${ARTIFACT_BUCKET_NAME}" || (echo "ERROR $script_name: ARTIFACT_BUCKET_NAME variable is empty" && exit 1)
echo "INFO $script_name: Using ARTIFACT_BUCKET_NAME '${ARTIFACT_BUCKET_NAME}'"

export IMMUTABLE_BUCKET_NAME=${IMMUTABLE_BUCKET_NAME}
test -n "${IMMUTABLE_BUCKET_NAME}" || (echo "ERROR $script_name: IMMUTABLE_BUCKET_NAME variable is empty" && exit 1)
echo "INFO $script_name: Using IMMUTABLE_BUCKET_NAME '${IMMUTABLE_BUCKET_NAME}'"

echo "INFO $script_name: Running site init for service object: ${service_obj}"

# TODO mount tmpfs at /run/tmp/chillbox_secrets

# Extract and set shell variables from JSON input
service_name=""
service_lang_template=""
service_secrets_config=""
service_niceness=""
service_workers=""
service_worker_class=""
service_max_requests=""
service_max_requests_jitter=""
service_log_level=""
eval "$(echo "$service_obj" | jq -r --arg jq_slugname "$SLUGNAME" '@sh "
  service_name=\(.name)
  service_lang_template=\(.lang)
  service_secrets_config=\( .secrets_config // "" )
  service_niceness=\( .niceness // 0 )
  service_worker_class=\( .worker_class // "sync" )
  service_workers=\( .workers // 1 )
  service_max_requests=\( .max_requests // 0 )
  service_max_requests_jitter=\( .max_requests_jitter // 0 )
  service_log_level=\( .log_level // "info" )
  "')"

service_secrets_config_file=""

if [ -n "$service_secrets_config" ]; then
  service_secrets_config_file="/run/tmp/chillbox_secrets/$SLUGNAME/$service_name/$service_secrets_config"
  service_secrets_config_dir="$(dirname "$service_secrets_config_file")"
  mkdir -p "$service_secrets_config_dir"
  chown -R "$SLUGNAME":dev "$service_secrets_config_dir"
  chmod -R 770 "$service_secrets_config_dir"

  "$bin_dir/download-and-decrypt-secrets-config.sh" "$SLUGNAME/$service_name/$service_secrets_config"
fi
# Need to check if this secrets config file was successfully downloaded since it
# might not exist yet. Secrets are added to the s3 bucket in a different process.
if [ -n "$service_secrets_config_file" ] && [ -e "$service_secrets_config_file" ] && [ ! -s "$service_secrets_config_file" ]; then
  # Failed to decrypt file and it is now an empty file so remove it.
  echo "WARNING $script_name: Failed to decrypt service secrets config file."
  rm -f "$service_secrets_config_file"
fi
if [ -n "$service_secrets_config_file" ] && [ ! -e "$service_secrets_config_file" ]; then
  echo "WARNING $script_name: No service secrets config file was able to be downloaded and decrypted."
fi

# Extract just the new service directory from the tmp_artifact
cd "$(dirname "$slugdir")"
tar x -z -f "$tmp_artifact" "$SLUGNAME/$service_name"
chown -R "$SLUGNAME":"$SLUGNAME" "$slugdir"
# Save the service object for later use when updating or removing the service.
echo "$service_obj" | jq -c '.' > "$slugdir/$service_name.service.json"

eval "$(jq -r '.env // [] | .[] | "export " + .name + "=" + (.value | @sh)' "/etc/chillbox/sites/$SLUGNAME.site.json" \
  | "$bin_dir/envsubst-site-env.sh" -c "/etc/chillbox/sites/$SLUGNAME.site.json")"

# The 'freeze' variable is set from the environment object if at all. Default to
# empty string.
freeze=""
eval "$(echo "$service_obj" | jq -r '.environment // [] | .[] | "export " + .name + "=" + (.value | @sh)' \
  | "$bin_dir/envsubst-site-env.sh" -c "/etc/chillbox/sites/$SLUGNAME.site.json")"

cd "$slugdir/${service_name}"
# This should support any WSGI or ASGI python applications.
# TODO change 'python' to 'gunicorn'
if [ "${service_lang_template}" = "python" ]; then

  mkdir -p "/var/lib/${SLUGNAME}/${service_name}"
  chown -R "$SLUGNAME":"$SLUGNAME" "/var/lib/${SLUGNAME}"

  su "$SLUGNAME" -c "python -m venv $slugdir/$service_name/.venv"
  # Support gunicorn with option to use gevent.
  # TODO Support uvicorn for ASGI python apps.
  su "$SLUGNAME" -c "$slugdir/$service_name/.venv/bin/pip install \
    --disable-pip-version-check \
    --compile \
    --no-build-isolation \
    --no-index \
    --find-links /var/lib/chillbox/python \
    'gunicorn[gevent,setproctitle]'"
  # The requirements.txt file should include find-links that are relative to the
  # service_name directory. Ideally, this is where the deps/ directory is
  # used.
  su "$SLUGNAME" -c "$slugdir/$service_name/.venv/bin/pip install \
    --disable-pip-version-check \
    --compile \
    --no-build-isolation \
    --no-index \
    -r $slugdir/$service_name/requirements.txt"
  su "$SLUGNAME" -c "$slugdir/$service_name/.venv/bin/pip install \
    --disable-pip-version-check \
    --compile \
    --no-build-isolation \
    --no-index \
    $slugdir/$service_name"

  chown -R "$SLUGNAME":"$SLUGNAME" "/var/lib/${SLUGNAME}/"

  # Only for openrc
  mkdir -p /etc/init.d
  cat <<PURR > "/etc/init.d/${SLUGNAME}-${service_name}"
#!/sbin/openrc-run
supervisor=s6
name="${SLUGNAME}-${service_name}"
procname="${SLUGNAME}-${service_name}"
description="${SLUGNAME}-${service_name}"
s6_service_path=/etc/services.d/${SLUGNAME}-${service_name}
depend() {
  need s6-svscan
}
PURR
  chmod +x "/etc/init.d/${SLUGNAME}-${service_name}"

  # The gunicorn command will use any gunicorn.conf.py file that is within the
  # directory of the service. It could potentially use a different configuration
  # file if the GUNICORN_CMD_ARGS are set in the site.json environment for the
  # service. The gunicorn.conf.py file is used to define the server hooks.  For
  # example, the on_starting() would be defined in gunicorn.conf.py to run
  # a init-db operation.
  # https://docs.gunicorn.org/en/stable/settings.html#server-hooks

  # Create a service directory with a run script and a logging script.
  # https://skarnet.org/software/s6/servicedir.html
  # Use gunicorn as process manager and uvicorn worker class.
  # http://www.uvicorn.org/#running-with-gunicorn
  # http://www.uvicorn.org/deployment/#deployment
  # This setup is for uvicorn with uvloop.
  mkdir -p "/etc/services.d/${SLUGNAME}-${service_name}"
  {
  cat <<PURR
#!/usr/bin/execlineb -P
s6-setuidgid $SLUGNAME
cd $slugdir/${service_name}
PURR
jq -r '.env // [] | .[] | "s6-env " + .name + "=" + .value' "/etc/chillbox/sites/$SLUGNAME.site.json" \
  | "$bin_dir/envsubst-site-env.sh" -c "/etc/chillbox/sites/$SLUGNAME.site.json"
echo "$service_obj" | jq -r '.environment // [] | .[] | "s6-env " + .name + "=" + .value' \
    | "$bin_dir/envsubst-site-env.sh" -c "/etc/chillbox/sites/$SLUGNAME.site.json"
  cat <<PURR
s6-env HOST=localhost
s6-env SECRETS_CONFIG=${service_secrets_config_file}
s6-env S3_ENDPOINT_URL=${S3_ENDPOINT_URL}
s6-env ARTIFACT_BUCKET_NAME=${ARTIFACT_BUCKET_NAME}
s6-env IMMUTABLE_BUCKET_NAME=${IMMUTABLE_BUCKET_NAME}
s6-env CHILLBOX_SERVER_NAME=${CHILLBOX_SERVER_NAME}
s6-env CHILLBOX_SERVER_PORT=${CHILLBOX_SERVER_PORT}
s6-env IMMUTABLE_BUCKET_DOMAIN_NAME=${IMMUTABLE_BUCKET_DOMAIN_NAME}
s6-env SERVER_PORT=${SERVER_PORT}
s6-env CHILLBOX_SUBNET=${CHILLBOX_SUBNET}
s6-env TECH_EMAIL=${TECH_EMAIL}
fdmove -c 2 1
nice -n $service_niceness
$slugdir/${service_name}/.venv/bin/gunicorn \
    --name ${SLUGNAME}_${service_name}_app \
    --chdir $slugdir/${service_name} \
    --workers $service_workers \
    --worker-class $service_worker_class \
    --max-requests $service_max_requests \
    --max-requests-jitter $service_max_requests_jitter \
    --log-level $service_log_level \
    --bind "127.0.0.1:$PORT" \
    --access-logfile - \
    "${SLUGNAME}_${service_name}.app:create_app()"
PURR
  } > "/etc/services.d/${SLUGNAME}-${service_name}/run"
  chmod +x "/etc/services.d/${SLUGNAME}-${service_name}/run"

  # Add logging
  mkdir -p "/etc/services.d/${SLUGNAME}-${service_name}/log"
  cat <<PURR > "/etc/services.d/${SLUGNAME}-${service_name}/log/run"
#!/usr/bin/execlineb -P
s6-setuidgid $SLUGNAME
s6-log n3 s1000000 T /var/log/${SLUGNAME}-${service_name}
PURR
  chmod +x "/etc/services.d/${SLUGNAME}-${service_name}/log/run"

  # Enable protection against constantly restarting a failing service.
  cat <<PURR > "/etc/services.d/${SLUGNAME}-${service_name}/finish"
#!/usr/bin/execlineb -P
s6-setuidgid $SLUGNAME
s6-permafailon 60 5 1-255,SIGSEGV,SIGBUS
PURR
  chmod +x "/etc/services.d/${SLUGNAME}-${service_name}/finish"

  rc-update add "${SLUGNAME}-${service_name}" default

  # The service should only start if no service secrets config file has been
  # defined or if there is one; it should exist.
  # An error isn't thrown here because the service can start later when the
  # secrets config file has been decrypted at a later time.
  if [ -z "${service_secrets_config_file}" ] || [ -e "${service_secrets_config_file}" ]; then
    rc-service "${SLUGNAME}-${service_name}" start
  else
    echo "INFO $script_name: Skipping call to 'rc-service ${SLUGNAME}-${service_name} start' since no file found at: ${service_secrets_config_file}"
  fi

elif [ "${service_lang_template}" = "chill" ]; then

  su "$SLUGNAME" -c "python -m venv $slugdir/$service_name/.venv"
  su "$SLUGNAME" -c "$slugdir/$service_name/.venv/bin/pip install \
    --disable-pip-version-check \
    --compile \
    --no-build-isolation \
    --no-index \
    --find-links /var/lib/chillbox/python \
    chill"

  # init chill
  # No support for managing tables that are outside of chill for this service.
  # That would be outside of the chillbox contract when using the chill service.
  # Any data that the chill service relies on should be part of the
  # chill-data.yaml that was included when the site artifact was created.
  su -p -s /bin/sh "$SLUGNAME" -c "$slugdir/${service_name}/.venv/bin/chill dropdb"
  su -p -s /bin/sh "$SLUGNAME" -c "$slugdir/${service_name}/.venv/bin/chill initdb"
  su -p -s /bin/sh "$SLUGNAME" -c 'find . -depth -maxdepth 1 -name '"'chill-*.yaml'"" -exec $slugdir/${service_name}/.venv/bin/chill load --yaml {} \;"

  if [ "${freeze}" = "true" ]; then
    echo "INFO $script_name: freeze - $SLUGNAME $service_name $service_name"
    su -p -s /bin/sh "$SLUGNAME" -c "$slugdir/${service_name}/.venv/bin/chill freeze"
  else
    echo "INFO $script_name: dynamic - $SLUGNAME $service_name $service_name"

    # Only for openrc
    mkdir -p /etc/init.d
    cat <<PURR > "/etc/init.d/${SLUGNAME}-${service_name}"
#!/sbin/openrc-run
supervisor=s6
name="${SLUGNAME}-${service_name}"
procname="${SLUGNAME}-${service_name}"
description="${SLUGNAME}-${service_name}"
s6_service_path=/etc/services.d/${SLUGNAME}-${service_name}
depend() {
  need s6-svscan
}
PURR
    chmod +x "/etc/init.d/${SLUGNAME}-${service_name}"

    mkdir -p "/etc/services.d/${SLUGNAME}-${service_name}"

    {
    cat <<MEOW
#!/usr/bin/execlineb -P
pipeline {
s6-setuidgid "$SLUGNAME"
cd "$slugdir/${service_name}"
MEOW
jq -r '.env // [] | .[] | "s6-env " + .name + "=" + .value' "/etc/chillbox/sites/$SLUGNAME.site.json" \
  | "$bin_dir/envsubst-site-env.sh" -c "/etc/chillbox/sites/$SLUGNAME.site.json"
echo "$service_obj" | jq -r '.environment // [] | .[] | "s6-env " + .name + "=" + .value' \
      | "$bin_dir/envsubst-site-env.sh" -c "/etc/chillbox/sites/$SLUGNAME.site.json"
    cat <<PURR
fdmove -c 2 1
$slugdir/${service_name}/.venv/bin/chill serve
} s6-log n3 s1000000 T /var/log/${SLUGNAME}-${service_name}
PURR
    } > "/etc/services.d/${SLUGNAME}-${service_name}/run"
    chmod +x "/etc/services.d/${SLUGNAME}-${service_name}/run"

    command -v rc-update > /dev/null \
      && rc-update add "${SLUGNAME}-${service_name}" default \
      || echo "INFO $script_name: Skipping call to 'rc-update add ${SLUGNAME}-${service_name} default'"
    command -v rc-service > /dev/null \
      && rc-service "${SLUGNAME}-${service_name}" start \
      || echo "INFO $script_name: Skipping call to 'rc-service ${SLUGNAME}-${service_name} start'"

  fi

else
  echo "ERROR $script_name: The service 'lang' template: '${service_lang_template}' is not supported!"
  exit 12
fi