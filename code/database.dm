var/database/database = null

/database/New()
	..()


/database/proc/newUID()
	return num2text(rand(1, 1000*1000*1000), 20)

/* only_execute_once = FALSE is only safe when this is called from a verb
 * or proc behaving like a verb, otherwise it can bog down other procs */
/database/proc/execute(querytext, var/only_execute_once = TRUE)
	. = FALSE

	// fixes a common SQL typo
	querytext = replacetext(querytext, " == ", " = ")

	if (findtext(querytext, regex("TABLE.*EXISTS")))
		querytext = replacetext(querytext, " ", "")
		querytext = replacetext(querytext, "TABLE", "")
		querytext = replacetext(querytext, "EXISTS", "")
		return table_exists(querytext)

	else if (findtext(querytext, regex("TABLE.*FILLED")))
		querytext = replacetext(querytext, " ", "")
		querytext = replacetext(querytext, "TABLE", "")
		querytext = replacetext(querytext, "FILLED", "")
		return table_filled(querytext)

	// clean up extra spaces in querytext
	var/empty_space = " " // don't replace single spaces
	for (var/v in 1 to 10)
		empty_space += " " // replaces up to 11 spaces at once
		querytext = replacetext(querytext, empty_space, v)

	// ensure we end with ;
	if (dd_hassuffix(querytext, ";"))
		querytext = copytext(querytext, TRUE, length(querytext))

	querytext = "[querytext];"

	var/database/query/Q = new(querytext)

	// try to execute 10 times over 5 seconds
	var/Q_executed = FALSE
	for (var/v in 1 to 10)
		if (Q.Execute(src))
			Q_executed = TRUE
			goto finishloop
		if (only_execute_once)
			goto finishloop
		sleep(5)

	finishloop
	if (Q_executed)
		. = TRUE
		if (findtext(querytext, "SELECT"))

			. = list()
			var/occurences_of = list()

			while (Q.NextRow())
				for (var/x in Q.GetRowData())
					if (!.[x])
						.[x] = Q.GetRowData()[x]
						.["[x]_1"] = .[x]
						occurences_of[x] = TRUE
					else // handle duplicate values
						var/occ = ++occurences_of[x]
						.["[x]_[occ]"] = Q.GetRowData()[x]
						// let us count how many 'x's there are
					.["occurences_of_[x]"] = occurences_of[x]

			return .

/* handle custom queries TABLE EXISTS and TABLE FILLED */
/proc/table_exists(tablename)
	var/database/query/Q = new("SELECT * FROM [tablename];")
	if (Q.Execute(database))
		return TRUE
	return FALSE

/database/proc/table_filled(tablename)
	if (!table_exists(tablename))
		return FALSE
	var/database/query/Q = new("SELECT * FROM [tablename];")
	if (Q.Execute(database) && Q.NextRow())
		return TRUE
	return FALSE