#!/usr/bin/env sh

set -o errexit

apk add \
  -q --no-progress \
  aws-cli
aws --version
