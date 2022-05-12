#!/bin/bash
set -xeuo pipefail

dn=$(dirname $0)

# Prow jobs don't support adding emptydir today
export COSA_SKIP_OVERLAY=1

# Create a temporary cosa workdir if COSA_DIR is not set.
cosa_dir="${COSA_DIR:-$(mktemp -d)}"
echo "Using $cosa_dir for build"
cd "$cosa_dir"

# Require that the RHEL version to use to build RHCOS is passed as first
# argument
if [[ "${#}" -ne 1 ]]; then
    echo "Missing required version parameter, e.g.: $0 rhel-8.5" 1>&2
    exit 1
fi

cosa init /src "${1}"

exec ${dn}/prow-build-test-qemu.sh "${1}"
