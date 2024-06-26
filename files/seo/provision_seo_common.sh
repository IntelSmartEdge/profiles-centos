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
param_token=${param_token}
# shellcheck disable=SC2269 # variable origin: pre.sh
param_bootstrapurl=${param_bootstrapurl}
# shellcheck disable=SC2269 # variable origin: pre.sh
param_bare_os=${param_bare_os}

# Generate SSH key
ssh-keygen -t rsa -q -f "$HOME/.ssh/id_rsa" -N "" <<< y
touch "$HOME/.ssh/authorized_keys"
cat "$HOME/.ssh/id_rsa.pub" >> "$HOME/.ssh/authorized_keys"
# Generate host SSH keys
sshd-keygen

# Install pipenv
python3 -m pip install pipenv
echo "export PATH=${HOME}/.local/bin:$PATH" >> ~/.bashrc
export PATH=${HOME}/.local/bin:$PATH

# Skip installing Experience Kit
if [ "${param_bare_os}" == "true" ]; then
    exit 0
fi

# (re)load settings - bash's associative arrays cannot be exported
# shellcheck source=./files/seo/provision_settings
source <(wget --header "Authorization: token ${param_token}" -O- "${param_bootstrapurl}/files/seo/provision_settings")

# shellcheck disable=SC2269 # variable origin: provision_settings
ek_path=${ek_path}
# shellcheck disable=SC2269 # variable origin: provision_settings
branch=${branch}
# shellcheck disable=SC2269 # variable origin: provision_settings
url=${url}

# Systemd service
wget --header "Authorization: token ${param_token}" -O /tmp/seo_deploy.sh.tpl "${param_bootstrapurl}/files/seo/systemd/seo_deploy.sh"
wget --header "Authorization: token ${param_token}" -O /tmp/seo.service.tpl "${param_bootstrapurl}/files/seo/systemd/seo.service"
envsubst < /tmp/seo.service.tpl > /etc/systemd/system/seo.service
# shellcheck disable=SC2016 # envsubst needs the environment variables unexpanded
envsubst '$ek_path' < /tmp/seo_deploy.sh.tpl > /usr/bin/seo_deploy.sh
rm -rf /tmp/seo.service.tpl /tmp/seo_deploy.sh.tpl
systemctl enable seo

# Clone Experience Kit
IFS="/" read -r -a url_split <<< "$url"

if [ -n "${git_user}" ] && [ -n "${git_password}" ]; then
    credentials="${git_user}:${git_password}"
else
    credentials="${git_user}${git_password}"
fi

rm -rf "${ek_path}"
if [ -n "${credentials}" ]; then
    git config --global url."${url_split[0]}//${credentials}@".insteadOf "${url_split[0]}//"
fi

if ! (git clone --branch "${branch}" --recursive "${url}" "${ek_path}") then
    # Workaround for no_proxy issue.
    export no_proxy="${no_proxy},${url_split[2]}"
    git clone --branch "${branch}" --recursive "${url}" "${ek_path}"
fi

if [ -n "${credentials}" ]; then
    git config --global --remove-section url."${url_split[0]}//${credentials}@"
fi

cd "${ek_path}"

# shellcheck disable=SC1090 
source <(wget --header "Authorization: token ${param_token}" -O- "${param_bootstrapurl}/files/seo/download_sideload_files.sh")

# Install Python packages
make install-dependencies

# Get group_var and host_vars
mkdir -p inventory/default/group_vars/{all,controller_group,edgenode_group} inventory/default/host_vars/{controller,node01}
wget --header "Authorization: token ${param_token}" -O inventory/default/group_vars/all/90-settings.yml "${param_bootstrapurl}/files/seo/group_vars/all.yml"
wget --header "Authorization: token ${param_token}" -O inventory/default/group_vars/controller_group/90-settings.yml "${param_bootstrapurl}/files/seo/group_vars/controller_group.yml"
wget --header "Authorization: token ${param_token}" -O inventory/default/group_vars/edgenode_group/90-settings.yml "${param_bootstrapurl}/files/seo/group_vars/edgenode_group.yml"
wget --header "Authorization: token ${param_token}" -O inventory/default/host_vars/controller/90-settings.yml "${param_bootstrapurl}/files/seo/host_vars/controller.yml"
wget --header "Authorization: token ${param_token}" -O inventory/default/host_vars/node01/90-settings.yml "${param_bootstrapurl}/files/seo/host_vars/node01.yml"
