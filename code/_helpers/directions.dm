/proc/opposite_direction(dir)
	switch (dir)
		if (NORTH)
			return SOUTH
		if (SOUTH)
			return NORTH
		if (EAST)
			return WEST
		if (WEST)
			return EAST
		if (NORTHWEST)
			return SOUTHEAST
		if (NORTHEAST)
			return SOUTHWEST
		if (SOUTHEAST)
			return NORTHWEST
		if (SOUTHWEST)
			return NORTHEAST
	return NORTH

/atom/proc/dir2_text(var/atom/a)
	var/d1 = null
	var/d2 = null

	if (!a)
		return "somewhere"
	else
		if (a.y > y)
			d1 = "North"
		else if (a.y < y)
			d1 = "South"

		if (a.x > x)
			d2 = "East"
		else if (a.x < x)
			d2 = "West"

	if (d1 && d2)
		return "[d1][lowertext(d2)]"
	else if (d1 && !d2)
		return d1
	else if (d2 && !d1)
		return d2
	else
		return "your location"
