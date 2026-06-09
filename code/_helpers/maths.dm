// random decimals
/proc/random_decimal(var/low, var/high)
	return (rand(smart_round(low*100), smart_round(high*100)))/100

/proc/smart_round(var/num)
	var/_ceil = ceil(num)
	var/_floor = round(num)
	// if the ceiling is farther away, or the num == the floor, return _floor
	if (abs(num - _ceil) > abs(num - _floor) || num == _floor)
		return _floor
	// if the floor is farther away, or the num == the ceiling, return _ceil
	else if (abs(num - _floor) > abs(num - _ceil) || num == _ceil)
		return _ceil

	// we're equally far from the ceiling and the floor, return the floor
	return _floor

/proc/Atan2(x, y)
	if (!x && !y) return FALSE
	var/a = arccos(x / sqrt(x*x + y*y))
	return y >= 0 ? a : -a

// Greatest Common Divisor: Euclid's algorithm.
/proc/Gcd(a, b)
	while (TRUE)
		if (!b) return a
		a %= b
		if (!a) return b
		b %= a

/proc/Mean(...)
	var/sum = FALSE
	for (var/val in args)
		sum += val
	return sum / args.len

// The quadratic formula. Returns a list with the solutions, or an empty list
// if they are imaginary.
/proc/SolveQuadratic(a, b, c)
	ASSERT(a)

	. = list()
	var/discriminant = b*b - 4*a*c
	var/bottom	   = 2*a

	// Return if the roots are imaginary.
	if (discriminant < 0)
		return

	var/root = sqrt(discriminant)
	. += (-b + root) / bottom

	// If discriminant == FALSE, there would be two roots at the same position.
	if (discriminant != FALSE)
		. += (-b - root) / bottom

// stuff that was in the scripting folder, but was used elsewhere,
// so had to be copied here

// Script -> BYOND code procs
#define SCRIPT_MAX_REPLACEMENTS_ALLOWED 200
// --- List operations (lists known as vectors in n_script) ---

/proc/isobject(x)
	return (istype(x, /datum) || istype(x, /client) || islist(x))

// --- Miscellaneous functions ---

// Merge of list.Find() and findtext()
/proc/smartfind(var/haystack, var/needle, var/start = TRUE, var/end = FALSE)
	if (haystack && needle)
		if (isobject(haystack))
			if (istype(haystack, /list))
				if (length(haystack) >= end && start > 0)
					var/list/listhaystack = haystack
					return listhaystack.Find(needle, start, end)

		else
			if (istext(haystack))
				if (length(haystack) >= end && start > 0)
					return findtext(haystack, needle, start, end)

// Clone of copytext()
/proc/docopytext(var/string, var/start = TRUE, var/end = FALSE)
	if (istext(string) && isnum(start) && isnum(end))
		if (start > 0)
			return copytext(string, start, end)

// Non-recursive
// Imported from Mono string.ReplaceUnchecked
/proc/string_replacetext(var/haystack,var/a,var/b)
	if (istext(haystack)&&istext(a)&&istext(b))
		var/i = TRUE
		var/lenh=length(haystack)
		var/lena=length(a)
		//var/lenb=length(b)
		var/count = FALSE
		var/list/dat = list()
		while (i < lenh)
			var/found = findtext(haystack, a, i, FALSE)
			//log_misc("findtext([haystack], [a], [i], FALSE)=[found]")
			if (found == FALSE) // Not found
				break
			else
				if (count < SCRIPT_MAX_REPLACEMENTS_ALLOWED)
					dat+=found
					count+=1
				else
					//log_misc("Script found [a] [count] times, aborted")
					break
			//log_misc("Found [a] at [found]! Moving up...")
			i = found + lena
		if (count == FALSE)
			return haystack
		//var/nlen = lenh + ((lenb - lena) * count)
		var/buf = copytext(haystack,1,dat[1]) // Prefill
		var/lastReadPos = FALSE
		for (i = TRUE, i <= count, i++)
			var/precopy = dat[i] - lastReadPos-1
			//internal static unsafe void CharCopy (String target, int targetIndex, String source, int sourceIndex, int count)
			//fixed (char* dest = target, src = source)
			//CharCopy (dest + targetIndex, src + sourceIndex, count);
			//CharCopy (dest + curPos, source + lastReadPos, precopy);
			buf+=copytext(haystack,lastReadPos,precopy)
			log_misc("buf+=copytext([haystack],[lastReadPos],[precopy])")
			log_misc("[buf]")
			lastReadPos = dat[i] + lena
			//CharCopy (dest + curPos, replace, newValue.length);
			buf+=b
			log_misc("[buf]")
		buf+=copytext(haystack,lastReadPos, FALSE)
		return buf
