#!/bin/bash
set -e

BOOTLOADER_NAME="boson.efi"
TARGET_NAME="fat.img"

BUILD_DIR="$(dirname $(pwd))/build"
TARGET="$BUILD_DIR/$TARGET_NAME"
BOOTLOADER="$BUILD_DIR/$BOOTLOADER_NAME"

dd if=/dev/zero of=$TARGET bs=1k count=1440
mformat -i $TARGET -f 1440 ::
mmd -i $TARGET ::/EFI
mmd -i $TARGET ::/EFI/BOOT
mcopy -i $TARGET $BOOTLOADER ::/EFI/BOOT/BOOTX64.EFI
