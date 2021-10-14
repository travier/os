#!/bin/bash
# This test is a dumping ground for quick read-only tests.
set -xeuo pipefail

cd $(mktemp -d)

ok() {
    echo "ok" "$@"
}

fatal() {
  echo "$@"
  exit 1
}

# Ensure we have tmpfs on /tmp like Fedora(FCOS)
tmpfs=$(findmnt -n -o FSTYPE /tmp)
if [ "${tmpfs}" != "tmpfs" ]; then
  fatal "Expected tmpfs on /tmp, found: ${tmpfs}"
fi
echo "ok tmpfs"

# SELinux should be on
#  enforce=$(getenforce)
# if [ "${enforce}" != "Enforcing" ]; then
#   fatal "Expected SELinux Enforcing, found ${enforce}"
# fi
# echo "ok selinux"

# We have forgotten to chmod a+x the chrony generator, and accidentally
# omitted it entirely.
find /usr/lib/systemd/system-generators -type f | while read f; do
  if ! test -x $f; then
    fatal "generator is not executable: $f"
  fi
done
test -x /usr/lib/systemd/system-generators/coreos-platform-chrony
echo "ok generators"

# https://bugzilla.redhat.com/show_bug.cgi?id=1830280
case "$(arch)" in
  x86_64)
    dmesg | grep ' random:' > random.txt
    if ! grep -qe 'crng done.*trust.*CPU' <random.txt; then
      sed -e 's/^/# /' < random.txt
      fatal "Failed to find crng trusting CPU"
    fi
    echo "ok random trust cpu" ;;
  *) echo "Don't know how to test hardware RNG state on arch=$(arch)" ;;
esac

if [ "$(systemctl is-enabled afterburn-sshkeys@.service)" = enabled ]; then
  fatal "error: afterburn-sshkeys@ is enabled"
fi
echo "ok afterburn-sshkeys@ is disabled"

# Make sure that kdump didn't start (it's either disabled, or enabled but
# conditional on crashkernel= karg, which we don't bake).
if ! systemctl show -p ActiveState kdump.service | grep -q ActiveState=inactive; then
    fatal "Unit kdump.service shouldn't be active"
fi
echo "ok kdump.service not active"

test -d /etc/yum.repos.d
echo "ok have /etc/yum.repos.d"

# FIXME C9S
# check if RHEL version encoded in RHCOS build version matches /etc/os-release
#source /etc/os-release
#if [ "${RHEL_VERSION//.}" != "$(echo "${VERSION}" | awk -F "." '{print $2}')" ]; then
#  fatal "error: RHEL version does not match"
#fi
#echo "ok RHEL version matches"

# check that we are not including the kernel headers on the host
# See:
# - https://bugzilla.redhat.com/show_bug.cgi?id=1814719
# - https://gitlab.cee.redhat.com/coreos/redhat-coreos/-/merge_requests/1116
if test -d /usr/include/linux; then
   fatal "should not have kernel headers on host"
fi
echo "ok kernel headers not on host"

# the below is duplicated from FCOS' misc-ro (we should figure out a way to
# share external host tests in common between RHCOS and FCOS more easily)

on_platform() {
    grep -q " ignition.platform.id=$1 " /proc/cmdline
}

get_journal_msg_timestamp() {
    journalctl -o json -b 0 --grep "$1" \
        | jq -r --slurp '.[0]["__MONOTONIC_TIMESTAMP"]'
}

switchroot_ts=$(get_journal_msg_timestamp 'Switching root.')
nm_ts=$(get_journal_msg_timestamp 'NetworkManager .* starting')
# by default, kola on QEMU shouldn't need to bring up networking
# https://github.com/coreos/fedora-coreos-config/pull/426
if [[ $nm_ts -lt $switchroot_ts ]] && on_platform qemu; then
    fatal "NetworkManager started in initramfs!"
# and as a sanity-check that this test works, verify that on AWS
# we did bring up networking in the initrd
elif [[ $nm_ts -gt $switchroot_ts ]] && on_platform aws; then
    fatal "NetworkManager not started in initramfs!"
fi
echo ok conditional initrd networking

# Verify this is shipped
if ! test -f /usr/bin/qemu-ga; then
  fatal "missing qemu guest agent"
fi
echo ok qemu guest agent

case "$(arch)" in
    x86_64|aarch64)
        # This is just a basic sanity check; at some point we
        # will implement "project-owned tests run in the pipeline"
        # and be able to run the existing bootupd tests:
        # https://github.com/coreos/fedora-coreos-config/pull/677
        bootupctl status
        ok bootupctl
        ;;
esac

if ! systemctl show -p ActiveState coreos-generate-iscsi-initiatorname.service | grep -q ActiveState=active; then
    fatal "coreos-generate-iscsi-initiatorname.service not active"
fi
if ! test -f /etc/iscsi/initiatorname.iscsi; then
    fatal "Missing /etc/iscsi/initiatorname.iscsi"
fi
echo "ok iSCSI initiator name"

systemctl is-enabled logrotate.timer
echo "ok logrotate"

bin_ctx=$(stat -c %C /usr/sbin)
usrlocal_sbin_ctx=$(stat -c %C /var/usrlocal/sbin)
if test "${bin_ctx}" != "${usrlocal_sbin_ctx}"; then
  fatal "/usr/sbin is ${bin_ctx} but /var/usrlocal/sbin is ${usrlocal_sbin_ctx}"
fi
test -f /var/lib/.coreos-usrlocal-fixup.stamp
echo "ok usr/local/sbin fixup"

rpm -q conntrack-tools
test ! -f /usr/lib/systemd/system/conntrackd.service
echo "ok conntrack tools without daemon"

# Ensure NM's internal DHCP client runs by default
if ! journalctl -b 0 -u NetworkManager --grep=dhcp | grep -q "Using DHCP client 'internal'"; then
  fatal "NetworkManager's internal DHCP client is not running"
fi

# Check that we have the proper presets for console-login-helper-messages in RHCOS.
# Versions of CLHM prior to v0.21 have `issuegen`-related systemd units.
if test -f /usr/lib/systemd/system/console-login-helper-messages-issuegen.service; then
  if ! systemctl is-enabled console-login-helper-messages-issuegen.path; then
    fatal "console-login-helper-messages-issuegen.path required but not enabled"
  fi
  if ! systemctl is-enabled console-login-helper-messages-issuegen.service; then
    fatal "console-login-helper-messages-issuegen.service required but not enabled"
  fi
fi
echo "ok console-login-helper-messages presets present"

# Check that rhaos packages do not match the OpenShift version
if [[ $(rpm -qa | grep rhaos | grep -v $OPENSHIFT_VERSION) ]]; then
  fatal "Error: rhaos packages do not match OpenShift version"
fi

