module boson::protocol::builder;

import boson::protocol;

faultdef INSUFFICIENT_SIZE;

struct BibBuilder {
	BootInfoBlock* bib;
	uptr mem;
	usz memSz;
	uptr cursor;
}

fn BibBuilder init(uptr memPtr, usz memSz) {
	BootInfoBlock* bib = (BootInfoBlock*)memPtr;
	bib.magic = protocol::MAGIC;
	bib.revision = protocol::REVISION;
	bib.totalSize = BootInfoBlock::size;

	return (BibBuilder) { 
		.bib = bib,
		.mem = memPtr,
		.memSz = memSz,
		.cursor = memPtr + BootInfoBlock::size
	};
}

macro bool BibBuilder.@append(&self, #tag) {
	$if !($Typeof(#tag)::is_substruct && $Typeof(#tag)::parent == TagHeader):
		$error("Invalid type for BibBuilder.append()");
	$endif

	if (self.cursor + #tag.size <= self.mem + self.memSz) {
		*(($Typeof(#tag)*) self.cursor) = #tag;
		self.cursor += #tag.size; 
		self.bib.totalSize += #tag.size;
		return true;
	}

	return false;
}

macro void? BibBuilder.@append_memory_map(&self, TagMemoryMap #tag, MemoryEntry[] #entries) {
	if (!self.@append(#tag)) return INSUFFICIENT_SIZE~;

	MemoryEntry* cur = (MemoryEntry*)(self.cursor - MemoryEntry::size*#tag.numOfEntries);

	foreach (MemoryEntry entry : #entries) {
		*cur = entry;
		cur++;
	}
}

macro BootInfoBlock*? BibBuilder.complete(&self) {
	if (!self.@append(tag::terminator())) return INSUFFICIENT_SIZE~;

	// move cursor to end, inhibit new appends
	self.cursor = self.mem + self.memSz;
	return self.bib;
}
