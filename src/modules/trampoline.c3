module boson::bootloader;

fn void start_kernel(uptr stack, uptr pml4, uptr entry, BootloaderPayload* payload) 
@naked @nostrip @noreturn @noinline @section(".tramp") {
	// stack: rcx, pml4: rdx, entry: r8, payload: r9
	asm {
		movq $rsp, $rcx;
		movq $rbp, $rcx;
		movq $cr3, $rdx;
	}
	asm("cli");
	asm {
		movq $rdi, $r9;
		subq $rsp, 8;
		pushq $r8;
	}
	asm("retq");
	asm("hlt");
}

const char TRAMP_END @section(".tramp$z") = 0;
