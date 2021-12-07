# syntax=docker/dockerfile:1

FROM alpine:3.15.0

## s6-overlay
# https://github.com/just-containers/s6-overlay
ARG S6_OVERLAY_RELEASE=v2.2.0.3
ENV S6_OVERLAY_RELEASE=${S6_OVERLAY_RELEASE}
RUN apk update && \
  apk add --no-cache \
  gnupg \
  gnupg-dirmngr && \
  mkdir -p /tmp && \
	wget -P /tmp/ \
		 https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_RELEASE}/s6-overlay-amd64.tar.gz && \
	wget -P /tmp/ \
		 https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_RELEASE}/s6-overlay-amd64.tar.gz.sig && \
	gpg --keyserver pgp.surfnet.nl --recv-keys 6101B2783B2FD161 && \
	gpg --verify /tmp/s6-overlay-amd64.tar.gz.sig /tmp/s6-overlay-amd64.tar.gz && \
  tar xzf /tmp/s6-overlay-amd64.tar.gz -C / && \
	rm -rf /tmp/s6-overlay-amd64.tar.gz /tmp/s6-overlay-amd64.tar.gz.sig && \
  apk --purge del \
    gnupg \
    gnupg-dirmngr
ENTRYPOINT [ "/init" ]

## nginx
EXPOSE 80
RUN apk update && \
  apk add --no-cache \
  nginx && \
	nginx -v

## chill
WORKDIR /usr/local/src/chill-venv
COPY requirements.txt ./
RUN apk update && \
  apk add --no-cache \
  gcc \
  python3 \
  python3-dev \
  libffi-dev \
  build-base \
  musl-dev \
  make \
  git \
  sqlite && \
  ln -s /usr/bin/python3 /usr/bin/python && \
  python -m venv . && \
	/usr/local/src/chill-venv/bin/pip install --upgrade pip wheel && \
	/usr/local/src/chill-venv/bin/pip install --disable-pip-version-check -r requirements.txt && \
	ln -s /usr/local/src/chill-venv/bin/chill /usr/local/bin/chill && \
  apk --purge del \
    gcc \
    python3-dev \
    libffi-dev \
    build-base \
    musl-dev \
    make \
  git && \
	chill --version


## aws cli
RUN apk update && \
  apk add --no-cache \
  jq \
  aws-cli && \
	aws --version
  #apk --purge del \
    #aws-cli

ARG S3_ENDPOINT_URL=http://localhost:9000
ARG IMMUTABLE_BUCKET_NAME=chillboximmutable
ARG ARTIFACT_BUCKET_NAME=chillboxartifact
# podman use secret in build?
# docker build --secret=id=id,src=path
#RUN --mount=type=secret,id=mysecret cat /run/secrets/mysecret

ARG slugname="jengalaxyart"
WORKDIR /usr/local/src/$slugname
COPY sites/$slugname.site.json ./
RUN --mount=type=secret,id=awscredentials source /run/secrets/awscredentials \
  && echo "access key id $AWS_ACCESS_KEY_ID" \
  && aws --version \
  && export version="$(jq -r '.version' $slugname.site.json)" \
  && aws --endpoint-url "$S3_ENDPOINT_URL" \
    s3 cp s3://$ARTIFACT_BUCKET_NAME/${slugname}/$slugname-$version.artifact.tar.gz \
    ./


## for each site
# s3 cp the artifact
#
## Other apps that will run as services
#COPY services/example /etc/services.d/example

# fetch artifact file for each chill app

# On remote chillbox host (only read access to S3)
# - Download artifact tar.gz from S3
# - Expand to new directory for the version
# - chill init, load yaml
# - add and enable, start the systemd service for new version
# - stage the new version by updating NGINX environment variables
# - run integration tests on staged version
# - promote the staged version to production by updating NGINX environment variables
# - remove old version
# - write version to /srv/chillbox/$slugname/version.txt

# On local
# - Delete old immutable versioned path on S3

CMD ["nginx"]
