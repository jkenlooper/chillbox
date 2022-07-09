# syntax=docker/dockerfile:1.4.1

# UPKEEP due: "2022-10-08" label: "Alpine Linux base image" interval: "+3 months"
# docker pull alpine:3.16.0
# docker image ls --digests alpine
FROM alpine:3.16.0@sha256:686d8c9dfa6f3ccfc8230bc3178d23f84eeaf7e457f36f271ab1acc53015037c

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
COPY check-json.py ./
COPY verify-sites-artifact.sh ./

ENV SITES_ARTIFACT=""
ENV SITES_MANIFEST=""

CMD ["/usr/local/src/verify-sites/verify-sites-artifact.sh"]
