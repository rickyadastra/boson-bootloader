module uefi::protocol::console;

macro SimpleTextOutputProtocol.clear_screen(&self) => self._clear_screen(self);
macro SimpleTextOutputProtocol.@output_string(&self, #string) {
	$switch ($typeof(#string)):
		$case EfiString.typeid:
			return self._output_string(self, #string);
		$case WString.typeid:
			return self._output_string(self, (EfiString)#string);
		$case String:
			return self._output_string(self, (EfiString)&&$$wstr16(#string));
		$default:
			$echo($typeof(#string));
			$error("Unknown string type for @output_string"); 
	$endswitch
}

macro SimpleTextInputProtocol.read_key(&self, EfiInputKey* key) => self._read_key(self, key);
