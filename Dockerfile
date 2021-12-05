# syntax=docker/dockerfile:1

FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get --yes install \
		gpg \
		unzip \
		ca-certificates \
		lsb-release \
		curl

## s6-overlay
# https://github.com/just-containers/s6-overlay
ARG S6_OVERLAY_INSTALLER_RELEASE=v2.2.0.3
ENV S6_OVERLAY_INSTALLER_RELEASE=${S6_OVERLAY_INSTALLER_RELEASE}
RUN mkdir -p /tmp && \
	curl --location --show-error --silent \
		 -o /tmp/s6-overlay-amd64-installer \
		 https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_INSTALLER_RELEASE}/s6-overlay-amd64-installer && \
	curl --location --show-error --silent \
		 -o /tmp/s6-overlay-amd64-installer.sig \
		 https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_INSTALLER_RELEASE}/s6-overlay-amd64-installer.sig && \
	gpg --keyserver pgp.surfnet.nl --recv-keys 6101B2783B2FD161 && \
	gpg --verify /tmp/s6-overlay-amd64-installer.sig /tmp/s6-overlay-amd64-installer && \
	chmod +x /tmp/s6-overlay-amd64-installer && \
	/tmp/s6-overlay-amd64-installer / && \
	rm -rf /tmp/s6-overlay-amd64-installer /tmp/s6-overlay-amd64-installer.sig

# Install latest stable version of NGINX
# https://nginx.org/en/linux_packages.html#Ubuntu
# Set up the apt repository for stable nginx packages and pin them.


## aws cli
ARG AWS_CLI_VERSION=2.2.11
ARG AWSCLIV2_CHECKSUM="a0fdfd071a62f7ad5510cfa606a937b3  awscliv2.zip"
WORKDIR /tmp
RUN curl -o awscliv2.zip https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWS_CLI_VERSION}.zip && \
	echo "$AWSCLIV2_CHECKSUM" | md5sum --check && \
	unzip awscliv2.zip && \
	./aws/install && \
	rm -rf /tmp/aws /tmp/awscliv2.zip && \
	aws --version

## Include Chill
RUN apt-get --yes update && \
  apt-get --yes upgrade && \
  apt-get --yes install --no-install-suggests --no-install-recommends \
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
RUN python -m venv . && \
	/usr/local/src/chill-venv/bin/pip install --upgrade pip wheel && \
	/usr/local/src/chill-venv/bin/pip install --disable-pip-version-check -r requirements.txt && \
	ln -s /usr/local/src/chill-venv/bin/chill /usr/local/bin/chill && \
	chill --version


## Other apps that will run as services
#COPY services/example /etc/services.d/example

# fetch artifact file for each chill app

## nginx
EXPOSE 80

RUN apt-get update && \
    apt-get install -y nginx && \
    echo "daemon off;" >> /etc/nginx/nginx.conf

ENTRYPOINT ["/init"]
CMD ["nginx"]
