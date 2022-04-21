#!/bin/bash
set -xeuo pipefail
# SCOS wrapper for the entrypoint for PRs to this repo via OpenShift Prow.
dn=$(dirname "${0}")
exec "${dn}/build-test-qemu-rhcos.sh" scos
