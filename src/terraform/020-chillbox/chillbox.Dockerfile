# syntax=docker/dockerfile:1.4.3

# UPKEEP due: "2022-12-14" label: "hashicorp/terraform base image" interval: "+4 months"
# docker pull hashicorp/terraform:1.2.7
# docker image ls --digests hashicorp/terraform
FROM hashicorp/terraform:1.2.7@sha256:8e4d010fc675dbae1eb6eee07b8fb4895b04d144152d2ef5ad39724857857ccb

WORKDIR /usr/local/src/chillbox-terraform

RUN <<INSTALL
set -o errexit
apk update
apk add \
  jq \
  vim \
  mandoc man-pages \
  coreutils \
  unzip \
  gnupg \
  gnupg-dirmngr

# UPKEEP due: "2023-01-01" label: "s5cmd for s3 object storage" interval: "+3 months"
s5cmd_release_url="https://github.com/peak/s5cmd/releases/download/v2.0.0/s5cmd_2.0.0_Linux-64bit.tar.gz"
s5cmd_tar="$(basename "$s5cmd_release_url")"
s5cmd_tmp_dir="$(mktemp -d)"
wget -P "$s5cmd_tmp_dir" -O "$s5cmd_tmp_dir/$s5cmd_tar" "$s5cmd_release_url"
tar x -o -f "$s5cmd_tmp_dir/$s5cmd_tar" -C "/usr/local/bin" s5cmd
rm -rf "$s5cmd_tmp_dir"

INSTALL

RUN <<WGET_ALPINE_CUSTOM_IMAGE
set -o errexit
# UPKEEP due: "2023-01-23" label: "Alpine Linux custom image" interval: "+3 months"
# Create this file by following instructions at jkenlooper/alpine-droplet
alpine_custom_image="https://github.com/jkenlooper/alpine-droplet/releases/download/alpine-virt-image-2022-10-23-1351/alpine-virt-image-2022-10-23-1351.qcow2.bz2"
echo "INFO: Using alpine custom image $alpine_custom_image"
alpine_custom_image_checksum="f229495ff2f6344a0d0e73b7e94492748b8aed9a964a7287a2e2e111193211c0713130f45008b45dca1db0c9339b59f529e51667fe4bb50c8b78e28f75e783a3"
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
ENV DECRYPTED_TFSTATE="/run/tmp/secrets/doterra/terraform.tfstate.json"
ENV ENCRYPTED_TFSTATE="/var/lib/terraform-020-chillbox/terraform.tfstate.json.asc"
ENV PATH=/usr/local/src/chillbox-terraform/bin:${PATH}
ENV SKIP_UPLOAD="n"

#ENV endpoint_url="http://localhost:9000"

RUN <<SETUP
set -o errexit
addgroup dev
adduser -G dev -D dev
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
COPY --chown=dev:dev 020-chillbox/init-chillbox.sh.tftpl .
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

COPY --chown=dev:dev 020-chillbox/upload-artifacts.sh .
COPY --chown=dev:dev bin bin
COPY --chown=dev:dev 020-chillbox/bin/ bin/
