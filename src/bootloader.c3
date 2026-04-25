module boson;

import uefi;

SystemTable* _table @private;
Console console;
MemoryManager mem;

// Error handling macros
macro @catch(#func) @builtin {
	if (catch f = efi_error(#func)) @throw(f);
}

macro @expect(#func, #f; @body()) @builtin {
	if (catch fa = efi_error(#func)) {
		if (fa == #f) {
			@body();
		} else {
			bootloader::log_and_panic(fa.nameof, $$FILE, $$FUNC, $$LINE);
		}
	}
}

macro @throw(#f) @builtin {
	bootloader::log_and_panic(#f.nameof, $$FILE, $$FUNC, $$LINE);
}

// Allocation macros
macro alloc(usz size) => mem.alloc(size);
macro alloct($Type) => ($Type*)mem.alloc($Type.sizeof);

module boson::bootloader;

import uefi;
import boson @public;

fn void log_and_panic(String reason, String file = "", String func = "", uint line = 0) {
	boson::console.panic(reason, file, func, line);
	boson::panic();
}

alias PanicFn = fn void(String message, String file, String function, uint line);
PanicFn panicfn = &log_and_panic;

fn void init(SystemTable* table) {
	boson::_table = table;
	boson::console = console::init(table);
	boson::mem = memory::init(table);
}

// Hacky stuff to avoid lld-link complaints

uptr __security_cookie @export("__security_cookie") = 0x123456789ABCDEF0;

fn void security_check_cookie(uptr cookie)  @noreturn @export("__security_check_cookie") {
	if (cookie != __security_cookie) {
		log_and_panic("Stack smash detected!");
	}
}
