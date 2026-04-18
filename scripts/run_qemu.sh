#!/bin/bash
set -e

FATIMG_NAME="fat.img"
OVMF_PATH="/usr/share/ovmf/OVMF.fd"

BUILD_DIR="$(dirname $(pwd))/build"
FATIMG="$BUILD_DIR/$FATIMG_NAME"

OPTIONS="-net none \
         -m 1G \
         -enable-kvm \
         -cpu host \
         -serial stdio"

qemu-system-x86_64 -bios $OVMF_PATH -drive file=$FATIMG,format=raw $OPTIONS
