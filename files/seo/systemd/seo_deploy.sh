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

set -x
set -euo pipefail

# shellcheck disable=SC2154
ek_dir="$ek_path"
marker_filename="${ek_dir}/.deployed"
issue_files=(/etc/issue /etc/issue.net)

clear_status() {
  # Remove old info from /etc/issue{,.net}
  for f in "${issue_files[@]}"; do
    sed '/Smart Edge Open Deployment Status/d' -i "${f}" >/dev/null
    printf "%s\n" "$(< "${f}")" > "${f}" # Remove redundant newlines at the end of file
  done
}

set_status() {
  local deploy_status=$1
  for f in "${issue_files[@]}"; do
    echo -e "\nSmart Edge Open Deployment Status: ${deploy_status}\n" >> "${f}"
  done
}

pushd "${ek_dir}"

clear_status

if [ -f "${marker_filename}" ]; then
  echo "SE already deployed (marker file detected)"
  set_status "deployed"
  exit 0
fi

# get the IP and insert it into inventory
IP=$(ip route get 8.8.8.8 | awk '{print $7}')
export IP
envsubst < inventory.yml.tpl > inventory.yml

export NO_PROXY="$NO_PROXY,$IP"
export no_proxy="$NO_PROXY"

set_status "in progress"
/root/.local/bin/pipenv install

set +e
/root/.local/bin/pipenv run ./deploy.py
status=$?
set -e

clear_status
if [ $status -eq 0 ]; then
  echo "SE deployed successfuly - creating marker"
  set_status "deployed"
  touch "${marker_filename}"
else
  set_status "failed. Check logs in ${ek_dir}/logs. To restart deployment run: systemctl restart seo"
fi

exit ${status}
