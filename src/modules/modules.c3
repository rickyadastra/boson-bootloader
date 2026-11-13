module boson::modules;

import uefi;
import boson;

const WString MODULES_PATH = (WString)$$wstr16("\\EFI\\BOOT\\modules\\");
const usz MODULES_BUFSIZE = 4096; 
const usz MAX_MODULES_COUNT = 32; 

char[MODULES_BUFSIZE] buf;
Module[MAX_MODULES_COUNT] loadedModules;
usz loadedModulesCount = 0;

fn void load_modules(FileProtocol* root) {
	FileProtocol* modulesDir;
	
	if (catch efi_error(root.open(&modulesDir, MODULES_PATH, FileOpenMode.READ, 0))) {
		boson::console.printn("Modules directory not found, skipping");
		return;
	}

	FileInfo* modulesInfo = file::get_info(modulesDir);
	boson::console.printn("Modules directory found, loading modules");

	usz bufSize = modulesInfo.size;

	while (true) {
		bufSize = buf.len;

		@catch(modulesDir.read(&bufSize, &&buf));
		FileInfo* info = (FileInfo*)&&buf;

		if (!info.attribute.archive) continue;
		if (bufSize == 0) break;

		usz i = 0;
		char[32] name;
		WChar* c = &info.filename;
		while (*c != (ushort)'\0' && i < name.len) name[i++] = (char)*c++;

		boson::console.print("Loading module %s...", name[:i]);

		FileProtocol* moduleFile;
		@catch(modulesDir.open(&moduleFile, &info.filename, FileOpenMode.READ, 0));

		void* moduleBuf = boson::mem.alloc_pages(memory::@pages(info.fileSize));
		@catch(moduleFile.read(&bufSize, moduleBuf));
		
		loadedModules[loadedModulesCount++] = {
			.address = (uptr)moduleBuf,
			.size = (uint)info.fileSize,
			.name = name[..],
			.nameLen = (char)i,
		};

		boson::console.printn(" done @ %x", moduleBuf);
	}
}
