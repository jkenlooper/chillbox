#!/usr/bin/env sh

set -o errexit

{% include 'chillbox:create_dirs-PATH_SENSITIVE.jinja' %}

{% include 'chillbox:create_dirs-PATH_SECRETS.jinja' %}
