# syntax=docker/dockerfile:1.3.0-labs

# UPKEEP due: "2022-07-12" label: "Alpine Linux base image" interval: "+3 months"
# docker pull alpine:3.15.4
# docker image ls --digests alpine
FROM alpine:3.15.4@sha256:4edbd2beb5f78b1014028f4fbb99f3237d9561100b6881aabbf5acce2c4f9454

WORKDIR /home/dev

RUN <<SETUP
addgroup dev
adduser -G dev -D dev
cat <<HERE > /home/dev/sleep.sh
#!/usr/bin/env sh
while true; do
  printf 'z'
  sleep 60
done
HERE
chmod +x /home/dev/sleep.sh

mkdir -p /var/lib/chillbox-shared-secrets
chown -R dev:dev /var/lib/chillbox-shared-secrets
chmod -R 700 /var/lib/chillbox-shared-secrets
SETUP

USER dev

CMD ["/home/dev/sleep.sh"]
