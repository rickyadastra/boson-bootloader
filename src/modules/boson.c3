module boson;

import uefi;

SystemTable* _table @private;
Console console;
MemoryManager mem;

uptr kernelEntryPoint;
PageTable* kernelRootPage;
uptr kernelStackBase;
usz kernelStackSize;
ulong memoryMapKey;

MemoryEntry[MAX_MEMORY_ENTRIES]* memoryEntries;
usz memoryEntriesCount;

macro @zero_pad(#v) @local => (#v <= 9) ? "0" : "";

macro @print_time(Time #time) {
	console.printn("%d-%s%d-%s%d %s%d:%s%d:%s%d UTC",
		#time.year,
		@zero_pad(#time.month),
		#time.month,
		@zero_pad(#time.day),
		#time.day,
		@zero_pad(#time.hour),
		#time.hour,
		@zero_pad(#time.minute),
		#time.minute,
		@zero_pad(#time.second),
		#time.second
	);
}

macro bool @is_leap_year(#year) => (#year % 4 == 0 && #year % 100 != 0) || (#year % 400 == 0);

macro ulong @time_to_epoch(Time #time) {
	if (#time.year < 1970) return 0;

    ulong totalDays = 0;
	const uint[13] DAYS_IN_MONTH = {0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};

    for (usz y = 1970; y < #time.year; y++) {
        totalDays += @is_leap_year(y) ? 366ul : 365ul;
    }

    for (usz m = 1; m < #time.month; m++) {
        if (m == 2 && @is_leap_year(#time.year)) totalDays += 1;
        totalDays += DAYS_IN_MONTH[m];
    }

    totalDays += #time.day - 1ul;

    ulong totalSeconds = totalDays * 86400ul;
    totalSeconds += #time.hour * 3600ul;
    totalSeconds += #time.minute * 60ul;
    totalSeconds += #time.second;

    return totalSeconds;
}

macro add_memory_entry(uptr base, uptr baseVirt, usz size, protocol::MemoryType type) {
	memoryEntries.[memoryEntriesCount++] = {
		.base = base,
		.baseVirt = baseVirt,
		.length = size,
		.type = type,
	};
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
