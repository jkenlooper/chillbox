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

## aws cli
RUN apk update && \
  apk add --no-cache \
  aws-cli && \
	aws --version && \
  apk --purge del \
    aws-cli

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


## Other apps that will run as services
#COPY services/example /etc/services.d/example

# fetch artifact file for each chill app


CMD ["nginx"]
