# syntax=docker/dockerfile:1.4.3

# UPKEEP due: "2023-05-21" label: "hashicorp/terraform base image" interval: "+4 months"
# docker pull hashicorp/terraform:1.3.7
# docker image ls --digests hashicorp/terraform
FROM hashicorp/terraform:1.3.7@sha256:48dbb8ae5b0d0fa63424e2eedffd92751ed8d0f2640db4e1dcaa7efc0771dc41

RUN <<DEV_USER
addgroup -g 44444 dev
adduser -u 44444 -G dev -s /bin/sh -D dev
DEV_USER

WORKDIR /usr/local/src/chillbox-terraform

RUN <<INSTALL
set -o errexit
apk update
apk add \
  jq \
  vim \
  mandoc man-pages docs \
  coreutils \
  unzip \
  gnupg \
  gnupg-dirmngr

# UPKEEP due: "2023-07-22" label: "s5cmd for s3 object storage" interval: "+6 months"
s5cmd_release_url="https://github.com/peak/s5cmd/releases/download/v2.0.0/s5cmd_2.0.0_Linux-64bit.tar.gz"
s5cmd_checksum="379d054f434bd1fbd44c0ae43a3f0f11a25e5c23fd9d7184ceeae1065e74e94ad6fa9e42dadd32d72860b919455e22cd2100b6315fd610d8bb4cfe81474621b4"
s5cmd_tar="$(basename "$s5cmd_release_url")"
s5cmd_tmp_dir="$(mktemp -d)"
wget -P "$s5cmd_tmp_dir" -O "$s5cmd_tmp_dir/$s5cmd_tar" "$s5cmd_release_url"
sha512sum "$s5cmd_tmp_dir/$s5cmd_tar"
echo "$s5cmd_checksum  $s5cmd_tmp_dir/$s5cmd_tar" | sha512sum --strict -c \
  || ( \
    echo "Cleaning up in case errexit is not set." \
    && mv --verbose "$s5cmd_tmp_dir/$s5cmd_tar" "$s5cmd_tmp_dir/$s5cmd_tar.INVALID" \
    && exit 1 \
    )
tar x -o -f "$s5cmd_tmp_dir/$s5cmd_tar" -C "/usr/local/bin" s5cmd
rm -rf "$s5cmd_tmp_dir"

INSTALL

RUN <<WGET_ALPINE_CUSTOM_IMAGE
set -o errexit
# UPKEEP due: "2023-04-21" label: "Alpine Linux custom image" interval: "+3 months"
# Create this file by following instructions at jkenlooper/alpine-droplet
alpine_custom_image="https://github.com/jkenlooper/alpine-droplet/releases/download/alpine-virt-image-2023-01-21-2310/alpine-virt-image-2023-01-21-2310.qcow2.bz2"
echo "INFO: Using alpine custom image $alpine_custom_image"
alpine_custom_image_checksum="6a70d976cc9d140c0c3f3a2f0bbe8307aa94786b2771f8cf68954e9810b6444b56b917cfc8b5aa7f6341934c2a17792c2d1093455690acc94f1e7bb2e86509b0"
echo "INFO: Using alpine custom image checksum ${alpine_custom_image_checksum}"

set -o errexit
wget "$alpine_custom_image"
alpine_custom_image_file="$(basename "${alpine_custom_image}")"
sha512sum "${alpine_custom_image_file}"
echo "${alpine_custom_image_checksum}  ${alpine_custom_image_file}" | sha512sum --strict -c \
  || ( \
    echo "Cleaning up in case errexit is not set." \
    && mv --verbose "${alpine_custom_image_file}" "${alpine_custom_image_file}.INVALID" \
    && exit 1 \
    )
cat <<HERE > alpine_custom_image.auto.tfvars
alpine_custom_image = "${alpine_custom_image_file}"
HERE
WGET_ALPINE_CUSTOM_IMAGE

ENV GPG_KEY_NAME="chillbox_local"
ENV TF_VAR_GPG_KEY_NAME="$GPG_KEY_NAME"
ENV DECRYPTED_TFSTATE="/run/tmp/secrets/doterra/terraform.tfstate.json"
ENV ENCRYPTED_TFSTATE="/var/lib/terraform-020-chillbox/terraform.tfstate.json.asc"
ENV PATH=/usr/local/src/chillbox-terraform/bin:${PATH}
ENV SKIP_UPLOAD="n"

#ENV endpoint_url="http://localhost:9000"

RUN <<SETUP
set -o errexit
chown -R dev:dev .

mkdir -p /run/tmp/secrets
chown -R dev:dev /run/tmp/secrets
chmod -R 0700 /run/tmp/secrets

mkdir -p /home/dev/.gnupg
chown -R dev:dev /home/dev/.gnupg
chmod -R 0700 /home/dev/.gnupg

mkdir -p /var/lib/doterra
chown -R dev:dev /var/lib/doterra
chmod -R 0700 /var/lib/doterra

mkdir -p /var/lib/terraform-020-chillbox
chown -R dev:dev /var/lib/terraform-020-chillbox
chmod -R 0700 /var/lib/terraform-020-chillbox
SETUP

ARG SITES_ARTIFACT
ENV SITES_ARTIFACT="$SITES_ARTIFACT"

COPY --chown=dev:dev 020-chillbox/chillbox.tf .
COPY --chown=dev:dev 020-chillbox/variables.tf .
COPY --chown=dev:dev 020-chillbox/main.tf .
COPY --chown=dev:dev 020-chillbox/outputs.tf .
COPY --chown=dev:dev 020-chillbox/.terraform.lock.hcl .

RUN <<TERRAFORM_INIT
set -o errexit
# Use 'terraform init -upgrade' since the tf files may have been updated with
# a newer provider version.
su dev -c "terraform init -upgrade"

# A Terraform workspace is required so that there is a directory created for the
# terraform state location instead of a file.  This way a docker volume can be
# made for this path since volumes can only be made from paths that are
# directories.
# Creates a directory at /usr/local/src/chillbox-terraform/terraform.tfstate.d
# to store the terraform.tfstate file.
su dev -c "terraform workspace new chillbox"

TERRAFORM_INIT

ARG CHILLBOX_ARTIFACT
ENV CHILLBOX_ARTIFACT="$CHILLBOX_ARTIFACT"
ARG SITES_MANIFEST
ENV SITES_MANIFEST="$SITES_MANIFEST"

COPY --chown=dev:dev 020-chillbox/init-chillbox.sh.tftpl .
COPY --chown=dev:dev 020-chillbox/host_inventory.ansible.cfg.tftpl .
COPY --chown=dev:dev 020-chillbox/ansible-etc-hosts-snippet.tftpl .
COPY --chown=dev:dev 020-chillbox/ansible_ssh_config.tftpl .
COPY --chown=dev:dev 020-chillbox/upload-artifacts.sh .
COPY --chown=dev:dev bin bin
COPY --chown=dev:dev 020-chillbox/bin/ bin/
