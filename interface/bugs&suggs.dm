/client/verb/reportabug()
	set hidden = TRUE

	establish_db_connection()

	rename

	var/bugname = input("What is a name for this bug?") as null|text
	if (!bugname)
		return

	if (lentext(bugname) > 100)
		bugname = copytext(bugname, TRUE, 101)
		src << "<span class = 'warning'>Your bug's name was clamped to 100 characters.</span>"

	var/check_name_already_exists = database.execute("SELECT * FROM bug_reports WHERE name = '[bugname]';", FALSE)
	if (islist(check_name_already_exists) && !isemptylist(check_name_already_exists))
		src << "<span class = 'danger'>This bug already exists! Please choose another name.</span>"
		goto rename

	bugname = sanitizeSQL(bugname)

	redesc

	var/bugdesc = input("What is the bug's description?") as text
	if (lentext(bugdesc) > 500)
		bugdesc = copytext(bugdesc, TRUE, 501)
		src << "<span class = 'warning'>Your bug's description was clamped to 500 characters.</span>"

	if (!bugdesc)
		src << "<span class = 'warning'>Please put something in the description field.</span>"
		goto redesc

	bugdesc = sanitizeSQL(bugdesc)

	var/list/steps = list()
	var/bugrep = input("Does the bug have any special steps in order to recreate it?") in list("Yes", "No")
	if (bugrep == "Yes")
		var/stepnum = steps.len+1
		while ((input("Add another step? (#[stepnum])") in list ("Yes", "No")) == "Yes")
			var/step = input("What is a description of step number #[stepnum]?") as text
			step = sanitizeSQL(step)
			if (lentext(step) > 200)
				step = copytext(step, TRUE, 201)
				src << "<span class = 'warning'>[step] #[stepnum] was clamped to 200 characters.</span>"
			steps += step
			if (stepnum == 10)
				src << "<span class = 'warning'>Max number of steps (#[stepnum]) reached.</span>"
				break
			else
				stepnum = steps.len+1

	// this code is a bit problematic
	// if you have duplicate steps, it won't work right and
	// it will merge steps
	// but that doesn't really matter right now
	// because you shouldn't have two of the same steps - Kachnov
	var/steps2string = ""
	for (var/_step in steps)
		steps2string += _step
		if (_step != steps[steps.len])
			steps2string += "&"

	var/anything_else = input("Anything else?") as text
	if (lentext(anything_else) > 1000)
		bugdesc = copytext(anything_else, 1, 1001)
		src << "<span class = 'warning'>Your bug's 'anything else' value was clamped to 1000 characters.</span>"

	if (!anything_else)
		anything_else = "nil"

	anything_else = sanitizeSQL(anything_else)

	anything_else += "<br><i>Reported by [src], who was, at the time, [key_name(src)]</i>"

	_tryagain_
	if (bugname && bugdesc && bugrep && anything_else)
		if (database)
			if (database.execute("INSERT INTO bug_reports (name, desc, steps, other) VALUES ('[bugname]', '[bugdesc]', '[steps2string]', '[anything_else]');", FALSE))
				src << "<span class = 'notice'>Your bug was successfully reported. Thank you!</span>"
				message_admins("New bug report received from [key_name(src)], titled '[bugname]'.")
			else
				src << "<span class = 'warning'>A database error occured; your bug was NOT reported.</span>"
				var/tryagain = input(src, "Try to report this bug once more?") in list("Yes", "No")
				if (tryagain == "Yes")
					goto _tryagain_
		else
			src << "<span class = 'warning'>A database error occured; your bug was NOT reported.</span>"
	else
		src << "<span class = 'warning'>Please fill in all fields!</span>"

/client/verb/makeasugg()
	set hidden = TRUE

	if (isPatron("$5+") && (input(src, "You are a Patron. Would you like to submit a tip that will be displayed at roundstart?") in list("Yes", "No")) == "Yes")
		establish_db_connection()
		var/tip = input("What is this tip?") as null|text
		if (!tip)
			return
		if (lentext(tip) > 500)
			tip = copytext(tip, TRUE, 501)
			src << "<span class = 'warning'>Your tip's name was clamped to 500 characters.</span>"
		tip = sanitizeSQL(tip, 500)
		if (database.execute("INSERT INTO player_tips (UID, submitter, tip) VALUES ('[database.newUID()]', '[ckey]', '[tip]');"))
			src << "<span class = 'good'>Success! Your tip was sent to the admins.</span>"
		else
			src << "<span class = 'bad'>A database error occured. Your tip was not sent to the admins.</span>"
	else

		establish_db_connection()

		rename

		var/suggname = input("What is a name for this suggestion?") as null|text
		if (!suggname)
			return

		if (lentext(suggname) > 100)
			suggname = copytext(suggname, TRUE, 101)
			src << "<span class = 'warning'>Your suggestion's name was clamped to 50 characters.</span>"

		var/check_name_already_exists = database.execute("SELECT * FROM suggestions WHERE name = '[suggname]';", FALSE)
		if (islist(check_name_already_exists) && !isemptylist(check_name_already_exists))
			src << "<span class = 'danger'>This suggestion already exists! Please choose another name.</span>"
			goto rename

		suggname = sanitizeSQL(suggname)

		redesc

		var/suggdesc = input("What is the suggestions's description?") as text
		if (lentext(suggdesc) > 500)
			suggdesc = copytext(suggdesc, TRUE, 501)
			src << "<span class = 'warning'>Your suggestion's description was clamped to 500 characters.</span>"

		if (!suggdesc)
			src << "<span class = 'warning'>Please put something in the description field.</span>"
			goto redesc

		suggdesc = sanitizeSQL(suggdesc)

		suggdesc += "<br><i>Suggested by [src], who was, at the time, [key_name(src)]</i>"

		_tryagain_
		if (suggname && suggdesc)
			if (database)
				if (database.execute("INSERT INTO suggestions (name, desc) VALUES ('[suggname]', '[suggdesc]');", FALSE))
					src << "<span class = 'notice'>Your suggestion was successfully received. Thank you!</span>"
					message_admins("New suggestion received from [key_name(src)], titled '[suggname]'.")
				else
					src << "<span class = 'warning'>A database error occured; your suggestion was NOT sent.</span>"
					var/tryagain = input(src, "Try to send this suggestion once more?") in list("Yes", "No")
					if (tryagain == "Yes")
						goto _tryagain_
			else
				src << "<span class = 'warning'>A database error occured; your suggestion was NOT sent.</span>"
		else
			src << "<span class = 'warning'>Please fill in all fields!</span>"
