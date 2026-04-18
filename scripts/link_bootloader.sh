#!/bin/bash
set -e

TARGET_NAME="boson.efi"

BUILD_DIR="$(dirname $(pwd))/build"
TARGET="$BUILD_DIR/$TARGET_NAME"
OBJS="$BUILD_DIR/obj/windows-x64/*.obj"

lld-link /entry:efi_main /subsystem:efi_application /out:$TARGET $OBJS
rm $BUILD_DIR/boson.lib # lib file is not needed 
