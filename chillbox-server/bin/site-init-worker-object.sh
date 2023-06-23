#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"
bin_dir="$(dirname "$0")"
worker_obj="$1"
tmp_artifact="$2"
slugdir="$3"

chillbox_owner="$(cat /var/lib/chillbox/owner)"

test -n "${worker_obj}" || (echo "ERROR $script_name: worker_obj variable is empty" && exit 1)
echo "INFO $script_name: Using worker_obj '${worker_obj}'"

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

echo "INFO $script_name: Running site init for worker object: ${worker_obj}"

# TODO mount tmpfs at /run/tmp/chillbox_secrets

# Extract and set shell variables from JSON input
worker_name=""
worker_lang_template=""
worker_secrets_config=""
worker_niceness=""
worker_count=""
worker_run_cmd=""
eval "$(echo "$worker_obj" | jq -r --arg jq_slugname "$SLUGNAME" '@sh "
  worker_name=\(.name)
  worker_lang_template=\(.lang)
  worker_secrets_config=\( .secrets_config // "" )
  worker_niceness=\( .niceness // 0 )
  worker_count=\( .count // 0 )
  worker_run_cmd=\(."run-cmd")
  "')"

worker_secrets_config_file=""

if [ -n "$worker_secrets_config" ]; then
  worker_secrets_config_file="/run/tmp/chillbox_secrets/$SLUGNAME/$worker_name/$worker_secrets_config"
  worker_secrets_config_dir="$(dirname "$worker_secrets_config_file")"
  mkdir -p "$worker_secrets_config_dir"
  chown -R "$SLUGNAME":"$chillbox_owner" "$worker_secrets_config_dir"
  chmod -R 770 "$worker_secrets_config_dir"

  "$bin_dir/download-and-decrypt-secrets-config.sh" "$SLUGNAME/$worker_name/$worker_secrets_config"
fi
# Need to check if this secrets config file was successfully downloaded since it
# might not exist yet. Secrets are added to the s3 bucket in a different process.
if [ -n "$worker_secrets_config_file" ] && [ -e "$worker_secrets_config_file" ] && [ ! -s "$worker_secrets_config_file" ]; then
  # Failed to decrypt file and it is now an empty file so remove it.
  echo "WARNING $script_name: Failed to decrypt worker secrets config file."
  rm -f "$worker_secrets_config_file"
fi
if [ -n "$worker_secrets_config_file" ] && [ ! -e "$worker_secrets_config_file" ]; then
  echo "WARNING $script_name: No worker secrets config file was able to be downloaded and decrypted."
fi

# Extract just the new worker directory from the tmp_artifact
cd "$(dirname "$slugdir")"
tar x -z -f "$tmp_artifact" "$SLUGNAME/$worker_name"
chown -R "$SLUGNAME":"$SLUGNAME" "$slugdir"
# Save the worker object for later use when updating or removing the worker.
echo "$worker_obj" | jq -c '.' > "$slugdir/$worker_name.worker.json"

eval "$(jq -r '.env // [] | .[] | "export " + .name + "=" + (.value | @sh)' "/etc/chillbox/sites/$SLUGNAME.site.json" \
  | "$bin_dir/envsubst-site-env.sh" -c "/etc/chillbox/sites/$SLUGNAME.site.json")"

# The 'freeze' variable is set from the environment object if at all. Default to
# empty string.
freeze=""
eval "$(echo "$worker_obj" | jq -r '.environment // [] | .[] | "export " + .name + "=" + (.value | @sh)' \
  | "$bin_dir/envsubst-site-env.sh" -c "/etc/chillbox/sites/$SLUGNAME.site.json")"

cd "$slugdir/${worker_name}"
if [ "${worker_lang_template}" = "python-worker" ]; then

  mkdir -p "/var/lib/${SLUGNAME}/${worker_name}"
  chown -R "$SLUGNAME":"$SLUGNAME" "/var/lib/${SLUGNAME}"

  su "$SLUGNAME" -c "python -m venv $slugdir/$worker_name.venv"
  su "$SLUGNAME" -c "$slugdir/$worker_name/.venv/bin/pip install \
    --disable-pip-version-check \
    --compile \
    --no-build-isolation \
    --no-index \
    --find-links /var/lib/chillbox/python \
    -r /etc/chillbox/pip-requirements.txt"
  # The requirements.txt file should include find-links that are relative to the
  # worker_name directory. Ideally, this is where the deps/ directory is
  # used.
  su "$SLUGNAME" -c "$slugdir/$worker_name/.venv/bin/pip install \
    --disable-pip-version-check \
    --compile \
    --no-build-isolation \
    --no-cache-dir \
    --no-index \
    -r $slugdir/$worker_name/requirements.txt"
  su "$SLUGNAME" -c "$slugdir/$worker_name/.venv/bin/pip install \
    --disable-pip-version-check \
    --compile \
    --no-index \
    --no-cache-dir \
    --no-build-isolation \
    $slugdir/$worker_name"

  chown -R "$SLUGNAME":"$SLUGNAME" "/var/lib/${SLUGNAME}/"

  # Only for openrc
  mkdir -p /etc/init.d
  cat <<PURR > "/etc/init.d/${SLUGNAME}-${worker_name}"
#!/sbin/openrc-run
supervisor=s6
name="${SLUGNAME}-${worker_name}"
procname="${SLUGNAME}-${worker_name}"
description="${SLUGNAME}-${worker_name}"
s6_service_path=/etc/services.d/${SLUGNAME}-${worker_name}
depend() {
  need s6-svscan
}
PURR
  chmod +x "/etc/init.d/${SLUGNAME}-${worker_name}"

  # Create a service directory with a run script and a logging script.
  # https://skarnet.org/software/s6/servicedir.html
  # Use simple custom start-workers.sh script as process manager to start
  # multiple workers with the same run command.
  mkdir -p "/etc/services.d/${SLUGNAME}-${worker_name}"
  {
  cat <<PURR
#!/usr/bin/execlineb -P
s6-setuidgid $SLUGNAME
cd $slugdir/${worker_name}
PURR
jq -r '.env // [] | .[] | "s6-env " + .name + "=" + .value' "/etc/chillbox/sites/$SLUGNAME.site.json" \
  | "$bin_dir/envsubst-site-env.sh" -c "/etc/chillbox/sites/$SLUGNAME.site.json"
echo "$worker_obj" | jq -r '.environment // [] | .[] | "s6-env " + .name + "=" + .value' \
    | "$bin_dir/envsubst-site-env.sh" -c "/etc/chillbox/sites/$SLUGNAME.site.json"
  cat <<PURR
s6-env HOST=localhost
s6-env SECRETS_CONFIG=${worker_secrets_config_file}
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
nice -n $worker_niceness

/etc/chillbox/bin/start-workers.sh $worker_count $worker_run_cmd
PURR
  } > "/etc/services.d/${SLUGNAME}-${worker_name}/run"
  chmod +x "/etc/services.d/${SLUGNAME}-${worker_name}/run"

  # Add logging
  mkdir -p "/etc/services.d/${SLUGNAME}-${worker_name}/log"
  cat <<PURR > "/etc/services.d/${SLUGNAME}-${worker_name}/log/run"
#!/usr/bin/execlineb -P
s6-setuidgid $SLUGNAME
s6-log n3 s1000000 T /var/log/${SLUGNAME}-${worker_name}
PURR
  chmod +x "/etc/services.d/${SLUGNAME}-${worker_name}/log/run"

  # Enable protection against constantly restarting a failing worker.
  cat <<PURR > "/etc/services.d/${SLUGNAME}-${worker_name}/finish"
#!/usr/bin/execlineb -P
s6-setuidgid $SLUGNAME
s6-permafailon 60 5 1-255,SIGSEGV,SIGBUS
PURR
  chmod +x "/etc/services.d/${SLUGNAME}-${worker_name}/finish"

  rc-update add "${SLUGNAME}-${worker_name}" default

  # The worker should only start if no worker secrets config file has been
  # defined or if there is one; it should exist.
  # An error isn't thrown here because the worker can start later when the
  # secrets config file has been decrypted at a later time.
  if [ -z "${worker_secrets_config_file}" ] || [ -e "${worker_secrets_config_file}" ]; then
    rc-service "${SLUGNAME}-${worker_name}" start
  else
    echo "INFO $script_name: Skipping call to 'rc-service ${SLUGNAME}-${worker_name} start' since no file found at: ${worker_secrets_config_file}"
  fi

else
  echo "ERROR $script_name: The worker 'lang' template: '${worker_lang_template}' is not supported!"
  exit 12
fi

