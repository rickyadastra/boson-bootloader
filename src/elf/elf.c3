module elf;

fn bool check_header(void* buffer, BitMode mode, Arch arch, Endianess endianess) {
	if (buffer == null) return false;

	Elf64Header* header = (Elf64Header*)buffer;

	return header.magic == ELF_MAGIC &&
		header.mode == mode &&
		header.endianess == endianess &&
		header.arch == arch;
}
