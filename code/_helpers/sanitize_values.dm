//general stuff
/proc/sanitize_integer(number, min=0, max=1, default=0)
	if (isnum(number))
		number = round(number)
		if (min <= number && number <= max)
			return number
	return default

/proc/sanitize_text(text, default="")
	if (istext(text))
		return text
	return default

/proc/sanitize_inlist(value, list/List, default)
	if (value in List)	return value
	if (default)			return default
	if (List && List.len)return List[1]






// Sanitize inputs to avoid SQL injection attacks
proc/sql_sanitize_text(var/text)
	text = replacetext(text, "'", "''")
	text = replacetext(text, ";", "")
	text = replacetext(text, "&", "")
	return text

