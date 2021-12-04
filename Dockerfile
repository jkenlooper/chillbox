# syntax=docker/dockerfile:1

FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y gpg

## s6-overlay
# https://github.com/just-containers/s6-overlay

ARG S6_OVERLAY_INSTALLER_RELEASE=v2.2.0.3
ENV S6_OVERLAY_INSTALLER_RELEASE=${S6_OVERLAY_INSTALLER_RELEASE}

ADD https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_INSTALLER_RELEASE}/s6-overlay-amd64-installer /tmp/
ADD https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_INSTALLER_RELEASE}/s6-overlay-amd64-installer.sig /tmp/

RUN gpg --keyserver pgp.surfnet.nl --recv-keys 6101B2783B2FD161
RUN gpg --verify /tmp/s6-overlay-amd64-installer.sig /tmp/s6-overlay-amd64-installer

RUN chmod +x /tmp/s6-overlay-amd64-installer && /tmp/s6-overlay-amd64-installer /


## Include Chill
RUN apt-get --yes update \
  && apt-get --yes upgrade \
  && apt-get --yes install --no-install-suggests --no-install-recommends \
  gcc \
	git \
  libffi-dev \
  libpython3-dev \
  libsqlite3-dev \
  python3 \
  python3-pip \
  python-is-python3 \
  python3-dev \
  python3-venv \
  sqlite3

WORKDIR /usr/local/src/chill-venv
COPY requirements.txt ./
RUN python -m venv .
RUN /usr/local/src/chill-venv/bin/pip install --upgrade pip wheel
RUN /usr/local/src/chill-venv/bin/pip install --disable-pip-version-check -r requirements.txt
RUN ln -s /usr/local/src/chill-venv/bin/chill /usr/local/bin/chill && chill --version


## Other apps that will run as services
#COPY services/example /etc/services.d/example

## nginx
EXPOSE 80

RUN apt-get update && \
    apt-get install -y nginx && \
    echo "daemon off;" >> /etc/nginx/nginx.conf

ENTRYPOINT ["/init"]
CMD ["nginx"]
