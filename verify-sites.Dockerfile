# syntax=docker/dockerfile:1.3.0-labs

# UPKEEP due: "2022-07-12" label: "Alpine Linux base image" interval: "+3 months"
# docker pull alpine:3.15.4
# docker image ls --digests alpine
FROM alpine:3.15.4@sha256:4edbd2beb5f78b1014028f4fbb99f3237d9561100b6881aabbf5acce2c4f9454

WORKDIR /usr/local/src/verify-sites
COPY verify-sites/requirements.txt ./
RUN <<DEPENDENCIES
apk update
apk add sed attr grep coreutils jq

apk add python3 python3-dev

# Add other tools that are helpful when troubleshooting.
apk add mandoc man-pages docs
apk add vim

# TODO install
mkdir -p /usr/local/src/verify-sites
cd /usr/local/src/verify-sites
python3 -m venv .
./bin/pip install --upgrade pip wheel
./bin/pip install --disable-pip-version-check --compile -r requirements.txt

DEPENDENCIES


# The site.schema.json is at the top level of the project so it's easier to
# refer to.
COPY site.schema.json ./
COPY verify-sites/check-json.py ./
COPY verify-sites/verify-sites-artifact.sh ./

ENV SITES_ARTIFACT=""
ENV SITES_MANIFEST=""

CMD ["/usr/local/src/verify-sites/verify-sites-artifact.sh"]
