module boson::modules;

import uefi;
import boson;

const WString MODULES_PATH = (WString)$$wstr16("\\EFI\\BOOT\\modules\\");
const usz MAX_MODULES_COUNT = 32; 

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

	usz bufSz = 0;
	FileInfo* info = null;

	while (true) {
		usz curSz = bufSz;
		EfiStatus status = modulesDir.read(&curSz, info);

		if (status == EfiStatus.BUFFER_TOO_SMALL) {
			if (info != null) boson::mem.free(info);

			bufSz = curSz;
			info = boson::alloc(bufSz);

			if (info == null) {
				status = EfiStatus.OUT_OF_RESOURCES;
				break;
			}

			status = modulesDir.read(&curSz, info);
		}

		if (catch f = efi_error(status)) {
			boson::console.printn("Error while enumerating modules: %s", f.description);
			return;
		}

		if (curSz == 0) break; // no more files
		if (!info.attribute.archive) continue;

		usz i = 0;
		char[32] name;
		WChar* c = &info.filename;
		while (*c != (ushort)'\0' && i < name.len) name[i++] = (char)*c++;

		boson::console.print("Loading module %s...", name[:i]);

		FileProtocol* moduleFile;
		@catch(modulesDir.open(&moduleFile, &info.filename, FileOpenMode.READ, 0));

		usz moduleSz = info.fileSize;
		usz pagesSz = memory::@pages(info.fileSize);
		void* moduleBuf = boson::mem.alloc_pages(pagesSz);
		@catch(moduleFile.read(&moduleSz, moduleBuf));

		boson::add_memory_entry((uptr)moduleBuf, 0, pagesSz*memory::PAGE_SIZE, MODULE);
		
		loadedModules[loadedModulesCount++] = {
			.address = (uptr)moduleBuf,
			.size = (uint)info.fileSize,
			.name = name[..],
			.nameLen = (char)i,
		};

		boson::console.printn(" done @ %x", moduleBuf);
		moduleFile.close();
	}

	if (info != null) boson::mem.free(info);
	modulesDir.close();
}
