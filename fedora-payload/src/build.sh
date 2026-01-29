#!/usr/bin/bash
set -exo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

dnf install -qy \
    anaconda \
    anaconda-install-img-deps \
    anaconda-dracut \
    dracut-config-generic \
    dracut-network \
    net-tools \
    grub2-efi-x64-cdboot

# these are necessary build tools, if you have a separate build container
# in `--bootc-build-ref` then these can go there
dnf install -qy \
    xorrisofs \
    squashfs-tools

dnf clean all

mkdir -p /boot/efi \
    && cp -ra /usr/lib/efi/*/*/EFI /boot/efi

# this stuff is normally done by lorax (runtime-postinstall.tmpl), i've distilled
# it down to the bare bones necessary
echo "install:x:0:0:root:/root:/usr/libexec/anaconda/run-anaconda" >> /etc/passwd
echo "install::14438:0:99999:7:::" >> /etc/shadow
passwd -d root

mv /usr/share/anaconda/list-harddrives-stub /usr/bin/list-harddrives
mv /etc/yum.repos.d /etc/anaconda.repos.d
ln -s /lib/systemd/system/anaconda.target /etc/systemd/system/default.target
rm -v /usr/lib/systemd/system-generators/systemd-gpt-auto-generator

rm /usr/lib/systemd/system/autovt@.service
ln -s /usr/lib/systemd/system/anaconda-shell@.service /usr/lib/systemd/system/autovt@.service

mkdir /usr/lib/systemd/logind.conf.d
echo "[Login]\nReserveVT=2" > /usr/lib/systemd/logind.conf.d/anaconda-shell.conf

# regenerate the initramfs including the anaconda module
mkdir "$(realpath /root)"
kernel=$(kernel-install list --json pretty | jq -r '.[] | select(.has_kernel == true) | .version')
DRACUT_NO_XATTR=1 dracut -v --force --zstd --reproducible --no-hostonly \
  --add "anaconda" \
    "/usr/lib/modules/${kernel}/initramfs.img" "${kernel}"

# set the defaults for anaconda, this includes the container that will be
# installed onto the system
cp /src/interactive-defaults.ks /usr/share/anaconda/interactive-defaults.ks

# set the defaults for (bootc-)image-builder
mkdir /usr/lib/bootc-image-builder
cp /src/iso.yaml /usr/lib/bootc-image-builder/iso.yaml
