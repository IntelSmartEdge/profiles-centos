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

set -a

# shellcheck disable=SC2269 # variable origin: pre.sh
param_token=${param_token}
# shellcheck disable=SC2269 # variable origin: pre.sh
param_bootstrapurl=${param_bootstrapurl}
# shellcheck disable=SC2269 # variable origin: pre.sh
http_proxy=${http_proxy}
# shellcheck disable=SC2269 # variable origin: pre.sh
param_username=${param_username}
# shellcheck disable=SC2269 # variable origin: pre.sh
param_bare_os=${param_bare_os}

# this is provided while using uOS
# shellcheck source=/dev/null
source /opt/bootstrap/functions

# --- Add Packages
centos_packages="openssh-server git python3-pip make libselinux-python selinux-policy selinux-policy-targeted python-perf python-gobject python-linux-procfs python-schedutils firewalld"
centos_epel_packages="arp-scan"

# --- List out any docker images you want pre-installed separated by spaces. ---
pull_sysdockerimagelist=""

# --- List out any docker tar images you want pre-installed separated by spaces.  We be pulled by wget. ---
wget_sysdockerimagelist="" 

# --- Install Extra Packages ---
# shellcheck disable=SC2154
run "Installing Extra Packages on Centos ${param_centosversion}" \
    "docker run -i --rm --privileged --name centos-installer ${DOCKER_PROXY_ENV} --network host -v $ROOTFS:/target/root centos:${param_centosversion} sh -c \
    '${MOUNT_BEFORE_CHROOT} && \
    LANG=C.UTF-8 chroot /target/root bash -c \
        \"set -x && export TERM=xterm-color && \
        ${MOUNT_BOOT_UNDER_CHROOT} && \
        sed -i -e \"s#^exclude=kernel.*##g\" /etc/yum.conf && \
        yum install -y ${centos_packages} && \
        sed \\\"s,.*Banner.*,Banner /etc/issue.net,g\\\" -i /etc/ssh/sshd_config\"'" \
    "${PROVISION_LOG}"

# --- Install EPEL Packages ---
# shellcheck disable=SC2154
run "Installing EPEL Packages on Centos ${param_centosversion}" \
    "docker run -i --rm --privileged --name centos-installer ${DOCKER_PROXY_ENV} --network host -v $ROOTFS:/target/root centos:${param_centosversion} sh -c \
    '${MOUNT_BEFORE_CHROOT} && \
    LANG=C.UTF-8 chroot /target/root bash -c \
        \"set -x && export TERM=xterm-color && \
        ${MOUNT_BOOT_UNDER_CHROOT} && \
        yum install -y epel-release && \
        yum install -y ${centos_epel_packages} && \
        yum remove -y epel-release\"'" \
    "${PROVISION_LOG}"

# --- Pull any and load any system images ---
for image in $pull_sysdockerimagelist; do
    run "Installing system-docker image $image" "docker exec -i system-docker docker pull $image" "${PROVISION_LOG}"
done
for image in $wget_sysdockerimagelist; do
    run "Installing system-docker image $image" "wget -O- $image 2>> ${PROVISION_LOG} | docker exec -i system-docker docker load" "${PROVISION_LOG}"
done

# disable SELinux, as it is misconfigured right after install
sed -i 's|SELINUX=.*|SELINUX=disabled|g' "$ROOTFS/etc/selinux/config"

# shellcheck source=./files/seo/provision_settings
source <(wget --header "Authorization: token ${param_token}" -O- "${param_bootstrapurl}/files/seo/provision_settings")
# shellcheck disable=SC2269 # variable origin: provision_settings
scenario=${scenario}
# shellcheck disable=SC2269 # variable origin: provision_settings
controller_mac=${controller_mac}

primary_interface=$(ip route get 8.8.8.8 | head -n1 | awk '{print $5}')
primary_interface_mac=$(cat "/sys/class/net/${primary_interface}/address")
is_controller=no # multi-node

if [[ "${scenario}" = "single-node" ]]; then
    ssh_certs_mount=""
    scenario_info="single-node"
elif [[ "${scenario}" = "multi-node" ]]; then
    ssh_certs_mount="-v /hostroot/certs:/target/root/CAssh"

    if [ -z "${controller_mac}" ] || [ "${controller_mac}" = "${primary_interface_mac}" ]; then
        is_controller=yes
        scenario_info="multi-node/controlplane"
    else
        scenario_info="multi-node/node"
    fi
else
    run "Unknown scenario: $scenario. Exiting." \
        "false" \
        "${PROVISION_LOG}"
fi

run "Preparing host for Experience Kits. Scenario: ${scenario_info}" \
    "docker run -i --rm --privileged --name centos-installer ${DOCKER_PROXY_ENV} --network host -v $ROOTFS:/target/root ${ssh_certs_mount} centos:${param_centosversion} sh -c \
    '${MOUNT_BEFORE_CHROOT} && \
    LANG=en_US.UTF-8 chroot /target/root bash -c \
    \"set -x && export TERM=xterm-color && \
        export param_token=$param_token && \
        export param_bootstrapurl=$param_bootstrapurl && \
        export param_username=$param_username && \
        export param_bare_os=$param_bare_os && \
        export is_controller=$is_controller && \
        export primary_interface=$primary_interface && \
        source <(wget --header \\\"Authorization: token ${param_token}\\\" -O- ${param_bootstrapurl}/files/seo/provision_settings) && \
        wget --header \\\"Authorization: token ${param_token}\\\" -O - ${param_bootstrapurl}/files/seo/provision_seo_common.sh | bash && \
        postfix=\\\$([[ \\\"\\\$scenario\\\" = \\\"single-node\\\" ]] && echo 'sn' || echo 'mn') && \
        wget --header \\\"Authorization: token ${param_token}\\\" -O- ${param_bootstrapurl}/files/seo/provision_seo_\\\$postfix.sh | bash && \
        echo finished\"'" \
    "${PROVISION_LOG}"
