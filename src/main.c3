module boson;

import uefi;

fn EfiStatus efi_main(EfiHandle handle, SystemTable* table) @export("efi_main") {
	bootloader::init(table);

	console.clear();
	console.printn("Boson Bootloader v2");
	console.pause();

	return EfiStatus.SUCCESS;
}
