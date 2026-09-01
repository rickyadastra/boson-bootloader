module boson;

import uefi;
import photon;
import elf;

const WString KERNEL_FILENAME = (WString)$$wstr16("\\EFI\\BOOT\\muon.sys");

fn EfiStatus efi_main(EfiHandle handle, SystemTable* table) @export("efi_main") {
	bootloader::init(table);

	console.clear();
	console.printn("Boson Bootloader for Muon Kernel - v2");
	console.print_newline();

	// open volume root
	LoadedImageProtocol* image;
	FileSystemProtocol* filesystem;
	FileProtocol* root;

	@catch(table.bootServices.handle_protocol(handle, &guid::LOADED_IMAGE_PROTOCOL, (void**)&image));
	@catch(table.bootServices.handle_protocol(image.deviceHandle, &guid::SIMPLE_FILE_SYSTEM_PROTOCOL, (void**)&filesystem));
	@catch(filesystem.open_volume(&root));

	// open kernel file
	FileProtocol* kernelFile;
	FileInfo* kernelInfo;

	root.open(&kernelFile, KERNEL_FILENAME, FileOpenMode.READ, 0);
	kernelInfo = file::get_info(kernelFile);
	console.printn("Kernel file found, size is %d bytes", kernelInfo.fileSize);

	// load kernel into memory
	void* kernelBuf = file::load(kernelFile, kernelInfo);
	console.pause();

	// check elf header
	if (!elf::check_header(kernelBuf, BitMode.BIT64, Arch.X86_64, Endianess.LITTLE_ENDIAN)) {
		console.printn("Kernel file is not a valid ELF file");
		return EfiStatus.UNSUPPORTED;
	}

	// get kernel entry point
	// alloc+map stack
	// map low 2mb
	// map apic
	// map kernel programs to hh
	// get acpi table addr
	// get memory map
	// bootstrap kernel


	console.printn("Press any key to shut down");
	console.pause();

	console.printn("Shutting down...");
	shutdown();

	return EfiStatus.SUCCESS;
}
