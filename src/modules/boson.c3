module boson;

import uefi;

SystemTable* _table @private;
Console console;
MemoryManager mem;

uptr kernelEntryPoint;
PageTable* kernelRootPage;

macro @zero_pad(#v) @local => (#v <= 9) ? "0" : "";

macro print_boot_time() {
	Time time;
	@catch(_table.runtimeServices.get_time(&time, null));

	console.printn("%d-%s%d-%s%d %s%d:%s%d:%s%d UTC",
		time.year,
		@zero_pad(time.month),
		time.month,
		@zero_pad(time.day),
		time.day,
		@zero_pad(time.hour),
		time.hour,
		@zero_pad(time.minute),
		time.minute,
		@zero_pad(time.second),
		time.second
	);
}

// Error handling macros
macro @catch(#func) @builtin {
	if (catch f = efi_error(#func)) @throw(f);
}

macro @expect(#func, #f; @body()) @builtin {
	if (catch fa = efi_error(#func)) {
		if (fa == #f) {
			@body();
		} else {
			bootloader::log_and_panic(fa.description, $$FILE, $$FUNC, $$LINE);
		}
	}
}

macro @throw(#f) @builtin {
	bootloader::log_and_panic(#f.description, $$FILE, $$FUNC, $$LINE);
}

// Allocation macros
macro alloc(usz size) => mem.alloc(size);
macro alloct($Type) => ($Type*)mem.alloc($Type::size);
