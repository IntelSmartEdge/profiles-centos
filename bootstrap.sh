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

# this is provided while using uOS
# shellcheck source=/dev/null
source /opt/bootstrap/functions

param_httpserver=$1

# --- Get kernel parameters ---
kernel_params=$(cat /proc/cmdline)

if [[ $kernel_params == *"token="* ]]; then
    tmp="${kernel_params##*token=}"
    export param_token="${tmp%% *}"
fi

if [[ $kernel_params == *"bootstrap="* ]]; then
    tmp="${kernel_params##*bootstrap=}"
    export param_bootstrap="${tmp%% *}"
    export param_bootstrapurl=${param_bootstrap//$(basename "$param_bootstrap")/}
fi

# shellcheck source=pre.sh
source <(wget --header "Authorization: token ${param_token}" -O - "${param_bootstrapurl}/pre.sh") && \
wget --header "Authorization: token ${param_token}" -O - "${param_bootstrapurl}/profile.sh" | bash -s - "$param_httpserver" && \
wget --header "Authorization: token ${param_token}" -O - "${param_bootstrapurl}/post.sh" | bash -s - "$param_httpserver"
