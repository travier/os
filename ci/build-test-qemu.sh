#!/bin/bash
set -xeuo pipefail
# This script is the entrypoint for PRs to this repo via OpenShift Prow.
dn=$(dirname $0)
# Prow jobs don't support adding emptydir today
export COSA_SKIP_OVERLAY=1
# Create a temporary cosa workdir
cd "$(mktemp -d)"
cosa init "${tmpsrc}"/src
# Grab the raw value of `mutate-os-release` and use sed to convert the value
# to X-Y format
# ocpver=$(rpm-ostree compose tree --print-only src/config/manifest.yaml | jq -r '.["mutate-os-release"]' | sed 's|\.|-|')
# curl -L http://base-"${ocpver}"-rhel8.ocp.svc.cluster.local > src/config/ocp.repo
cosa fetch
cosa build
cosa buildextend-extensions
# FIXME C9S no secure boot
# cosa kola --basic-qemu-scenarios
cosa kola run basic
cosa kola run 'ext.*'
# TODO: all tests in the future, but there are a lot
# and we want multiple tiers, and we need to split them
# into multiple pods and stuff.
