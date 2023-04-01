# syntax=docker/dockerfile:1.4.3

# UPKEEP due: "2023-05-21" label: "hashicorp/terraform base image" interval: "+4 months"
# docker pull hashicorp/terraform:1.3.7
# docker image ls --digests hashicorp/terraform
FROM hashicorp/terraform:1.3.7@sha256:48dbb8ae5b0d0fa63424e2eedffd92751ed8d0f2640db4e1dcaa7efc0771dc41

RUN <<DEV_USER
addgroup -g 44444 dev
adduser -u 44444 -G dev -s /bin/sh -D dev
DEV_USER

WORKDIR /usr/local/src/artifact-modules

RUN <<INSTALL
set -o errexit
apk update
apk add \
  jq \
  vim \
  mandoc man-pages \
  coreutils

INSTALL

ENV PATH=/usr/local/src/chillbox-terraform/bin:${PATH}

RUN <<SETUP
set -o errexit
chown -R dev:dev .


mkdir -p /var/lib/terraform-030-artifact-modules
chown -R dev:dev /var/lib/terraform-030-artifact-modules
chmod -R 0700 /var/lib/terraform-030-artifact-modules
SETUP

COPY --chown=dev:dev terraform-030-artifact-modules/.terraform.lock.hcl .

RUN <<TERRAFORM_INIT
set -o errexit
su dev -c "terraform init"
TERRAFORM_INIT

COPY --chown=dev:dev terraform-030-artifact-modules/extract-terraform-artifact-modules.sh .
#COPY --chown=dev:dev dist ./dist
RUN <<ARTIFACT_MODULES
set -o errexit
echo "Extracting artifact terraform modules is not implemented." && exit 0

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

# Will need to init again since the artifact modules will have dependencies.
su dev -c "terraform init"
ARTIFACT_MODULES

COPY --chown=dev:dev terraform-bin bin
COPY --chown=dev:dev terraform-030-artifact-modules/bin/ bin/
