module uefi::protocol::file;

macro FileProtocol.open(&self, FileProtocol** newHandle, WChar* fileName, FileOpenMode openMode, ulong attributes)
	=> self._open(self, newHandle, fileName, openMode, attributes);

macro FileProtocol.close(&self) => self._close(self);
macro FileProtocol.delete(&self) => self._delete(self);
macro FileProtocol.read(&self, usz* bufSize, void* buf) => self._read(self, bufSize, buf);
macro FileProtocol.write(&self, usz* bufSize, void* buf) => self._write(self, bufSize, buf);
macro FileProtocol.get_position(&self, ulong* pos) => self._get_position(self, pos);
macro FileProtocol.set_position(&self, ulong pos) => self._set_position(self, pos);
macro FileProtocol.get_info(&self, EfiGuid* infoType, usz* bufSize, void* buf) => self._get_info(self, infoType, bufSize, buf);
macro FileProtocol.set_info(&self, EfiGuid* infoType, usz bufSize, void* buf) => self._set_info(self, infoType, bufSize, buf);
macro FileProtocol.flush(&self) => self._flush(self);

macro FileSystemProtocol.open_volume(&self, FileProtocol** fileProt) => self._open_volume(self, fileProt);

constdef FileOpenMode : inline ulong {
	CREATE = 0,
	READ = 1,
	WRITE = 2,
}
