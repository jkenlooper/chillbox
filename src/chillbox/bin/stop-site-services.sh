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

echo "INFO $script_name: Stopping site services for: ${SLUGNAME}"

# Stop all services in the $SLUGNAME directory and make backups
find "$SLUGNAME" -depth -mindepth 1 -maxdepth 1 -type f -name '*.service_handler.json' \
  | while read -r existing_service_handler; do
    echo "INFO $script_name: Stopping existing service handler: $existing_service_handler"
    test -f "${existing_service_handler}" || (echo "ERROR $script_name: Failed to read file '${existing_service_handler}'" && exit 1)
    service_name=""
    service_lang_template=""
    service_handler=""
    service_secrets_config=""
    eval "$(jq -r '@sh "
    service_name=\(.name)
    service_lang_template=\(.lang)
    service_handler=\(.handler)
    service_secrets_config=\(.secrets_config)
    "' "$existing_service_handler")"
    echo "$service_lang_template"
    rc-service "${SLUGNAME}-${service_name}" stop || printf "Ignoring"
    rc-update delete "${SLUGNAME}-${service_name}" default || printf "Ignoring"
    rm -f "/etc/init.d/${SLUGNAME}-${service_name}" || printf "Ignoring"
    rm -rf "/etc/services.d/${SLUGNAME}-${service_name}" || printf "Ignoring"

    rm -rf "$slugdir/${service_handler}.bak.tar.gz"
    rm -rf "$slugdir/${service_handler}.service_handler.json.bak"
    mv "$slugdir/${service_handler}.service_handler.json" "$slugdir/${service_handler}.service_handler.json.bak"
    test -e "$slugdir/${service_handler}" \
      && tar c -f "$slugdir/${service_handler}.bak.tar.gz" "$SLUGNAME/${service_handler}" \
      || echo "INFO $script_name: No existing $slugdir/${service_handler} directory to backup"

    # Stopping the service will require removing any secrets config file as
    # well. A new one should be downloaded from s3 and decrypted to start the
    # service back up.
    # TODO should be /run/tmp/chillbox/encrypted_secrets/
    if [ -e "/var/lib/${SLUGNAME}/secrets/${service_secrets_config}" ]; then
      echo "INFO $script_name: Shredding /var/lib/${SLUGNAME}/secrets/${service_secrets_config} file"
      shred -fu "/var/lib/${SLUGNAME}/secrets/${service_secrets_config}"
    fi
done

# TODO Set nginx server for this $SLUGNAME to maintenance
