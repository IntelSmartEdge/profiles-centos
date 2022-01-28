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

start=$(date +%s)
export start

PROVISION_LOG="/tmp/provisioning.log"
run "Begin provisioning process..." \
    "echo \"Begin provisioning process with following params: \$(cat /proc/cmdline)\" && \
    while (! docker ps > /dev/null ); do sleep 0.5; done" \
    "${PROVISION_LOG}"

PROVISIONER=$1

# --- Get kernel parameters ---
kernel_params=$(cat /proc/cmdline)

if [[ $kernel_params == *"ntp_server"* ]]; then
    tmp="${kernel_params##*ntp_server=}"
    export param_ntp="${tmp%% *}"
else
    export param_ntp="us.pool.ntp.org"
fi

run "Trying to sync time with ${param_ntp}..." \
    "ntpd -d -N -q -n -p ${param_ntp} || true" \
    "${PROVISION_LOG}"

if [[ $kernel_params == *"proxy="* ]]; then
    tmp="${kernel_params##*proxy=}"
    export param_proxy="${tmp%% *}"

    export http_proxy=${param_proxy}
    export https_proxy=${param_proxy}
    export no_proxy="localhost,127.0.0.1,${PROVISIONER}"
    export HTTP_PROXY=${param_proxy}
    export HTTPS_PROXY=${param_proxy}
    export NO_PROXY="localhost,127.0.0.1,${PROVISIONER}"
    export DOCKER_PROXY_ENV="--env http_proxy='${http_proxy}' --env https_proxy='${https_proxy}' --env no_proxy='${no_proxy}' --env HTTP_PROXY='${HTTP_PROXY}' --env HTTPS_PROXY='${HTTPS_PROXY}' --env NO_PROXY='${NO_PROXY}'"
elif nc -vz -w 2 "${PROVISIONER}" 3128 && nc -vz -w 2 "${PROVISIONER}" 4128; then
    PROXY_DOCKER_BIND="-v /tmp/ssl:/etc/ssl/ -v /usr/local/share/ca-certificates/EB.pem:/etc/pki/ca-trust/source/anchors/EB.pem"
    export http_proxy=http://${PROVISIONER}:3128/
    export https_proxy=http://${PROVISIONER}:4128/
    export no_proxy="localhost,127.0.0.1,${PROVISIONER}"
    export HTTP_PROXY=http://${PROVISIONER}:3128/
    export HTTPS_PROXY=http://${PROVISIONER}:4128/
    export NO_PROXY="localhost,127.0.0.1,${PROVISIONER}"
    export DOCKER_PROXY_ENV="--env http_proxy='${http_proxy}' --env https_proxy='${https_proxy}' --env no_proxy='${no_proxy}' --env HTTP_PROXY='${HTTP_PROXY}' --env HTTPS_PROXY='${HTTPS_PROXY}' --env NO_PROXY='${NO_PROXY}' ${PROXY_DOCKER_BIND}"
    wget -O - "http://${PROVISIONER}/squid-cert/CA.pem" > /usr/local/share/ca-certificates/EB.pem
    update-ca-certificates
elif nc -vz -w 2 "${PROVISIONER}" 3128; then
    export http_proxy=http://${PROVISIONER}:3128/
    export https_proxy=http://${PROVISIONER}:3128/
    export no_proxy="localhost,127.0.0.1,${PROVISIONER}"
    export HTTP_PROXY=http://${PROVISIONER}:3128/
    export HTTPS_PROXY=http://${PROVISIONER}:3128/
    export NO_PROXY="localhost,127.0.0.1,${PROVISIONER}"
    export DOCKER_PROXY_ENV="--env http_proxy='${http_proxy}' --env https_proxy='${https_proxy}' --env no_proxy='${no_proxy}' --env HTTP_PROXY='${HTTP_PROXY}' --env HTTPS_PROXY='${HTTPS_PROXY}' --env NO_PROXY='${NO_PROXY}'"
fi

