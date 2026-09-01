module boson::file;

import uefi;

macro FileInfo* get_info(FileProtocol* file) {
	FileInfo* finfo = null;
	usz size;

	@expect(file.get_info(&guid::FILE_INFO, &size, null), error::BUFFER_TOO_SMALL) {
		finfo = (FileInfo*)boson::alloc(size);
		@catch(file.get_info(&guid::FILE_INFO, &size, finfo));
	};

	return finfo;
}
