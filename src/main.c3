module boson;

import uefi;
import elf;

const usz MAX_MEMORY_ENTRIES = 0x1000 / MemoryEntry::size;						// 128 entries
const WString KERNEL_FILENAME = (WString)$$wstr16("\\EFI\\BOOT\\muon.sys");
const usz KERNEL_STACK_SIZE = 4;
const uptr KERNEL_STACK_BASE = 0xffffffff40000000;

fn EfiStatus efi_main(EfiHandle handle, SystemTable* table) @export("efi_main") {
	bootloader::init(table);

	Time bootTime;
	@catch(table.runtimeServices.get_time(&bootTime, null));

	console.clear();
	console.printn("Boson Bootloader for Muon Kernel");
	boson::@print_time(bootTime);
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

	@catch(root.open(&kernelFile, KERNEL_FILENAME, FileOpenMode.READ, 0));
	kernelInfo = file::get_info(kernelFile);
	console.printn("Kernel file found, size is %d bytes", kernelInfo.fileSize);

	// load modules from modules/ directory, skip if directory is  missing
	modules::load_modules(root);

	// load kernel into memory
	void* kernelBuf = file::load(kernelFile, kernelInfo);
	bootloader::prepare_page_table();

	const usz BIB_SIZE = 1; // pages
	BibBuilder builder = protocol::builder::init((uptr)mem.alloc_pages(BIB_SIZE, true), BIB_SIZE*memory::PAGE_SIZE);
	if (catch f = mem.map(kernelRootPage, builder.bib, (uptr)builder.bib, BIB_SIZE)) {
		console.printn("Could not map boot info block into memory, reason %s", f.description);
		return EfiStatus.LOAD_ERROR;
	}

	builder.@append(tag::boot_time(boson::@time_to_epoch(bootTime)));

	if (catch f = mem.imap(
		kernelRootPage, (void*)&bootloader::start_kernel, memory::@pages((uptr)&bootloader::TRAMP_END - (uptr)&bootloader::start_kernel)
	)) {
		console.printn("Could not map kernel trampoline, reason %s", f.description);
		return EfiStatus.LOAD_ERROR;
	}

	console.printn("Kernel trampoline mapped @ %x", &bootloader::start_kernel);

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

	builder.@append(tag::stack((void*)kernelStackBase, kernelStackSize));

	// map low 2mb
	if (catch f = mem.map(kernelRootPage, (void*)0x0, 0x0, 1, true)) {
		console.printn("Could not map lower 2MB, reason %s", f.description);
		return EfiStatus.LOAD_ERROR;
	}

	// get acpi table addr
	foreach (ConfigurationTable tb : table.configurationTable[:table.numberOfTableEntries]) {
		if (guid::@compare(tb.vendorGuid, guid::ACPI_20_TABLE)) {
			console.printn("Found ACPI 2.0 table @ %x", tb.vendorTable);
			builder.@append(tag::rsdp(tb.vendorTable));
		}
	}

	// get memory map
	usz descSz, size, usable, unusable;
	if (catch f = bootloader::@get_memory_map(usable, unusable)) {
		console.printn("Error while creating memory entries map");
	}

	if (catch builder.@append_memory_map(
			tag::memory_map(boson::memoryEntriesCount, usable+unusable), 
			boson::memoryEntries.[:boson::memoryEntriesCount])
		) {
		console.printn("Error while populating boot info block memory entries");
		return EfiStatus.LOAD_ERROR;
	}

	$if $feat(DEBUG):
		foreach (usz i, MemoryEntry me : boson::memoryEntries) {
			if (i >= boson::memoryEntriesCount) break;
			console.printn("%d: %s %x:%x", i, me.type.description, me.base, me.base+me.length-1);
		}
	$endif

	console.printn("Usable memory: %d KB. Total memory: %d KB.", usable/1024, (usable+unusable)/1024);

	BootInfoBlock*? bib = builder.complete();
	if (catch f = bib) {
		console.printn("Could not finalize boot info block, reason %s", f.description);
		return EfiStatus.LOAD_ERROR;
	}
	
	$if $feat(DEBUG):
		console.printn("Printing complete boot info block structure...");
		bib.@foreach_tag(; i, tag) {
			console.printn("tag[%d] found: id=%x, size=%d", i, tag.id, tag.size);

			if (tag.id == MEMORY_MAP) {
				TagMemoryMap* mm = ((TagMemoryMap*)tag);
				foreach (sz j, MemoryEntry entry : mm.entries[:mm.numOfEntries]) {
					console.printn("\t%d: %s, size=%x, length=%x", j, entry.type.description, entry.base, entry.length);
				}
			}
		};
	$endif

	// bootstrap kernel
	ulong key, tmp;
	@expect(table.bootServices.get_memory_map(&tmp, null, &key, null, null), error::BUFFER_TOO_SMALL) {
		@catch(table.bootServices.exit_boot_services(handle, key));
		bootloader::start_kernel(
			boson::kernelStackBase + boson::kernelStackSize, 
			(uptr)boson::kernelRootPage, 
			boson::kernelEntryPoint, 
			bib
		);
	};

	return EfiStatus.SUCCESS;
}
