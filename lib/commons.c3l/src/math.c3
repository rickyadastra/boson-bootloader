module commons::math;

import lang;

const DOUBLE_MANT_DIG = 53;
const DOUBLE_MAX_EXP = 1024;
const DOUBLE_EPSILON = 2.22044604925031308085e-16;

macro max(x, y, ...)
{
	$if $vacount == 0:
		return $$max(x, y);
	$else
		var m = $$max(x, y);
		$for var $i = 0; $i < $vacount; $i++:
			m = $$max(m, $vaarg[$i]);
		$endfor
		return m;
	$endif
}

macro min(x, y, ...)
{
	$if $vacount == 0:
		return $$min(x, y);
	$else
		var m = $$min(x, y);
		$for var $i = 0; $i < $vacount; $i++:
			m = $$min(m, $vaarg[$i]);
		$endfor
		return m;
	$endif
}
