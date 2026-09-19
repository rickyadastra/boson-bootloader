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
