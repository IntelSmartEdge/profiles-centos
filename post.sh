#!/bin/bash

# INTEL CONFIDENTIAL
#
# Copyright 2019-2022 Intel Corporation.
#
# This software and the related documents are Intel copyrighted materials, and your use of
# them is governed by the express license under which they were provided to you ("License").
# Unless the License provides otherwise, you may not use, modify, copy, publish, distribute,
# disclose or transmit this software or the related documents without Intel's prior written permission.
#
# This software and the related documents are provided as is, with no express or implied warranties,
# other than those that are expressly stated in the License.


# this is provided while using uOS
# shellcheck source=/dev/null
source /opt/bootstrap/functions

# --- Cleanup ---

sed -i 's|insecure||g' "$ROOTFS/root/.curlrc"
sed -i 's|sslverify=0||g' "$ROOTFS/etc/dnf/dnf.conf"
sed -i 's|sslverify=0||g' "$ROOTFS/etc/yum.conf"

# create some empty files that some services expect to find (otherwise they fail!)
touch "$ROOTFS/etc/sysconfig/network"

if [ -n "${param_docker_login_user}" ] && [ -n "${param_docker_login_pass}" ]; then
    run "Logout from a Docker registry" \
        "docker logout" \
        "${PROVISION_LOG}"
fi

stop=$(date +%s)
# shellcheck disable=SC2154 # $start defined in pre.sh
elapsed_total_seconds=$((stop - start))
elapsed_min=$((elapsed_total_seconds / 60))
elapsed_sec=$((elapsed_total_seconds % 60))

run "Finished. Elapsed time: ${elapsed_min} minutes ${elapsed_sec} seconds (total seconds: ${elapsed_total_seconds})" \
    "echo 'Finished. Elapsed time: ${elapsed_min} minutes ${elapsed_sec} seconds (total seconds: ${elapsed_total_seconds})'" \
    "${PROVISION_LOG}"

run "Provisioning log will be available in /var/log/provisioning.log" \
    "true" \
    "/dev/null"

cp "${PROVISION_LOG}" "$ROOTFS/var/log/provisioning.log"

# shellcheck disable=SC2154 # $freemem defined in pre.sh
if [ "$freemem" -lt 6291456 ]; then
    run "Cleaning up" \
        "killall dockerd &&
        sleep 3 &&
        swapoff $ROOTFS/swap &&
        rm $ROOTFS/swap &&
        while (! rm -fr $ROOTFS/tmp/ > /dev/null ); do sleep 2; done" \
        "${PROVISION_LOG}"
fi

# shellcheck disable=SC2154 # $BOOTFS, $ROOTFS, and $param_diskencrypt defined in pre.sh
umount "$BOOTFS" &&
umount "$ROOTFS" &&
if [[ $param_diskencrypt == 'true' ]]; then
    cryptsetup luksClose root 2>&1 | tee -a /dev/console
fi

run "Rebooting in 10 seconds" \
    "sleep 10 && reboot" \
    "/dev/null"
