# syntax=docker/dockerfile:1.3.0-labs

# UPKEEP due: "2022-08-12" label: "hashicorp/terraform base image" interval: "+4 months"
# docker pull hashicorp/terraform:1.2.0-alpha-20220328
# docker image ls --digests hashicorp/terraform
FROM hashicorp/terraform:1.2.0-alpha-20220328@sha256:94c01aed14a10ef34fad8d8c7913dd605813076ecc824284377d7f1375aa596c

RUN <<INSTALL
apk update
apk add \
  aws-cli \
  jq \
  gpg \
  gpg-agent

INSTALL

WORKDIR /usr/local/src/chillbox-terraform

ARG ALPINE_CUSTOM_IMAGE=""
ARG ALPINE_CUSTOM_IMAGE_CHECKSUM=""
RUN <<WGET_ALPINE_CUSTOM_IMAGE
set -o errexit
test -n "${ALPINE_CUSTOM_IMAGE}"
test -n "${ALPINE_CUSTOM_IMAGE_CHECKSUM}"
wget $ALPINE_CUSTOM_IMAGE
alpine_custom_image_file="$(basename ${ALPINE_CUSTOM_IMAGE})"
md5sum "${alpine_custom_image_file}"
echo "${ALPINE_CUSTOM_IMAGE_CHECKSUM}  ${alpine_custom_image_file}" | md5sum -c
cat <<HERE > alpine_custom_image.auto.tfvars
alpine_custom_image = "${alpine_custom_image_file}"
HERE
WGET_ALPINE_CUSTOM_IMAGE

# Set WORKSPACE before SETUP to invalidate that layer.
ARG WORKSPACE=development
ENV WORKSPACE=${WORKSPACE}
ENV PATH=/usr/local/src/chillbox-terraform/bin:${PATH}

ARG SITES_ARTIFACT=""
ENV SITES_ARTIFACT=${SITES_ARTIFACT}
ARG CHILLBOX_ARTIFACT=""
ENV CHILLBOX_ARTIFACT=${CHILLBOX_ARTIFACT}
ARG SITES_MANIFEST=""
ENV SITES_MANIFEST=${SITES_MANIFEST}
ENV endpoint_url="http://localhost:9000"

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
SETUP

COPY --chown=dev:dev chillbox-terraform-010-infra.output.json .
RUN <<SITES_ARTIFACT_CONFIG
if [ ! -f "chillbox-terraform-010-infra.output.json" ]; then
  echo "Missing file: chillbox-terraform-010-infra.output.json"
  exit 1
fi

# Set the immutable_bucket_name and artifact_bucket_name from the infra output.
# TODO add site domain list
jq \
  --arg jq_sites_artifact "${SITES_ARTIFACT}" \
  --arg jq_chillbox_artifact "${CHILLBOX_ARTIFACT}" \
  --arg jq_sites_manifest "${SITES_MANIFEST}" \
  '{
  sites_artifact: $jq_sites_artifact,
  chillbox_artifact: $jq_chillbox_artifact,
  sites_manifest: $jq_sites_manifest,
  } + map_values(.value)' \
  chillbox-terraform-010-infra.output.json \
  > chillbox_sites.auto.tfvars.json
chown dev:dev chillbox_sites.auto.tfvars.json
SITES_ARTIFACT_CONFIG

COPY extract-terraform-artifact-modules.sh .
COPY --chown=dev:dev dist ./dist
RUN <<ARTIFACT_MODULES
# TODO extract each tar.gz in the dist/ if the site has defined a terraform module.
# TODO extract and find any .tf files in the artifact for each site. Treat the
# different services as different modules that can set the terraform required
# providers as needed. Top level will define the terraform providers.
jq '{
  sites_artifact: .sites_artifact,
  sites_manifest: .sites_manifest,
  }' chillbox_sites.auto.tfvars.json \
  | ./extract-terraform-artifact-modules.sh
# the artifact-modules.tf file is created via the above command.


ARTIFACT_MODULES

COPY --chown=dev:dev chillbox.tf .
COPY --chown=dev:dev variables.tf .
COPY --chown=dev:dev main.tf .
COPY --chown=dev:dev alpine-box-init.sh.tftpl .
COPY --chown=dev:dev private.auto.tfvars .
COPY --chown=dev:dev bin/doterra.sh ./bin/doterra.sh
COPY --chown=dev:dev .terraform.lock.hcl .

RUN <<TERRAFORM_INIT
su dev -c "terraform init"
su dev -c "terraform workspace new $WORKSPACE"
TERRAFORM_INIT

USER dev
