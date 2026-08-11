module boson::bootloader;

import uefi;
import boson @public;

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
