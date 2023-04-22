#!/usr/bin/env sh
set -o errexit

set -- ""

# exampleUPKEEP due: "2023-04-21" label: "Vuln exception GHSA-r9hx-vwmv-q579" interval: "+3 months"
# n/a
# https://osv.dev/vulnerability/GHSA-r9hx-vwmv-q579
#set -- "$@" --ignore-vuln "GHSA-r9hx-vwmv-q579"

# UPKEEP due: "2023-10-22" label: "Vuln exception GHSA-c33w-24p9-8m24" interval: "+6 months"
# n/a
# https://osv.dev/vulnerability/GHSA-c33w-24p9-8m24
set -- "$@" --ignore-vuln "GHSA-c33w-24p9-8m24"

# Change to the app directory so the find-links can be relative.
cd /home/dev/app
pip-audit \
    --require-hashes \
    --progress-spinner off \
    --local \
    --strict \
    --vulnerability-service pypi \
    $@ \
    -r ./dep/requirements.txt
pip-audit \
    --progress-spinner off \
    --local \
    --strict \
    --vulnerability-service osv \
    $@ \
    -r ./dep/requirements.txt
