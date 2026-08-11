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

// Hacky stuff to avoid lld-link complaints
uptr __security_cookie @export("__security_cookie") = 0x123456789ABCDEF0;

fn void security_check_cookie(uptr cookie)  @noreturn @export("__security_check_cookie") {
	if (cookie != __security_cookie) {
		bootloader::log_and_panic("Stack smash detected!");
	}
}