if [[ $kernel_params == *"proxysocks="* ]]; then
    tmp="${kernel_params##*proxysocks=}"
    param_proxysocks="${tmp%% *}"

    export FTP_PROXY=${param_proxysocks}

    tmp_socks=$(echo "${param_proxysocks}" | sed "s#http://##g" | sed "s#https://##g" | sed "s#/##g")
    export SSH_PROXY_CMD="-o ProxyCommand='nc -x ${tmp_socks} %h %p'"
fi

if [[ $kernel_params == *"wifissid="* ]]; then
    tmp="${kernel_params##*wifissid=}"
    export param_wifissid="${tmp%% *}"
elif [ -n "${SSID}" ]; then
    export param_wifissid="${SSID}"
fi

if [[ $kernel_params == *"wifipsk="* ]]; then
    tmp="${kernel_params##*wifipsk=}"
    export param_wifipsk="${tmp%% *}"
elif [ -n "${PSK}" ]; then
    export param_wifipsk="${PSK}"
fi

if [[ $kernel_params == *"network="* ]]; then
    tmp="${kernel_params##*network=}"
    export param_network="${tmp%% *}"
fi

if [[ $kernel_params == *"httppath="* ]]; then
    tmp="${kernel_params##*httppath=}"
    export param_httppath="${tmp%% *}"
fi

if [[ $kernel_params == *"parttype="* ]]; then
    tmp="${kernel_params##*parttype=}"
    export param_parttype="${tmp%% *}"
elif [ -d /sys/firmware/efi ]; then
    export param_parttype="efi"
else
    export param_parttype="msdos"
fi

