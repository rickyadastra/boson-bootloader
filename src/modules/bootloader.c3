module boson::bootloader;

import uefi;
import boson @public;
import elf;
import lang;

fn void log_and_panic(String reason, String file = "", String func = "", int line = 0) {
	boson::console.panic(reason, file, func, line);
	boson::panic();
}

alias PanicFn = fn void(String message, String file, String function, int line);
PanicFn panicfn = &log_and_panic;

fn void init(SystemTable* table) {
	boson::_table = table;
	boson::console = console::init(table);
	boson::mem = memory::init(table);

	// init memory regions array
	boson::memoryRegions = boson::mem.alloc_pages(1);
}

macro void prepare_page_table() {
	boson::kernelRootPage = (PageTable*)boson::mem.alloc_pages(1, true);

	// self map table to 510
	boson::kernelRootPage.[510] = { .addr = ((uptr)boson::kernelRootPage) >> 12, .writable = true, .present = true };
}

fn void? load_programs(void* buffer) {
	if (buffer == null) $$unreachable();

	Elf64Header* header = (Elf64Header*)buffer;
	Elf64ProgramHeader[] programs = header.get_programs();

	foreach (idx, Elf64ProgramHeader* &program : programs) {
		if (program.type != LOAD) continue;

		// copy from binary to memory
		usz pages = memory::@pages(program.memSize);
		void* paddr = boson::mem.alloc_pages(pages);
		lang::memcpy(paddr, ((char*)buffer + program.fileOffset), program.fileSize);

		// zero fill if needed
		usz zeroSz = program.memSize - program.fileSize;
		if (zeroSz > 0) lang::memset((char*)paddr + program.fileSize, 0, zeroSz);
		
		// TODO: create memory map region
		boson::add_memory_region((uptr)paddr, program.vaddr, pages, KERNEL);

		// map vmem
		boson::mem.map(boson::kernelRootPage, paddr, program.vaddr, pages)!;
	}
}

fn void? prepare_stack(usz pages, uptr vaddr) {
	void* paddr = boson::mem.alloc_pages(pages, true);
	
	boson::mem.map(boson::kernelRootPage, paddr, vaddr, pages)!;
	boson::add_memory_region((uptr)paddr, vaddr, pages, KERNEL);

	boson::kernelStackBase = vaddr;
	boson::kernelStackSize = pages * memory::PAGE_SIZE;
}

macro MemoryDescriptor*? @get_memory_map(usz #usable, usz #unusable) {
	ulong mapKey, descSz, size;
	uint ver;
	MemoryDescriptor* map = null;

	EfiStatus status = boson::_table.bootServices.get_memory_map(&size, null, &mapKey, &descSz, &ver);
	if (status == BUFFER_TOO_SMALL) {
		boson::console.printn("buffer too small, required %d bytes, requesting %d (desc size %d)", 
			size, size + 2*descSz, descSz);
		map = (MemoryDescriptor*)boson::mem.alloc(size + 2*descSz);
		((char*)map)[:(size + 2*descSz)] = 0;
	} else {
		return error::LOAD_ERROR~;
	}

	status = boson::_table.bootServices.get_memory_map(&size, map, &mapKey, &descSz, &ver);
	if (efi_error(status)!) return error::LOAD_ERROR~;
	
	boson::memoryMapKey = mapKey;

	MemoryRegionType lastType = RESERVED;
	uptr base = -1;
	uptr lastBase = -1;
	usz length;
	
	foreach (usz i, MemoryDescriptor desc : map[:(size/descSz)]) {
		boson::console.printn("[%d]: %s @ %x:%x -> %x (%d pages)", i, 
			desc.type.description, desc.physicalStart, desc.physicalStart+(desc.numberOfPages*memory::PAGE_SIZE)-1,
			desc.virtualStart, desc.numberOfPages);

		if (desc.type == ACPI_RECLAIM) {
			boson::mem.map(boson::kernelRootPage, (void*)desc.physicalStart, desc.virtualStart, desc.numberOfPages)!;
		}

		// can't add to payload memory regions if full
		if (boson::memoryRegionSize >= boson::MAX_MEMORY_REGIONS) continue;

		MemoryRegionType type;
		switch (desc.type) {
			case LOADER_DATA:
				type = BOOTLOADER;
				#usable += desc.numberOfPages;
			case LOADER_CODE:
			case BOOT_SERVICES_CODE:
			case CONVENTIONAL:
			case BOOT_SERVICES_DATA:
				type = AVAILABLE;
				#usable += desc.numberOfPages;
			case RUNTIME_SERVICES_CODE:
			case RUNTIME_SERVICES_DATA:
				type = FIRMWARE;
				#unusable += desc.numberOfPages;
			case ACPI_RECLAIM:
			case ACPI_NVS:
				type = ACPI;
				#unusable += desc.numberOfPages;
			case MEMORY_MAPPED_IO:
			case MEMORY_MAPPED_IO_PORT_SPACE:
				type = MMIO;
				#unusable += desc.numberOfPages;
			case UNUSABLE:
			case PAL_CODE:
			case RESERVED:
			default:
				type = RESERVED;
				#unusable += desc.numberOfPages;
		}

		if (lastType == type && base + length == desc.physicalStart) {
			length += desc.numberOfPages * memory::PAGE_SIZE;
		} else {
			if (base != -1) boson::add_memory_region(base, 0, length, lastType);

			lastBase = base;
			base = desc.physicalStart;
			lastType = type;
			length = desc.numberOfPages * memory::PAGE_SIZE;
		}
	}

	if (lastBase != base) boson::add_memory_region(base, 0, length, lastType);

	#usable *= memory::PAGE_SIZE;
	#unusable *= memory::PAGE_SIZE;

	return map;
}
