// TRUE when A is an item that declares every quality in `quality` (TOOL_*
// flags in code/__defines/tools.dm). Null and non-items are never tools.
/proc/is_tool(atom/A, quality)
	if (!isitem(A))
		return FALSE
	var/obj/item/I = A
	return (I.tool_flags & quality) == quality
