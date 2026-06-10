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

// stuff that was in the scripting folder, but was used elsewhere,
// so had to be copied here

// Script -> BYOND code procs
#define SCRIPT_MAX_REPLACEMENTS_ALLOWED 200
// --- List operations (lists known as vectors in n_script) ---

/proc/isobject(x)
	return (istype(x, /datum) || istype(x, /client) || islist(x))
