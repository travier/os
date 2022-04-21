#!/bin/bash
set -xeuo pipefail
# This script is the entrypoint for PRs to this repo via OpenShift Prow.
dn=$(dirname "${0}")
# Prow jobs don't support adding emptydir today
export COSA_SKIP_OVERLAY=1
# Create a temporary cosa workdir if COSA_DIR is not set.
cosa_dir="${COSA_DIR:-$(mktemp -d)}"
echo "Using ${cosa_dir} for build"
cd "${cosa_dir}"
cosa init /src

# Default to building RHCOS unless we were explicitely called to build SCOS
if [[ "${#}" -eq 1 ]] && [[ "${1}" == "scos" ]]; then
    exec "${dn}/prow-build-test-qemu.sh" scos
fi
exec "${dn}/prow-build-test-qemu.sh"