# syntax=docker/dockerfile:1.4.3

# UPKEEP due: "2023-01-10" label: "Alpine Linux base image" interval: "+3 months"
# docker pull alpine:3.16.2
# docker image ls --digests alpine
FROM alpine:3.16.2@sha256:bc41182d7ef5ffc53a40b044e725193bc10142a1243f395ee852a8d9730fc2ad

WORKDIR /usr/local/src/verify-sites
COPY requirements.txt ./
RUN <<DEPENDENCIES
set -o errexit
apk update
apk add sed attr grep coreutils jq

apk add python3 python3-dev

# Add other tools that are helpful when troubleshooting.
apk add mandoc man-pages docs
apk add vim

mkdir -p /usr/local/src/verify-sites
cd /usr/local/src/verify-sites
python3 -m venv .
./bin/pip install --upgrade pip wheel
./bin/pip install --disable-pip-version-check --compile -r requirements.txt

DEPENDENCIES

COPY site.schema.json ./
COPY check-json.py ./
COPY verify-sites-artifact.sh ./

ENV SITES_ARTIFACT=""
ENV SITES_MANIFEST=""

CMD ["/usr/local/src/verify-sites/verify-sites-artifact.sh"]
