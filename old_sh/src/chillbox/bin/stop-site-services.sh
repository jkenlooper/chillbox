#!/usr/bin/env sh

set -o errexit

script_name="$(basename "$0")"

SLUGNAME="${SLUGNAME:-$1}"
slugdir="${slugdir:-$2}"

export SLUGNAME
test -n "${SLUGNAME}" || (echo "ERROR $script_name: SLUGNAME variable is empty" && exit 1)
echo "INFO $script_name: Using slugname '${SLUGNAME}'"

test -n "${slugdir}" || (echo "ERROR $script_name: slugdir variable is empty" && exit 1)
test -d "${slugdir}" || (echo "ERROR $script_name: slugdir should be a directory" && exit 1)
test "$(dirname "${slugdir}")" != "${slugdir}" || (echo "ERROR $script_name: slugdir parent should be a directory" && exit 1)
test "${slugdir}" != "${slugdir#/}" || (echo "ERROR $script_name: slugdir should be an absolute path and start with '/'" && exit 1)
echo "INFO $script_name: Using slugdir '${slugdir}'"

# Set the working directory so the tar command creates the desired structure.
cd "$(dirname "${slugdir}")"

echo "INFO $script_name: Stopping site services and workers for: ${SLUGNAME}"

# Stop all workers in the $SLUGNAME directory and make backups
find "$SLUGNAME" -depth -mindepth 1 -maxdepth 1 -type f -name '*.worker.json' \
  | while read -r existing_worker; do
    echo "INFO $script_name: Stopping existing worker: $existing_worker"
    test -f "${existing_worker}" || (echo "ERROR $script_name: Failed to read file '${existing_worker}'" && exit 1)
    worker_name=""
    worker_lang_template=""
    worker_secrets_config=""
    eval "$(jq -r '@sh "
    worker_name=\(.name)
    worker_lang_template=\(.lang)
    worker_secrets_config=\(.secrets_config)
    "' "$existing_worker")"
    echo "$worker_lang_template"
    rc-service "${SLUGNAME}-${worker_name}" stop || printf "Ignoring"
    rc-update delete "${SLUGNAME}-${worker_name}" default || printf "Ignoring"
    rm -f "/etc/init.d/${SLUGNAME}-${worker_name}" || printf "Ignoring"
    rm -rf "/etc/services.d/${SLUGNAME}-${worker_name}" || printf "Ignoring"

    rm -rf "$slugdir/${worker_name}.bak.tar.gz"
    rm -rf "$slugdir/${worker_name}.worker.json.bak"
    mv "$slugdir/${worker_name}.worker.json" "$slugdir/${worker_name}.worker.json.bak"
    test -e "$slugdir/${worker_name}" \
      && tar c -f "$slugdir/${worker_name}.bak.tar.gz" "$SLUGNAME/${worker_name}" \
      || echo "INFO $script_name: No existing $slugdir/${worker_name} directory to backup"

    # Stopping the worker will require removing any secrets config file as
    # well. A new one should be downloaded from s3 and decrypted to start the
    # worker back up.
    if [ -e "/run/tmp/chillbox_secrets/$SLUGNAME/$worker_name/$worker_secrets_config" ]; then
      echo "INFO $script_name: Shredding /run/tmp/chillbox_secrets/$SLUGNAME/$worker_name/$worker_secrets_config file"
      shred -fu "/run/tmp/chillbox_secrets/$SLUGNAME/$worker_name/$worker_secrets_config" \
        || rm -f "/run/tmp/chillbox_secrets/$SLUGNAME/$worker_name/$worker_secrets_config"
    fi
done

# Stop all services in the $SLUGNAME directory and make backups
find "$SLUGNAME" -depth -mindepth 1 -maxdepth 1 -type f -name '*.service.json' \
  | while read -r existing_service; do
    echo "INFO $script_name: Stopping existing service: $existing_service"
    test -f "${existing_service}" || (echo "ERROR $script_name: Failed to read file '${existing_service}'" && exit 1)
    service_name=""
    service_lang_template=""
    service_secrets_config=""
    eval "$(jq -r '@sh "
    service_name=\(.name)
    service_lang_template=\(.lang)
    service_secrets_config=\(.secrets_config)
    "' "$existing_service")"
    echo "$service_lang_template"
    rc-service "${SLUGNAME}-${service_name}" stop || printf "Ignoring"
    # TODO Stopping the service doesn't work correctly. Need to configure the s6
    # run script or change the configuration. Or maybe don't use s6 for now?
    rc-update delete "${SLUGNAME}-${service_name}" default || printf "Ignoring"
    rm -f "/etc/init.d/${SLUGNAME}-${service_name}" || printf "Ignoring"
    rm -rf "/etc/services.d/${SLUGNAME}-${service_name}" || printf "Ignoring"

    rm -rf "$slugdir/${service_name}.bak.tar.gz"
    rm -rf "$slugdir/${service_name}.service.json.bak"
    mv "$slugdir/${service_name}.service.json" "$slugdir/${service_name}.service.json.bak"
    test -e "$slugdir/${service_name}" \
      && tar c -f "$slugdir/${service_name}.bak.tar.gz" "$SLUGNAME/${service_name}" \
      || echo "INFO $script_name: No existing $slugdir/${service_name} directory to backup"

    # Stopping the service will require removing any secrets config file as
    # well. A new one should be downloaded from s3 and decrypted to start the
    # service back up.
    if [ -e "/run/tmp/chillbox_secrets/$SLUGNAME/$service_name/$service_secrets_config" ]; then
      echo "INFO $script_name: Shredding /run/tmp/chillbox_secrets/$SLUGNAME/$service_name/$service_secrets_config file"
      shred -fu "/run/tmp/chillbox_secrets/$SLUGNAME/$service_name/$service_secrets_config" \
        || rm -f "/run/tmp/chillbox_secrets/$SLUGNAME/$service_name/$service_secrets_config"
    fi
done

has_redis="$(jq -r -e 'has("redis")' "/etc/chillbox/sites/$SLUGNAME.site.json" || printf "false")"
if [ "$has_redis" = "true" ]; then
  rc-service "${SLUGNAME}-redis" stop || printf "Ignoring"
  rc-update delete "${SLUGNAME}-redis" default || printf "Ignoring"
fi

# TODO Set nginx server for this $SLUGNAME to maintenance
