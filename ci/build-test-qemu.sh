#!/bin/bash
set -xeuo pipefail

# This script is the entrypoint for PRs to this repo via OpenShift Prow.
dn=$(dirname $0)
exec ${dn}/build-test-qemu-init.sh "rhel-8.5"
