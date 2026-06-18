C3C 			:= /mnt/e/OSDev/c3c/build/c3c
FLAGS 			:= --trust=full --warn-builtin=no
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

$(BUILD_TARGET):
	@$(C3C) build $(FLAGS)

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
