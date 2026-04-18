module boson::console;

import uefi;
import uefi::protocol::console;
import commons::formatting;

const String NEWLINE @private = "\r\n";
const WString WNEWLINE @private = $$wstr16(NEWLINE);
WChar[1024] buf = {};

struct Console {
    SimpleTextInputProtocol* conIn;
    SimpleTextOutputProtocol* conOut;
}

fn Console init(SystemTable* table) => {.conIn = table.conIn, .conOut = table.conOut};

macro WString @wide(String str) {
    foreach (usz i, char c : str) {
        buf[i] = (WChar)c;
    }

    buf[str.len] = '\0';
    return (WString)buf[..str.len+1];
}

fn void Console.print(&self, String string, args...) {
    Formatter fmt; 
    String s = fmt.format(string, ...args)!!;
    efi_error(self.conOut.@output_string((EfiString)@wide(s)))!!;
}

macro Console.wprint(&self, WString $string) => efi_error(self.conOut.@output_string($string))!!;

macro Console.printn(&self, String string, args...) {
    self.print(string, ...args);
    self.wprint(WNEWLINE);
}

macro Console.wprintn(&self, WString $string) {
    self.wprint($string);
    self.wprint(WNEWLINE);
}

fn void Console.panic(&self, String reason, String file = "", String func = "", uint line = 0) {
	self.conOut.@output_string("\nBOSON PANIC! ");
	self.conOut.@output_string(@wide(reason));

    if (func.len > 0) {
        self.conOut.@output_string(" @ ");
        self.conOut.@output_string(@wide(func));

        if (file.len > 0) {
            self.conOut.@output_string(" (");
            self.conOut.@output_string(@wide(file));

            char[16] tempBuf;
            if (try fmtLen = formatting::format_any_to_decimal(&line, &tempBuf)) {
                self.conOut.@output_string(":");
                self.conOut.@output_string(@wide((String)tempBuf[:fmtLen]));
            }
            self.conOut.@output_string(")\n");
        }
    }
}

macro Console.pause(&self) {
    while (catch efi_error(self.conIn.@read_key((EfiInputKey){})));
}

macro Console.clear(&self) => self.conOut.@clear_screen();
