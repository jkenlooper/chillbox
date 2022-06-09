# syntax=docker/dockerfile:1.3.0-labs

# UPKEEP due: "2022-08-12" label: "hashicorp/terraform base image" interval: "+4 months"
# docker pull hashicorp/terraform:1.2.0-alpha-20220328
# docker image ls --digests hashicorp/terraform
FROM hashicorp/terraform:1.2.0-alpha-20220328@sha256:94c01aed14a10ef34fad8d8c7913dd605813076ecc824284377d7f1375aa596c

WORKDIR /usr/local/src/chillbox-terraform

COPY bin/install-aws-cli.sh bin/
RUN <<INSTALL
apk update
/usr/local/src/chillbox-terraform/bin/install-aws-cli.sh
apk add \
  jq \
  vim \
  mandoc man-pages \
  coreutils \
  gnupg \
  gnupg-dirmngr

INSTALL

RUN <<WGET_ALPINE_CUSTOM_IMAGE
# UPKEEP due: "2022-07-12" label: "Alpine Linux custom image" interval: "+3 months"
# Create this file by following instructions at jkenlooper/alpine-droplet
alpine_custom_image="https://github.com/jkenlooper/alpine-droplet/releases/download/alpine-virt-image-2022-04-13-0434/alpine-virt-image-2022-04-13-0434.qcow2.bz2"
echo "INFO: Using alpine custom image $alpine_custom_image"
alpine_custom_image_checksum="f8aa090e27509cc9e9cb57f6ad16d7b3"
echo "INFO: Using alpine custom image checksum ${alpine_custom_image_checksum}"

set -o errexit
wget "$alpine_custom_image"
alpine_custom_image_file="$(basename "${alpine_custom_image}")"
md5sum "${alpine_custom_image_file}"
echo "${alpine_custom_image_checksum}  ${alpine_custom_image_file}" | md5sum -c
cat <<HERE > alpine_custom_image.auto.tfvars
alpine_custom_image = "${alpine_custom_image_file}"
HERE
WGET_ALPINE_CUSTOM_IMAGE

# Set WORKSPACE before SETUP to invalidate that layer.
ARG WORKSPACE=development
ENV WORKSPACE=${WORKSPACE}
ENV GPG_KEY_NAME="chillbox_doterra__${WORKSPACE}"
ENV DECRYPTED_TFSTATE="/run/tmp/secrets/doterra/$WORKSPACE-terraform.tfstate.json"
ENV ENCRYPTED_TFSTATE="/var/lib/terraform-020-chillbox/$WORKSPACE-terraform.tfstate.json.asc"
ENV PATH=/usr/local/src/chillbox-terraform/bin:${PATH}
ENV SKIP_UPLOAD="n"

#ENV endpoint_url="http://localhost:9000"

RUN <<SETUP
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

COPY --chown=dev:dev terraform-020-chillbox/extract-terraform-artifact-modules.sh .
COPY --chown=dev:dev dist ./dist
COPY --chown=dev:dev .build-artifacts-vars .
RUN <<ARTIFACT_MODULES
# Set the SITES_ARTIFACT CHILLBOX_ARTIFACT SITES_MANIFEST vars
. .build-artifacts-vars

mkdir -p artifact-modules
chown dev:dev artifact-modules
# NOT_IMPLEMENTED May revisit this feature in the future. The way that this is
# included with the terraform-020-chillbox deployment is not ideal since it will
# modify the .terraform.lock.hcl. A better solution would probably be to have
# a separate terraform deployment for each site that has defined an artifact
# module.
artifact_module_tf_file=artifact-modules.tf.not_implemented
touch "$artifact_module_tf_file"
chown dev:dev "$artifact_module_tf_file"
echo "$SITES_ARTIFACT"

su dev -p -c "jq --null-input --arg jq_sites_artifact '${SITES_ARTIFACT}' --arg jq_artifact_module_tf_file '${artifact_module_tf_file}' '{ sites_artifact: \$jq_sites_artifact, artifact_module_tf_file: \$jq_artifact_module_tf_file }' | ./extract-terraform-artifact-modules.sh"
cat extract-terraform-artifact-modules.sh.log
ARTIFACT_MODULES

COPY --chown=dev:dev terraform-020-chillbox/generate-site_domains_auto_tfvars.sh .
RUN <<SITE_DOMAINS
set -x
# Set the SITES_ARTIFACT CHILLBOX_ARTIFACT SITES_MANIFEST vars
. .build-artifacts-vars

su dev -p -c "jq --null-input --arg jq_sites_artifact '${SITES_ARTIFACT}' '{ sites_artifact: \$jq_sites_artifact }' | ./generate-site_domains_auto_tfvars.sh"
SITE_DOMAINS

COPY --chown=dev:dev terraform-020-chillbox/chillbox.tf .
COPY --chown=dev:dev terraform-020-chillbox/variables.tf .
COPY --chown=dev:dev terraform-020-chillbox/main.tf .
COPY --chown=dev:dev terraform-020-chillbox/outputs.tf .
COPY --chown=dev:dev terraform-020-chillbox/user_data_chillbox.sh.tftpl .
COPY --chown=dev:dev terraform-020-chillbox/.terraform.lock.hcl .

RUN <<TERRAFORM_INIT
su dev -c "terraform init"
su dev -c "terraform workspace new $WORKSPACE"
TERRAFORM_INIT

COPY --chown=dev:dev terraform-020-chillbox/upload-artifacts.sh .
COPY --chown=dev:dev terraform-bin bin
COPY --chown=dev:dev terraform-020-chillbox/bin/ bin/
