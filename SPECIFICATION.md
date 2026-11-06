<p align="center">
  <img alt="Photon Boot Protocol Logo" src="assets/logo.png" width=720/>
</p>

The **Boson Boot Protocol** is a UEFI x86-64 boot specification designed to be simple, minimal and robust. 
Specifically made for the [**Boson Bootloader**](../README.md) and the [**Muon Kernel**](https://github.com/rickyadastra/muon-kernel).

The official specification for the Boson Boot Protocol is written in C3 and it's implicitly backward-compatible with C and C++.

# Protocol Architecture
The Boson Boot Protocol generates a single contiguous memory region called **Boot Information Block**, or BIB for short. 
The kernel should read all the information needed and mark the BIB region as usable memory as soon as possible to reclaim it.

### Boot Information Block (BIB)
```c3
struct BootInfoBlock {
    ulong magic;
    uint revision;
    uint _reserved;
    usz totalSize;
    usz flags;
    TagHeader* tags;
}
```

Each member of the Boot Information Block is defined as follows:
- `magic` – A constant value to identify the BIB header. It should always be `0xB125208036991188`
- `revision` – The current protocol revision. 
- `_reserved` – Reserved for future expansions, must be 0.
- `totalSize` – Total size of the BIB in bytes, including the header and the tags. Minimum is 40 bytes (BIB header + Terminator tag)
- `flags` – Control bits for future behaviour. Bit 0 is reserved and must be 0.
- `tags` – Start of BIB tags, contiguous allocated array of heterogeneous structures.

**Protocol Revision**: `(major << 24) | minor`
- **Major (8 bit)**: Architectural change (1.x → 2.0 breaks compatibility)
- **Minor (16 bit)**: New optional tags (1.0 → 1.1 is compatible)

### Tag Header Structure
Information is passed from the bootloader to the kernel via a Tag structure.
Each tag starts with a common header.
The following section describes essential tag definitions that should be present in every BIB.

```c3
struct TagHeader {
    uint id;
    uint size;
}
```

- `id` – The tag identifier.
- `size` – The tag size including the header. Minimum is 8 bytes.

Specific tag data follows immediately after the header.
Note that during parsing the next tag will be located at offset `size` from current.

## Essential Tag Definitions

### Terminator Tag

**Identifier**: `0x00000000`   
**Purpose**: Marker for end of tag array. MANDATORY as the final tag.

The kernel terminates tag iteration on encountering `id == 0x00000000`

```c3
struct TagTerminator {
    inline TagHeader header;
}
```

### Memory Map Tag 

**Identifier**: `0x00001000`  
**Purpose**: Describes available physical memory layout to the kernel.  

At least one `AVAILABLE` entry must be present. No overlapping ranges between entries. BIB memory is marked as `BOOTLOADER`. Kernel memory is marked as `KERNEL`. `totalBytes` is the total number of bytes from the UEFI memory map.

```c3
enum MemoryType : uint {
	BOOTLOADER,
	AVAILABLE,
	FIRMWARE,
	ACPI,
	MMIO,
	RESERVED,
	KERNEL,
}

struct MemoryEntry {
	uptr base;
	uptr baseVirt;
	usz length;
	uint _reserved;
	MemoryType type;
}

struct TagMemoryMap {
	inline TagHeader header;
	uint numOfEntries;
	uint _reserved;
	ulong totalBytes;
	MemoryEntry[*] entries;
}
```

### Stack Tag 

**Identifier**: `0x00001001`  
**Purpose**: Describes the stack assigned to the kernel by the bootloader.   

Kernel uses `base`, `size` and `end` fields to know about stack's attributes. Kernel is free to ignore this tag and configure its own stack instead. All fields are in bytes.

```c3
struct TagStack {
	inline TagHeader header;
	void* base;
	void* end;
	usz len;
}
```

### RSDP Tag 

**Identifier**: `0x00001002`  
**Purpose**: Address of ACPI Root System Description Pointer table.

The `rsdp` field contains the RSDP address. Kernel uses it to access and parse the ACPI Root System Description Table according to the ACPI specification.

```c3
struct TagRsdp {
	inline TagHeader header;
	void* rsdp;
}
```

### Framebuffer Tag

**Identifier**: *TBD*  
**Purpose**: Describes video framebuffer configured by bootloader.

*TBD*

### Boot Time Tag 

**Identifier**: *TBD*  
**Purpose**: Captures UEFI clock state at boot time.

*TBD*

### Modules Tag 

**Identifier**: *TBD*   
**Purpose**: Describes additional loaded modules (initrd, drivers, etc.)

*TBD*

### Symbols Table Tag

**Identifier**: *TBD*  
**Purpose**: Communicates the kernel binary's symbol table to the kernel.

*TBD*

### Unwind Table Tag

**Identifier**: *TBD*  
**Purpose**: Communicates the kernel binary's DWARF unwind table to the kernel.

*TBD*

### Custom Tag

**Identifier**: `0x00002000` - `0x0000FFFF`  
**Purpose**: Range reserved for custom bootloader/kernel-specific tags.

# Protocol Semantics

The current specification revision is **`1.0`**.

## Machine State at Entry

Once control is transferred to the kernel, the following are to be expected:
- Each program of the binary is loaded at its specified VMA
- The `rip` register is the entry point defined in the ELF binary
- The `rdi` register contains a pointer to the `BootInfoBlock` structure populated by the bootloader
- The `rsp` register is `0xFFFFFFFF40003FF8`
- The `rbp` register is `0xFFFFFFFF40004000`
- All selector registers (`cs`, `ds`, `ss` etc.) are left untouched (UEFI defaults)
- The GDT is in an undefined state
- The IDT is in an undefined state; interrupts are disabled
- Paging is active with a PML4 root page; ELF programs, bootloader payload, trampoline, memory regions map and the lowest 2MB of physical memory are mapped; `cr3` contains the physical address of such page table

