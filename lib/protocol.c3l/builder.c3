module boson::protocol::builder;

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
	bib.tags = null;

	return (BibBuilder) { 
		.bib = bib,
		.mem = memPtr,
		.memSz = memSz,
		.cursor = memPtr + BootInfoBlock::size
	};
}

macro bool BibBuilder.@append(&self, #tag) {

}
