/*
 * Holds procs designed to change one type of value, into another.
 * Contains:
 *			path2text
 *			hex2num & num2hex
 *			text2list & list2text
 *			file2list
 *			angle2dir
 *			angle2text
 */

/proc/path2text(var/path)
	return "[path]"

//Returns an integer given a hex input
/proc/hex2num(hex)
	if(!istext(hex))
		return

	var/num = 0
	var/power = 0
	var/i = length_char(hex)

	while(i > 0)
		var/char = copytext_char(hex, i, i + 1)
		switch(char)
			if ("0")
				pass()
			if("9", "8", "7", "6", "5", "4", "3", "2", "1")
				num += text2num(char) * 16 ** power
			if("a", "A")
				num += 16 ** power * 10
			if("b", "B")
				num += 16 ** power * 11
			if("c", "C")
				num += 16 ** power * 12
			if("d", "D")
				num += 16 ** power * 13
			if("e", "E")
				num += 16 ** power * 14
			if("f", "F")
				num += 16 ** power * 15
			else
				return
		power++
		i--
	return num

//Returns the hex value of a number given a value assumed to be a base-ten value
/proc/num2hex(num, placeholder)
	if(placeholder == null)
		placeholder = 2

	if(!isnum(num))
		return

	if(num == 0)
		var/final = ""
		for(var/i in 1 to placeholder)
			final = "[final]0"
		return final

	var/hex = ""
	var/i = 0
	while(16 ** i < num)
		i++
	var/power = null
	power = i - 1
	while(power >= 0)
		var/val = round(num / 16 ** power)
		num -= val * 16 ** power
		switch(val)
			if(9, 8, 7, 6, 5, 4, 3, 2, 1, 0)
				hex += text("[]", val)
			if(10)
				hex += "A"
			if(11)
				hex += "B"
			if(12)
				hex += "C"
			if(13)
				hex += "D"
			if(14)
				hex += "E"
			if(15)
				hex += "F"
			else
		power--
	while(length_char(hex) < placeholder)
		hex = text("0[]", hex)
	return hex

//TODO replace thise usage with the byond proc
//Converts a string into a list by splitting the string at each delimiter found. (discarding the seperator)
/proc/text2list(text, delimiter = "\n")
	var/delim_len = length_char(delimiter)
	if(delim_len < 1)
		return list(text)

	. = list()
	var/last_found = 1
	var/found
	do
		found = findtext_char(text, delimiter, last_found, 0)
		. += copytext_char(text, last_found, found)
		last_found = found + delim_len
	while(found)
// Splits the text of a file at seperator and returns them in a list.
/proc/file2list(filename, seperator="\n")
	return splittext(return_file_text(filename),seperator)

//Turns a direction into text
/proc/num2dir(direction)
	switch(direction)
		if(1)
			return NORTH
		if(2)
			return SOUTH
		if(4)
			return EAST
		if(8)
			return WEST

//Turns a direction into text
/proc/dir2text(direction)
	switch(direction)
		if(NORTH)
			return "north"
		if(SOUTH)
			return "south"
		if(EAST)
			return "east"
		if(WEST)
			return "west"
		if(NORTHEAST)
			return "northeast"
		if(SOUTHEAST)
			return "southeast"
		if(NORTHWEST)
			return "northwest"
		if(SOUTHWEST)
			return "southwest"

//Turns text into proper directions
/proc/text2dir(direction)
	switch(uppertext(direction))
		if("NORTH")
			return NORTH
		if("SOUTH")
			return SOUTH
		if("EAST")
			return EAST
		if("WEST")
			return WEST
		if("NORTHEAST")
			return NORTHEAST
		if("NORTHWEST")
			return NORTHWEST
		if("SOUTHEAST")
			return SOUTHEAST
		if("SOUTHWEST")
			return SOUTHWEST

//Converts an angle (degrees) into an ss13 direction
/proc/angle2dir(degree)
	degree = ((degree + 22.5) % 365)
	if(degree < 45)
		return NORTH
	if(degree < 90)
		return NORTHEAST
	if(degree < 135)
		return EAST
	if(degree < 180)
		return SOUTHEAST
	if(degree < 225)
		return SOUTH
	if(degree < 270)
		return SOUTHWEST
	if(degree < 315)
		return WEST
	return NORTH|WEST

//returns the north-zero clockwise angle in degrees, given a direction
/proc/dir2angle(D)
	switch(D)
		if(NORTH)
			return 0
		if(SOUTH)
			return 180
		if(EAST)
			return 90
		if(WEST)
			return 270
		if(NORTHEAST)
			return 45
		if(SOUTHEAST)
			return 135
		if(NORTHWEST)
			return 315
		if(SOUTHWEST)
			return 225

/proc/nearbydirections(direction)
	switch (direction)
		if (NORTH)
			return list(NORTHWEST, NORTHEAST, NORTH)
		if (SOUTH)
			return list(SOUTHWEST, SOUTHEAST, SOUTH)
		if (EAST)
			return list(NORTHEAST, SOUTHEAST, EAST)
		if (WEST)
			return list(NORTHWEST, SOUTHWEST, WEST)
		if (NORTHEAST)
			return list(NORTH, EAST, NORTHEAST)
		if (SOUTHEAST)
			return list(SOUTH, EAST, SOUTHEAST)
		if (NORTHWEST)
			return list(NORTH, WEST, NORTHWEST)
		if (SOUTHWEST)
			return list(SOUTH, WEST, SOUTHWEST)

//Converts a blend_mode constant to one acceptable to icon.Blend()
/proc/blendMode2iconMode(blend_mode)
	switch(blend_mode)
		if(BLEND_MULTIPLY)
			return ICON_MULTIPLY
		if(BLEND_ADD)
			return ICON_ADD
		if(BLEND_SUBTRACT)
			return ICON_SUBTRACT
		else
			return ICON_OVERLAY

// Converts a rights bitfield into a string
/proc/rights2text(rights,seperator="")
	if (rights & R_BUILDMODE)
		. += "[seperator]+BUILDMODE"
	if (rights & R_ADMIN)
		. += "[seperator]+ADMIN"
	if (rights & R_TRIALADMIN)
		. += "[seperator]+TRIALADMIN"
	if (rights & R_FUN)
		. += "[seperator]+FUN"
	if (rights & R_SERVER)
		. += "[seperator]+SERVER"
	if (rights & R_DEBUG)
		. += "[seperator]+DEBUG"
	if (rights & R_POSSESS)
		. += "[seperator]+POSSESS"
	if (rights & R_PERMISSIONS)
		. += "[seperator]+PERMISSIONS"
	if (rights & R_STEALTH)
		. += "[seperator]+STEALTH"
	if (rights & R_REJUVINATE)
		. += "[seperator]+REJUVINATE"
	if (rights & R_VAREDIT)
		. += "[seperator]+VAREDIT"
	if (rights & R_SOUNDS)
		. += "[seperator]+SOUND"
	if (rights & R_SPAWN)
		. += "[seperator]+SPAWN"
	if (rights & R_MOD)
		. += "[seperator]+MODERATOR"
	if (rights & R_MENTOR)
		. += "[seperator]+MENTOR"
	return .

/proc/list2text(L)
	return jointext(L, ";")


