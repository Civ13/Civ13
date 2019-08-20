/* WWinput: wrappers for input()/alert(). Example: WWinput(mob_or_client, "Y/N", "Choices", "text", list("Y", "N"))
 * Specifying the type variable when type == "text" is not necessary, but it's recommended. WWinput has two purposes:
 	* 1. Standardizing input()/alert() with a format that encourages supplying all args, like 'title', for the sake of QOL
 	* 2. Stopping mob movement while an alert/input window is active
*/

/* Note the toc1, toc2 args here. These are short for "type_or_choices". When neither are defined, we just go to alert().
 * When both are defined, toc1 will be the type argument, toc2 will be the choices (list) argument, mimicing the traditional BYOND input construct of "as type in list".
 * toc2 should never be defined unless toc1 is also defined, or the proc will return FALSE and do nothing. When toc1 is the only argument of the two
 * defined, it will be checked to see if its a type or a choices list. If it's a list with >= 1 object (text, num, actual object), its considered to be a choices list.
 * If it's "num" or "text", it will be converted into the appropriate type. Object types can't go here, or the proc returns FALSE and fails.
 * Unfortunately, BYOND doesn't support dynamic arguments for input()'s "as type" thing - we have to use "as [text/num/whatever]", not "as [var]".
 * So when both toc1 and toc2 are defined, we just take the choices list and remove anything that isn't the proper type. All of this makes this procedure quite slower
 * than BYOND's input(), but that's inevitable when wrapping a built-in function. */

/proc/WWinput(client, message, title, default, toc1, toc2)

	if (!title)
		title = "Civilization 13"

	. = FALSE

	if (!isclient(client))
		if (!ismob(client))
			return FALSE
		else
			client = client:client

	var/client/C = client
	if (C)
		C.stopmovingup()
		C.stopmovingdown()
		C.stopmovingleft()
		C.stopmovingright()

	if (!toc1 && !toc2)
		alert(C, message, title, "Continue")
		. = TRUE
	else
		// no, this is bad
		if (!toc1 && toc2)
			return FALSE
		else if (toc1 && !toc2)
			var/choice = FALSE

			if (islist(toc1) && toc1:len)
				choice = TRUE

			if (choice)
				if (default)
					. = input(C, message, title, default) in toc1
				else
					. = input(C, message, title) in toc1
			else
				switch (toc1)
					if ("text")
						if (default)
							. = input(C, message, title, default) as text
						else
							. = input(C, message, title) as text
					if ("num")
						if (default)
							. = input(C, message, title, default) as num
						else
							. = input(C, message, title) as num
					if ("color")
						if (default)
							. = input(C, message, title, default) as color
						else
							. = input(C, message, title) as color

		else if (toc1 && toc2)
			switch (toc1)
				if ("text")
					for (var/thing in toc2)
						if (!istext(thing))
							toc2 -= thing
				if ("num")
					for (var/thing in toc2)
						if (!isnum(thing))
							toc2 -= thing
				if ("list", list())
					for (var/thing in toc2)
						if (!islist(thing))
							toc2 -= thing
				else
					if (isdatum(toc1))
						toc1 = toc1:type
					if (ispath(toc1))
						for (var/thing in toc2)
							if (thing == toc1 || ispath(thing, toc1) || istype(thing, toc1))
								pass()
							else
								toc2 -= toc1

			if (default)
				. = input(C, message, title, default) in toc2
			else
				. = input(C, message, title) in toc2

	// if we picked the Cancel choice, return null
	if (. == "Cancel")
		if (toc1 && islist(toc1) && toc1:len && toc1[toc1:len] == .)
			. = null
		else if (toc2 && islist(toc2) && toc2:len && toc2[toc2:len] == .)
			. = null

	return .

// alias for WWinput that only accepts the first three arguments. Use it for giving informative popups. Unlike BYOND's alert(), it may not be used for getting user input.
/proc/WWalert(client, message, title)
	return WWinput(client, message, title)