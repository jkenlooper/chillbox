#!/usr/bin/env sh

set -o errexit

#current_user="$(id -u -n)"
#test "$current_user" = "root" || (echo "ERROR $0: Must be root." && exit 1)

chillbox_cache="${XDG_CACHE_HOME:-"$HOME/.cache"}/chillbox/"
mkdir -p "$chillbox_cache"

# UPKEEP due: "2023-03-22" label: "QEMU machine emulator" interval: "+6 months"
# https://www.qemu.org/download/
qemu_tar_xz="https://download.qemu.org/qemu-7.1.0.tar.xz"

qemu_tar_xz_file="$(basename "$qemu_tar_xz")"
cached_qemu_tar_xz_file="$chillbox_cache/$qemu_tar_xz_file"

has_qemu_x86_64="$(command -v qemu-system-x86_64 || printf "")"
if [ -z "$has_qemu_x86_64" ]; then
  if [ ! -e "$cached_qemu_tar_xz_file" ]; then
    wget -O "$cached_qemu_tar_xz_file" "$qemu_tar_xz"
  fi

  tmp_qemu="$(mktemp -d)"
  tar x --xz --strip-components=1 -C "$tmp_qemu" -f "$qemu_tar_xz"

  (
  cd "$tmp_qemu"
  # https://wiki.qemu.org/Hosts/Linux
  # sudo apt-get install git libglib2.0-dev libfdt-dev libpixman-1-dev zlib1g-dev ninja-build
  # Only care about configuring for installation of qemu-system-x86_64 by using
  # the softmmu.
  ./configure --target-list=x86_64-softmmu
  make
  make install
  )
fi

# UPKEEP due: "2023-04-21" label: "Alpine Linux custom image" interval: "+3 months"
# Create this file by following instructions at jkenlooper/alpine-droplet
alpine_custom_image="https://github.com/jkenlooper/alpine-droplet/releases/download/alpine-virt-image-2023-01-21-2310/alpine-virt-image-2023-01-21-2310.qcow2.bz2"
alpine_custom_image_checksum="6a70d976cc9d140c0c3f3a2f0bbe8307aa94786b2771f8cf68954e9810b6444b56b917cfc8b5aa7f6341934c2a17792c2d1093455690acc94f1e7bb2e86509b0"


alpine_custom_image_file="$(basename "$alpine_custom_image")"
cached_alpine_custom_image_file="$chillbox_cache/$alpine_custom_image_file"
image_dir="$(dirname "$cached_alpine_custom_image_file")"
image_file="$(basename "$cached_alpine_custom_image_file" ".bz2")"

if [ ! -e "$image_dir/$image_file" ]; then
  wget -O "$cached_alpine_custom_image_file" "$alpine_custom_image"
  sha512sum "$cached_alpine_custom_image_file"
  echo "$alpine_custom_image_checksum  $cached_alpine_custom_image_file" | sha512sum --strict -c \
  || (
    echo "Cleaning up in case errexit is not set." \
    && mv --force --verbose "$cached_alpine_custom_image_file" "$cached_alpine_custom_image_file.INVALID" \
    && exit 1
    )
  bunzip2 "$cached_alpine_custom_image_file"
fi


qemu-system-x86_64 \
  -machine type=q35,accel=tcg \
  -smp 4 \
  -hda "$image_dir/$image_file" \
  -m 8G \
  -vga virtio \
  -usb \
  -device usb-tablet \
  -display default,show-cursor=on \
  -daemonize \
  -net user,hostfwd=tcp::10022-:22 \
  -net nic

sleep 30

ssh root@localhost -p10022

