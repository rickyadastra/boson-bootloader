module elf;

faultdef NO_BUFFER;

fn bool? check_header(void* buffer, BitMode mode, Arch arch, Endianess endianess) {
	if (buffer == null) return NO_BUFFER~;

	Elf64Header* header = (Elf64Header*)buffer;

	return header.magic == ELF_MAGIC &&
		header.mode == mode &&
		header.endianess == endianess &&
		header.arch == arch;
}

fn uptr? get_entry_point(void* buffer) {
	if (buffer == null) return NO_BUFFER~;
	return ((Elf64Header*)buffer).entryPoint;
}
