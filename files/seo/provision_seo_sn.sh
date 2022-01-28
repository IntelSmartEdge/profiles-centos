#!/usr/bin/env bash

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

set -euo pipefail
set -x

# shellcheck disable=SC2269 # variable origin: pre.sh
param_username=${param_username}
# shellcheck disable=SC2269 # variable origin: pre.sh
param_token=${param_token}
# shellcheck disable=SC2269 # variable origin: pre.sh
param_bootstrapurl=${param_bootstrapurl}
# shellcheck disable=SC2269 # variable origin: pre.sh
param_bare_os=${param_bare_os}

# Set up non-root user
echo "${param_username} ALL=(ALL) NOPASSWD:ALL" | tee "/etc/sudoers.d/${param_username}"
mkdir "/home/${param_username}/.ssh"
ssh-keygen -t rsa -f "/home/${param_username}/.ssh/id_rsa" -N "" -C "${param_username}"
cat /root/.ssh/id_rsa.pub >> "/home/${param_username}/.ssh/authorized_keys"

# Skip installing Experience Kit
if [ "${param_bare_os}" == "true" ]; then
    exit 0
fi

# shellcheck disable=SC2269 # variable origin: provision_settings
ek_path=${ek_path}
# shellcheck disable=SC2269 # variable origin: provision_settings
flavor=${flavor}

# Get inventory for single node
wget --header "Authorization: token ${param_token}" -O "${ek_path}/inventory.yml.tpl2" "${param_bootstrapurl}/files/seo/inventories/single_node.yml"
# shellcheck disable=SC2016 # envsubst needs the environment variables unexpanded
envsubst '$flavor $param_username' < "${ek_path}/inventory.yml.tpl2" > "${ek_path}/inventory.yml.tpl"
rm -rf "${ek_path}/inventory.yml.tpl2"