if [[ $kernel_params == *"bootstrap="* ]]; then
    tmp="${kernel_params##*bootstrap=}"
    export param_bootstrap="${tmp%% *}"
    export param_bootstrapurl=${param_bootstrap//$(basename "$param_bootstrap")/}
fi

if [[ $kernel_params == *"token="* ]]; then
    tmp="${kernel_params##*token=}"
    export param_token="${tmp%% *}"
fi

if [[ $kernel_params == *"kernparam="* ]]; then
    tmp="${kernel_params##*kernparam=}"
    temp_param_kernparam="${tmp%% *}"
    param_kernparam=$(echo "${temp_param_kernparam}" | sed 's/#/ /g' | sed 's/:/=/g')
    export param_kernparam
fi

if [[ $kernel_params == *"centosversion="* ]]; then
    tmp="${kernel_params##*centosversion=}"
    export param_centosversion="${tmp%% *}"
fi

if [[ $kernel_params == *"kernelversion="* ]]; then
    tmp="${kernel_params##*kernelversion=}"
    export param_kernelversion="${tmp%% *}"
else
    export param_kernelversion="kernel"
fi

if [[ $kernel_params == *"username="* ]]; then
    tmp="${kernel_params##*username=}"
    export param_username="${tmp%% *}"
else
    export param_username="sys-admin"
fi

if [[ $kernel_params == *"password="* ]]; then
    tmp="${kernel_params##*password=}"
    export param_password="${tmp%% *}"
else
    export param_password="password"
fi

if [[ $kernel_params == *"bare_os="* ]]; then
    tmp="${kernel_params##*bare_os=}"
    export param_bare_os="${tmp%% *}"
else
    export param_bare_os="false"
fi

if [[ $param_bare_os == "true" ]]; then
    export param_validationmode=true
else 
    export param_validationmode=false
fi

if [[ $kernel_params == *"debug="* ]]; then
    tmp="${kernel_params##*debug=}"
    export param_debug="${tmp%% *}"
    export debug="${tmp%% *}"
fi

if [[ $kernel_params == *"release="* ]]; then
    tmp="${kernel_params##*release=}"
    export param_release="${tmp%% *}"
else
    export param_release='dev'
fi

if [[ $kernel_params == *"docker_login_user="* ]]; then
    tmp="${kernel_params##*docker_login_user=}"
    export param_docker_login_user="${tmp%% *}"
fi

if [[ $kernel_params == *"docker_login_pass="* ]]; then
    tmp="${kernel_params##*docker_login_pass=}"
    export param_docker_login_pass="${tmp%% *}"
fi

if [[ $param_release == 'prod' ]]; then
    export kernel_params="$param_kernparam" # ipv6.disable=1
else
    export kernel_params="$param_kernparam"
fi

# --- Minimal Centos package list
export param_packages=" \
    audit \
    bash \
    deltarpm \
    dnf \
    iputils \
    iproute \
    kbd \
    less \
    lz4 \
    net-tools \
    ncurses \
    passwd \
    policycoreutils \
    rootfiles \
    rtkit \
    sqlite \
    sudo \
    systemd \
    vim-minimal \
    wget \
    xfsprogs \
    yum \
    e2fsprogs \
    btrfs-progs \
    dhclient \
    dnsmasq \
    dracut-network \
    cronie \
    irqbalance \
    rsyslog \
    man-db \
    microcode_ctl \
    parted \
    teamd \
    tuned \
    kernel-tools \
    biosdevname \
    NetworkManager"

# --- Run Partitioner ---
# shellcheck source=create_seo_partitions.sh
source <(wget --header "Authorization: token ${param_token}" -O- "${param_bootstrapurl}/create_seo_partitions.sh")

# --- Get free memory
freemem=$(grep MemTotal /proc/meminfo | awk '{print $2}')
export freemem

# --- check if we need to move tmp folder ---
if [ "$freemem" -lt 6291456 ]; then
    mkdir -p $ROOTFS/tmp
    export TMP=$ROOTFS/tmp
else
    export TMP=/tmp
fi
export PROVISION_LOG="$TMP/provisioning.log"

if wget "http://${PROVISIONER}:5557/v2/_catalog" -O- 2>/dev/null; then
    export REGISTRY_MIRROR="--registry-mirror=http://${PROVISIONER}:5557"
elif wget "http://${PROVISIONER}:5000/v2/_catalog" -O- 2>/dev/null; then
    export REGISTRY_MIRROR="--registry-mirror=http://${PROVISIONER}:5000"
fi

# -- Configure Image database ---
run "Configuring Image Database" \
    "mkdir -p $ROOTFS/tmp/docker && \
    chmod 777 $ROOTFS/tmp && \
    killall dockerd && sleep 2 && \
    /usr/local/bin/dockerd ${REGISTRY_MIRROR} --data-root=$ROOTFS/tmp/docker > /dev/null 2>&1 &" \
    "${PROVISION_LOG}"

while (! docker ps > /dev/null ); do sleep 0.5; done; sleep 3

if [ -n "${param_docker_login_user}" ] && [ -n "${param_docker_login_pass}" ]; then
    run "Log in to a Docker registry" \
        "docker login -u ${param_docker_login_user} -p ${param_docker_login_pass}" \
        "${PROVISION_LOG}"
fi

# --- Begin Centos Install Process ---
run "Preparing Centos ${param_centosversion} installer" \
    "docker pull centos:${param_centosversion}" \
    "${PROVISION_LOG}"

rootfs_partuuid=$(lsblk -no UUID "${ROOT_PARTITION}")
bootfs_partuuid=$(lsblk -no UUID "${BOOT_PARTITION}")

export MOUNT_BEFORE_CHROOT=" \
    mount --bind /dev /target/root/dev && \
    mount -t proc proc /target/root/proc && \
    mount -t sysfs sysfs /target/root/sys"

if [[ $param_parttype == 'efi' ]]; then
    export MOUNT_BOOT_UNDER_CHROOT="chmod a+rw /dev/null /dev/zero && mkdir -p /boot/efi && mount ${BOOT_PARTITION} /boot/efi"

    run "Installing Centos ${param_centosversion} (~10 min)" \
        "docker run -i --rm --privileged --name centos-installer ${DOCKER_PROXY_ENV} --network host -v $ROOTFS:/target/root centos:${param_centosversion} sh -c \
        'echo insecure >> ~/.curlrc && echo 'sslverify=0' >> /etc/yum.conf && \
        yum install -y dnf && \
        echo 'sslverify=0' >> /etc/dnf/dnf.conf && \
        dnf -y --releasever=${param_centosversion} --installroot=/target/root --setopt=install_weak_deps=False --setopt=keepcache=True --nodocs install ${param_packages} && \
        cp /etc/resolv.conf /target/root/etc/resolv.conf && \
        ${MOUNT_BEFORE_CHROOT} && \
        LANG=C.UTF-8 chroot /target/root bash -c \
            \"set -x && export TERM=xterm-color && \
            ${MOUNT_BOOT_UNDER_CHROOT} && \
            echo 'insecure' >> ~/.curlrc && echo 'sslverify=0' >> /etc/yum.conf && echo 'sslverify=0' >> /etc/dnf/dnf.conf && \
            yum install -y grub2-efi grub2-efi-modules grub2-tools shim && \
            yum install -y ${param_kernelversion} linux-firmware && \
            grub2-install ${BOOT_PARTITION} --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=centos --no-nvram && \
            ln -f -s /boot/grub2/grub.cfg /etc/grub2-efi.cfg && \
            rm /boot/grub2/grubenv && \
            mv /boot/efi/EFI/centos/grubenv /boot/grub2/grubenv && \
            adduser --shell /usr/bin/bash ${param_username} && \
            usermod -a -G wheel ${param_username} && \
            echo ${param_username}:${param_password} | chpasswd && \
            yum autoremove -y && \
            yum clean -y packages\"' && \
        wget --header \"Authorization: token ${param_token}\" -O - ${param_bootstrapurl}/files/etc/fstab | sed -e \"s#ROOT#UUID=${rootfs_partuuid}#g\" | sed -e \"s#BOOT#UUID=${bootfs_partuuid}                 /boot/efi       vfat    umask=0077        0       1#g\" > $ROOTFS/etc/fstab" \
        "${PROVISION_LOG}"

    # add EFI boot manager entry, that will jump to grub boot manager, located on boot partition
    EFI_BOOT_NAME="Centos OS"
    run "EFI Boot Manager" \
        "efibootmgr -c -d ${DRIVE} -p 1 -L \"${EFI_BOOT_NAME}\" -l '\\EFI\\centos\\grubx64.efi'" \
        "${PROVISION_LOG}"
else
    export MOUNT_BOOT_UNDER_CHROOT="chmod a+rw /dev/null /dev/zero && mount ${BOOT_PARTITION} /boot"

    run "Installing Centos ${param_centosversion} (~10 min)" \
        "docker run -i --rm --privileged --name centos-installer ${DOCKER_PROXY_ENV} --network host -v $ROOTFS:/target/root centos:${param_centosversion} sh -c \
        'echo 'insecure' >> ~/.curlrc && echo 'sslverify=0' >> /etc/yum.conf && \
        yum install -y dnf && \
        echo 'sslverify=0' >> /etc/dnf/dnf.conf && \
        dnf -y --releasever=${param_centosversion} --installroot=/target/root --setopt=install_weak_deps=False --setopt=keepcache=True --nodocs install ${param_packages} && \
        cp /etc/resolv.conf /target/root/etc/resolv.conf && \
        ${MOUNT_BEFORE_CHROOT} && \
        LANG=C.UTF-8 chroot /target/root bash -c \
            \"set -x && export TERM=xterm-color && \
            ${MOUNT_BOOT_UNDER_CHROOT} && \
            echo 'insecure' >> ~/.curlrc && echo 'sslverify=0' >> /etc/yum.conf && echo 'sslverify=0' >> /etc/dnf/dnf.conf && \
            yum install -y grub2-pc grub2-pc-modules grub2-tools && \
            yum install -y ${param_kernelversion} linux-firmware && \
            grub2-install --boot-directory=/boot ${DRIVE} && \
            adduser --shell /usr/bin/bash ${param_username} && \
            usermod -a -G wheel ${param_username} && \
            echo ${param_username}:${param_password} | chpasswd && \
            yum autoremove -y && \
            yum clean -y packages\"' && \
        wget --header \"Authorization: token ${param_token}\" -O - ${param_bootstrapurl}/files/etc/fstab | sed -e \"s#ROOT#UUID=${rootfs_partuuid}#g\" | sed -e \"s#BOOT#UUID=${bootfs_partuuid}                 /boot           ext4    defaults        0       2#g\" > $ROOTFS/etc/fstab" \
        "${PROVISION_LOG}"
fi

# --- Enabling Centos boostrap items ---
HOSTNAME="centos-$(tr </dev/urandom -dc a-f0-9 | head -c10)"
run "Enabling Centos boostrap items" \
    "wget --header \"Authorization: token ${param_token}\" -O $ROOTFS/etc/systemd/system/show-ip.service ${param_bootstrapurl}/systemd/show-ip.service && \
    mkdir -p $ROOTFS/etc/systemd/system/network-online.target.wants/ && \
    ln -s /etc/systemd/system/show-ip.service $ROOTFS/etc/systemd/system/network-online.target.wants/show-ip.service; \
    wget --header \"Authorization: token ${param_token}\" -O - ${param_bootstrapurl}/files/etc/hosts | sed -e \"s#@@HOSTNAME@@#${HOSTNAME}#g\" > $ROOTFS/etc/hosts && \
    mkdir -p $ROOTFS/etc/systemd/network/ && \
    wget --header \"Authorization: token ${param_token}\" -O - ${param_bootstrapurl}/files/etc/systemd/network/wired.network > $ROOTFS/etc/systemd/network/wired.network && \
    echo 'GRUB_CMDLINE_LINUX=\"kvmgt vfio-iommu-type1 vfio-mdev i915.enable_gvt=1 kvm.ignore_msrs=1 intel_iommu=on drm.debug=0\"' >> $ROOTFS/etc/default/grub && \
    echo 'GRUB_TIMEOUT=5' >> $ROOTFS/etc/default/grub && \
    echo 'GRUB_DEFAULT=saved' >> $ROOTFS/etc/default/grub && \
    echo 'GRUB_DISABLE_SUBMENU=true' >> $ROOTFS/etc/default/grub && \
    echo 'GRUB_DISABLE_RECOVERY=true' >> $ROOTFS/etc/default/grub && \
    echo \"${HOSTNAME}\" > $ROOTFS/etc/hostname && \
    echo \"LANG=en_US.UTF-8\" >> $ROOTFS/etc/default/locale && \
    echo \"install_weak_deps=False\" >> $ROOTFS/etc/dnf/dnf.conf && \
    echo \"keepcache=True\" >> $ROOTFS/etc/dnf/dnf.conf && \
    echo \"tsflags=nodocs\" >> $ROOTFS/etc/dnf/dnf.conf && \
    rm -f /mnt/etc/yum.repos.d/*{*cisco*,*testing*,*modular*}* && \
    docker run -i --rm --privileged --name centos-installer ${DOCKER_PROXY_ENV} --network host -v $ROOTFS:/target/root centos:${param_centosversion} sh -c \
        '${MOUNT_BEFORE_CHROOT} && \
        LANG=C.UTF-8 chroot /target/root bash -c \
            \"set -x && export TERM=xterm-color && \
            ${MOUNT_BOOT_UNDER_CHROOT} && \
            yum install -y lvm2 && \
            dracut --regenerate-all --force --add lvm --lvmconf --mdadmconf && \
            grub2-mkconfig -o /boot/grub2/grub.cfg && \
            yum install -y grubby && \
            grubby --set-default=\\\$(ls /boot/vmlinuz*) && \
            systemd-firstboot --root=/ --locale=en_US.UTF-8 --hostname=${HOSTNAME} --setup-machine-id\"'" \
    "${PROVISION_LOG}"

if [ "${param_network}" == "bridged" ]; then
    run "Installing the bridged network" \
        "mkdir -p $ROOTFS/etc/systemd/network/ && \
        wget --header \"Authorization: token ${param_token}\" -O $ROOTFS/etc/systemd/network/wired.network ${param_bootstrapurl}/files/etc/systemd/network/bridged/wired.network && \
        wget --header \"Authorization: token ${param_token}\" -O $ROOTFS/etc/systemd/network/bond0.netdev ${param_bootstrapurl}/files/etc/systemd/network/bridged/bond0.netdev && \
        wget --header \"Authorization: token ${param_token}\" -O $ROOTFS/etc/systemd/network/bond0.network ${param_bootstrapurl}/files/etc/systemd/network/bridged/bond0.network && \
        wget --header \"Authorization: token ${param_token}\" -O $ROOTFS/etc/systemd/network/br0.netdev ${param_bootstrapurl}/files/etc/systemd/network/bridged/br0.netdev && \
        wget --header \"Authorization: token ${param_token}\" -O $ROOTFS/etc/systemd/network/br0.network ${param_bootstrapurl}/files/etc/systemd/network/bridged/br0.network" \
        "${PROVISION_LOG}"

elif [ "${param_network}" == "network-manager" ]; then
    run "Installing Network Manager Packages on Centos ${param_centosversion}" \
        "docker run -i --rm --privileged --name centos-installer ${DOCKER_PROXY_ENV} --network host -v $ROOTFS:/target/root centos:${param_centosversion} sh -c \
        '${MOUNT_BEFORE_CHROOT} && \
        LANG=C.UTF-8 chroot /target/root bash -c \
            \"set -x && export TERM=xterm-color && \
            yum install -y NetworkManager\"'" \
        "${PROVISION_LOG}"
fi

if [ -d "/sys/class/ieee80211" ] && ( find /sys/class/net/wl* > /dev/null 2>&1 ); then
    if [ -n "${param_wifissid}" ]; then
        WIFI_NAME_ONBOARD=$(udevadm test-builtin net_id /sys/class/net/wl* 2> /dev/null | grep ID_NET_NAME_ONBOARD | awk -F'=' '{print $2}' | head -1)
        WIFI_NAME_PATH=$(udevadm test-builtin net_id /sys/class/net/wl* 2> /dev/null | grep ID_NET_NAME_PATH | awk -F'=' '{print $2}' | head -1)
        if [ -n "${WIFI_NAME_ONBOARD}" ]; then
            WIFI_NAME=${WIFI_NAME_ONBOARD}
        else 
            WIFI_NAME=${WIFI_NAME_PATH}
        fi
        if [ "${param_network}" == "bridged" ]; then
            run "Installing Wifi on Centos ${param_centosversion}" \
                "wget --header \"Authorization: token ${param_token}\" -O $ROOTFS/etc/systemd/network/wireless.network ${param_bootstrapurl}/files/etc/systemd/network/bridged/wireless.network.template && \
                sed -i -e \"s#@@WIFI_NAME@@#${WIFI_NAME}#g\" $ROOTFS/etc/systemd/network/wireless.network && \
                sed -i -e \"s#@@WPA_SSID@@#${param_wifissid}#g\" $ROOTFS/etc/systemd/network/wireless.network && \
                sed -i -e \"s#@@WPA_PSK@@#${param_wifipsk}#g\" $ROOTFS/etc/systemd/network/wireless.network" \
                "${PROVISION_LOG}"
        elif [ "${param_network}" == "network-manager" ]; then
            run "Installing Wifi on Centos ${param_centosversion}" \
                "docker run -i --rm --privileged --name centos-installer ${DOCKER_PROXY_ENV} --network host -v $ROOTFS:/target/root centos:${param_centosversion} sh -c \
                '${MOUNT_BEFORE_CHROOT} && \
                LANG=C.UTF-8 chroot /target/root bash -c \
                    \"set -x && export TERM=xterm-color && \
                    nmcli radio wifi on && \
                    nmcli dev wifi connect ${param_wifissid} password '${param_wifipsk}' || true \"'" \
                "${PROVISION_LOG}"
        else
            run "Installing Wifi on Centos ${param_centosversion}" \
                "wget --header \"Authorization: token ${param_token}\" -O $ROOTFS/etc/systemd/network/wireless.network ${param_bootstrapurl}/files/etc/systemd/network/wireless.network.template && \
                sed -i -e \"s#@@WIFI_NAME@@#${WIFI_NAME}#g\" $ROOTFS/etc/systemd/network/wireless.network && \
                sed -i -e \"s#@@WPA_SSID@@#${param_wifissid}#g\" $ROOTFS/etc/systemd/network/wireless.network && \
                sed -i -e \"s#@@WPA_PSK@@#${param_wifipsk}#g\" $ROOTFS/etc/systemd/network/wireless.network" \
                "${PROVISION_LOG}"
        fi

        run "Installing Wireless Packages on Centos ${param_centosversion}" \
            "docker run -i --rm --privileged --name centos-installer ${DOCKER_PROXY_ENV} --network host -v $ROOTFS:/target/root centos:${param_centosversion} sh -c \
            '${MOUNT_BEFORE_CHROOT} && \
            LANG=C.UTF-8 chroot /target/root bash -c \
                \"set -x && export TERM=xterm-color && \
                ${MOUNT_BOOT_UNDER_CHROOT} && \
                yum install -y wireless-tools wpa_supplicant && \
                mkdir -p /etc/wpa_supplicant && \
                wpa_passphrase ${param_wifissid} '${param_wifipsk}' > /etc/wpa_supplicant/wpa_supplicant-${WIFI_NAME}.conf && \
                systemctl enable wpa_supplicant@${WIFI_NAME}.service\"'" \
            "${PROVISION_LOG}"
    fi
fi

run "Enabling Kernel Modules at boot time" \
    "mkdir -p $ROOTFS/etc/modules-load.d/ && \
    echo 'kvmgt' > $ROOTFS/etc/modules-load.d/kvmgt.conf && \
    echo 'vfio-iommu-type1' > $ROOTFS/etc/modules-load.d/vfio.conf && \
    echo 'dm-crypt' > $ROOTFS/etc/modules-load.d/dm-crypt.conf && \
    echo 'fuse' > $ROOTFS/etc/modules-load.d/fuse.conf && \
    echo 'i915' > $ROOTFS/etc/modules-load.d/i915.conf" \
    "${PROVISION_LOG}"

if [ -f $ROOTFS/etc/skel/.bashrc ]; then
    echo 'force_color_prompt=yes' >> $ROOTFS/etc/skel/.bashrc
fi
if [ -f $ROOTFS/root/.bashrc ]; then
    echo 'force_color_prompt=yes' >> $ROOTFS/root/.bashrc
fi
if [ -f $ROOTFS/home/${param_username}/.bashrc ]; then
    echo 'force_color_prompt=yes' >> $ROOTFS/home/${param_username}/.bashrc
fi

# The proxy will be set up by Experience Kits
if [ -n "${param_proxy}" ]; then
    run "Enabling Proxy Environment Variables" \
        "echo -e '\
        http_proxy=${param_proxy}\n\
        https_proxy=${param_proxy}\n\
        no_proxy=localhost,127.0.0.1' >> $ROOTFS/etc/environment && \
        mkdir -p $ROOTFS/root/ && \
        echo 'source /etc/environment' >> $ROOTFS/root/.bashrc" \
        "${PROVISION_LOG}"
fi

if [ -n "${param_proxysocks}" ]; then
    run "Enabling Socks Proxy Environment Variables" \
        "echo -e 'ftp_proxy=${param_proxysocks}' >> $ROOTFS/etc/environment" \
        "${PROVISION_LOG}"
fi
