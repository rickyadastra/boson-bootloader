module boson::memory;

import uefi;

struct MemoryManager {
	BootServices* bootServices;
}

fn MemoryManager init(SystemTable* table) => {.bootServices = table.bootServices};

fn void* MemoryManager.alloc(&self, usz size, MemoryType memoryType = LOADER_DATA) {
	void* p;
	@catch(self.bootServices.allocate_pool(memoryType, size, &p));
	return p;
}

fn void* MemoryManager.alloc_pages(&self, usz num, AllocateType allocateType = ANY_PAGES, MemoryType memoryType = LOADER_DATA) {
	void* p;
	@catch(self.bootServices.allocate_pages(allocateType, memoryType, num, &p));
	return p;
}

macro void MemoryManager.free(&self, void* ptr) => @catch(self.bootServices.free_pool(ptr));
macro void MemoryManager.free_pages(&self, void* ptr, usz num) => @catch(self.bootServices.free_pages(ptr, num));
