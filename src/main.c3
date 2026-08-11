module boson;

import uefi;
import photon;

const WString KERNEL_FILENAME = (WString)$$wstr16("\\EFI\\BOOT\\muon.sys");

fn EfiStatus efi_main(EfiHandle handle, SystemTable* table) @export("efi_main") {
	bootloader::init(table);

	console.clear();
	console.printn("Boson Bootloader for Muon Kernel - v2");
	console.print_newline();

	ulong* a = alloct(ulong);
	console.printn("Allocated %x", a);
	console.pause();

	LoadedImageProtocol* image;
	FileSystemProtocol* filesystem;
	FileProtocol* root;
	@catch(table.bootServices.handle_protocol(handle, &guid::LOADED_IMAGE_PROTOCOL, (void**)&image));
	@catch(table.bootServices.handle_protocol(image.deviceHandle, &guid::SIMPLE_FILE_SYSTEM_PROTOCOL, (void**)&filesystem));
	@catch(filesystem.open_volume(&root));

	// load kernel file

	usz size;

	FileProtocol* kernelFile;
	root.open(&kernelFile, KERNEL_FILENAME, 0x1, 0);

	@expect(kernelFile.get_info(&guid::FILE_INFO, &size, null), error::BUFFER_TOO_SMALL) {
		console.printn("Allocating %d bytes for file info", size);
		FileInfo* finfo = (FileInfo*)alloc(size);
		@catch(kernelFile.get_info(&guid::FILE_INFO, &size, finfo));
		console.print("file info size: %d bytes, filename: \"", finfo.fileSize);
		console.wprint((EfiString)&finfo.filename);
		console.printn("\"");
	};

	console.pause();

	console.printn("Press any key to shut down");
	console.pause();

	console.printn("Shutting down...");
	shutdown();

	return EfiStatus.SUCCESS;
}
