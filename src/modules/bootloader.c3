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

		// map vmem
		boson::mem.map(boson::kernelRootPage, paddr, program.vaddr, pages)!;
	}
}
