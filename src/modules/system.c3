module boson;

import uefi::protocol;

macro panic() {
	asm("cli");
	asm("hlt");
}

macro shutdown(ResetType type = SHUTDOWN, EfiStatus status = SUCCESS) 
	=> _table.runtimeServices.reset_system(type, status, 0, null);
