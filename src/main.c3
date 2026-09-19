module boson;

import uefi;
import photon;
import elf;

const WString KERNEL_FILENAME = (WString)$$wstr16("\\EFI\\BOOT\\muon.sys");
const usz KERNEL_STACK_SIZE = 4;
const uptr KERNEL_STACK_BASE = 0xffffffff40000000;

fn EfiStatus efi_main(EfiHandle handle, SystemTable* table) @export("efi_main") {
	bootloader::init(table);

	console.clear();
	console.printn("Boson Bootloader for Muon Kernel");
	boson::print_boot_time();
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
	bootloader::prepare_page_table();

	// bootloader payload
	BootloaderPayload* payload = mem.alloc_pages(memory::@pages(BootloaderPayload::size), true);
	if (catch f = mem.map(kernelRootPage, payload, (uptr)payload, memory::@pages(BootloaderPayload::size))) {
		console.printn("Could not prepare bootloade payload, reason %s", f.description);
		return EfiStatus.LOAD_ERROR;
	}

	// check elf header
	bool? elfResult = elf::check_header(kernelBuf, BitMode.BIT64, Arch.X86_64, Endianess.LITTLE_ENDIAN);
	if (catch f = elfResult) {
		console.printn("Could not read kernel file header, reason %s", f.description);
		return EfiStatus.UNSUPPORTED;
	} else {
		if (!elfResult) {
			console.printn("Kernel file is not a valid ELF file");
			return EfiStatus.UNSUPPORTED;
		}
	}

	// get kernel entry point
	uptr? entryPointResult = elf::get_entry_point(kernelBuf);
	if (catch f = entryPointResult) {
		console.printn("Could not read kernel entry point, reason %s", f.description);
		return EfiStatus.UNSUPPORTED;
	}
	kernelEntryPoint = entryPointResult;
	console.printn("Kernel entry point is at %x", kernelEntryPoint);

	console.pause();

	// map kernel programs to hh
	if (catch f = bootloader::load_programs(kernelBuf)) {
		console.printn("Could not load kernel programs, reason %s", f.description);
		return EfiStatus.LOAD_ERROR;
	}

	// alloc+map stack
	if (catch f = bootloader::prepare_stack(KERNEL_STACK_SIZE, KERNEL_STACK_BASE)) {
		console.printn("Could not allocate kernel stack, reason %s", f.description);
		return EfiStatus.LOAD_ERROR;
	}
	payload.stack = {
		.size = (uint)kernelStackSize,
		.base = kernelStackBase,
		.end = kernelStackBase + kernelStackSize,
	};

	// map low 2mb
	if (catch f = mem.map(kernelRootPage, (void*)0x0, 0x0, 1, true)) {
		console.printn("Could not map lower 2MB, reason %s", f.description);
		return EfiStatus.LOAD_ERROR;
	}

	// get acpi table addr
	foreach (ConfigurationTable tb : table.configurationTable[:table.numberOfTableEntries]) {
		if (guid::@compare(tb.vendorGuid, guid::ACPI_20_TABLE)) {
			console.printn("Found ACPI 2.0 table @ %x", tb.vendorTable);
			payload.rsdpAddr = (uptr)tb.vendorTable;
		}
	}

	// get memory map
	// bootstrap kernel

	console.printn("Press any key to shut down");
	console.pause();

	console.printn("Shutting down...");
	shutdown();

	return EfiStatus.SUCCESS;
}
