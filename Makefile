C3C 			:= c3c
C3C_FLAGS 		:= --trust=full --warn-builtin=no
C3C_MIN_VER := 0.8.4
C3C_VERSION := $(shell $(C3C) --version | awk '/C3 Compiler Version/ {print $$4}')

BOOTLOADER_NAME := boson.efi
BUILD_DIR		:= build
BUILD_TARGET	:= $(BUILD_DIR)/$(BOOTLOADER_NAME)
FAT_IMG			:= $(BUILD_DIR)/fat.img
OVMF_PATH		:= /usr/share/ovmf/OVMF.fd

QEMU			:= qemu-system-x86_64
QEMU_OPTIONS	:= -bios $(OVMF_PATH) \
				   -net none \
				   -m 1G \
				   -enable-kvm \
				   -cpu host \
				   -serial stdio

.PHONY: build $(BUILD_TARGET) image run clear

build: $(BUILD_TARGET)
image: $(FAT_IMG)

$(BUILD_TARGET): check-ver
	@$(C3C) build $(C3C_FLAGS)

$(FAT_IMG): $(BUILD_TARGET)
	@dd if=/dev/zero of=$@ bs=1k count=1440
	@mformat -i $@ -f 1440 ::
	@mmd -i $@ ::/EFI
	@mmd -i $@ ::/EFI/BOOT
	@mcopy -i $@ $< ::/EFI/BOOT/BOOTX64.EFI

run: $(FAT_IMG)
	@$(QEMU) -drive file=$^,format=raw $(QEMU_OPTIONS)

clear:
	@$(C3C) clean
	@rm -rf ./build

check-ver:
	@RES=$$( { echo "$(C3C_VERSION)"; echo "$(C3C_MIN_VER)"; } | sort -V | head -n1 ); \
	if [ "$$RES" != "$(C3C_MIN_VER)" ]; then \
		echo "\nCurrent C3 Compiler version is $(C3C_VERSION), but at least version $(C3C_MIN_VER) is required.\nPlease update c3c (https://c3-lang.org/getting-started/prebuilt-binaries/) and retry.\n"; \
		exit 1; \
	fi \
