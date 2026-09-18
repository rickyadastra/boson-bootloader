module boson::memory;

import uefi;

faultdef TABLE_IS_NULL;

const usz PAGE_SIZE = 0x1000;

bitstruct PageTableEntry : ulong {
	bool present : 0;
	bool writable : 1;
	bool huge : 7;
	uptr addr : 12..51;
}

typedef PageTable = PageTableEntry[512];
$assert(PageTable::size == PAGE_SIZE);

struct MemoryManager {
	BootServices* bootServices;
}

fn MemoryManager init(SystemTable* table) => {.bootServices = table.bootServices};

fn void* MemoryManager.alloc(&self, usz size, MemoryType memoryType = LOADER_DATA) {
	void* p;
	@catch(self.bootServices.allocate_pool(memoryType, size, &p));
	return p;
}

fn void* MemoryManager.alloc_pages(&self, usz num, bool clear = false, AllocateType allocateType = ANY_PAGES, MemoryType memoryType = LOADER_DATA) {
	void* p;
	@catch(self.bootServices.allocate_pages(allocateType, memoryType, num, &p));

	if (clear) {
		char* c = p;
		c[:num*PAGE_SIZE] = 0;
	}

	return p;
}

macro void MemoryManager.free(&self, void* ptr) => @catch(self.bootServices.free_pool(ptr));
macro void MemoryManager.free_pages(&self, void* ptr, usz num) => @catch(self.bootServices.free_pages(ptr, num));

macro usz @pages(usz #bytes) => (#bytes + (PAGE_SIZE - 1ul)) / PAGE_SIZE;

fn void MemoryManager.vmap_helper(&mem, PageTable* pml4, uptr paddr, uptr vaddr, bool huge = false) {
	paddr = (uptr)paddr & ~((uptr)0xfff);
	vaddr = (uptr)vaddr & ~((uptr)0xfff);

	usz pml4e = (vaddr >> 39) & 0x1ff;
	usz pdpte = (vaddr >> 30) & 0x1ff;
    usz pde = (vaddr >> 21) & 0x1ff;
    usz pte = (vaddr >> 12) & 0x1ff;

	PageTable* curPml4 = pml4;
	PageTable* curPdpt, curPd, curPt;

	if (!curPml4.[pml4e].present) {
		curPdpt = (PageTable*)mem.alloc_pages(1, true);
		curPml4.[pml4e] = { .addr = ((uptr)curPdpt) >> 12, .writable = true, .present = true };
	} else {
		curPdpt = (PageTable*)(curPml4.[pml4e].addr << 12);
	}

	if (!curPdpt.[pdpte].present) {
		curPd = (PageTable*)mem.alloc_pages(1, true);
		curPdpt.[pdpte] = { .addr = ((uptr)curPd) >> 12, .writable = true, .present = true };
	} else {
		curPd = (PageTable*)(curPdpt.[pdpte].addr << 12);
	}

	if (huge) {
		curPd.[pde] = { .addr = paddr >> 12, .writable = true, .present = true, .huge = true };
	} else {
		if (!curPd.[pde].present) {
			curPt = (PageTable*)mem.alloc_pages(1, true);
			curPd.[pde] = { .addr = ((uptr)curPt) >> 12, .writable = true, .present = true };
		} else {
			curPt = (PageTable*)(curPd.[pde].addr << 12);
		}

		curPt.[pte] = { .addr = paddr >> 12, .writable = true, .present = true };
	}
}

fn void? MemoryManager.map(&mem, PageTable* pml4, void* paddr, uptr vaddr, usz pages) {
	if (&pml4 == null) return TABLE_IS_NULL~;

	for (usz count = 0; count < pages; count++, paddr += PAGE_SIZE, vaddr += PAGE_SIZE) {
		mem.vmap_helper(pml4, (uptr)paddr, vaddr);
	}
}
