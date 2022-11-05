# syntax=docker/dockerfile:1.4.3

# UPKEEP due: "2023-01-10" label: "Alpine Linux base image" interval: "+3 months"
# docker pull alpine:3.16.2
# docker image ls --digests alpine
FROM alpine:3.16.2@sha256:bc41182d7ef5ffc53a40b044e725193bc10142a1243f395ee852a8d9730fc2ad as build

WORKDIR /build

RUN <<DEV_USER
# Create an unprivileged user that will only have access to /build directory.
addgroup -g 2000 dev
adduser -u 2000 -G dev -s /bin/sh -D dev
chown -R dev:dev /build
DEV_USER

COPY --chown=dev:dev local-scripts/build.sh /build/build.sh

# Only the src/ directory is copied to the container.
COPY --chown=dev:dev src /build/src

ENV BUILD_SRC_DIR=/build/src
ENV BUILD_DIST_DIR=/build/dist

USER dev

# Build the dist files inside the container
RUN ./build.sh
