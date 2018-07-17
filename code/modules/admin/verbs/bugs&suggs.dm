var/sepstring = ""
// see bug reports
/client/proc/see_bug_reports()
	set name = "See Bug Reports"
	set category = "Server"

	establish_db_connection()

	if (database)
		var/list/bugreports = database.execute("SELECT * FROM bug_reports;")
		var/list/bugreport_names = list()
		if (islist(bugreports) && !isemptylist(bugreports))
			for (var/v in TRUE to bugreports["occurences_of_name"])
				bugreport_names += bugreports["name_[v]"]
		else
			src << "<span class = 'danger'>There are no open bug reports right now.</span>"
			return
		var/bugreport = input("Please select a bug report to work with.") in bugreport_names + "Cancel"
		if (!bugreport || bugreport == "Cancel")
			src << "<span class = 'warning'>No bug report selected; cancelling proc.</span>"
			return
		else
			var/option = input(src, "Please select an option for bugreport '[bugreport]'.") in list("View", "Delete", "Cancel")
			switch (lowertext(option))
				if ("view")

					bugreports = database.execute("SELECT * FROM bug_reports WHERE name = '[bugreport]';")
					if (!islist(bugreports) || isemptylist(bugreports))
						src << "<span class = 'danger'>Something went wrong - you can't see this bug report. Contact someone with DB access or a coder and tell them to fix it.</span>"
						return

					if (!sepstring)
						for (var/v in TRUE to 50)
							sepstring += "-"

					src << "<span class = 'notice'>[sepstring]</span>"
					src << "<span class = 'notice'><big>[bugreport]</big></span>"
					for (var/key in bugreports)
						if (dd_hassuffix(key, "_"))
							continue
						if (findtext(key, "occurences"))
							continue
						if (key == "steps")
							continue
						var/value = bugreports[key]
						src << "<span class = 'notice'>[key] = [value]</span>"
					var/steps = bugreports["steps"]
					if (lentext(steps))
						var/list/stepslist = splittext(steps, "&")
						var/stepnum = FALSE
						src << "<br><br>***TO REPRODUCE ERROR***<br><br>"
						for (var/_step in stepslist)
							src << "Step #[++stepnum]: [_step]<br>"

					src << "<span class = 'notice'>[sepstring]</span>"

				if ("delete")
					if (database.execute("DELETE FROM bug_reports WHERE name = '[bugreport]';"))
						src << "<span class = 'notice'>Bug report '[bugreport]' successfully deleted.</span>"
						var/M = "[key_name(src)] has deleted the bug report '[bugreport]'"
						log_admin(M)
						message_admins(M)
					else
						src << "<span class = 'warning'>A database error occured; bugreport '[bugreport]' was not deleted.</span>"
				if ("cancel")
					return
	else
		src << "<span class = 'danger'>A database error occured; you cannot see bug reports right now.</span>"

// see suggestions
/client/proc/see_suggestions()
	set name = "See Suggestions"
	set category = "Server"

	establish_db_connection()

	if (database)
		var/list/suggestions = database.execute("SELECT * FROM suggestions;")
		var/list/suggestion_names = list()
		if (islist(suggestions) && !isemptylist(suggestions))
			for (var/v in TRUE to suggestions["occurences_of_name"])
				suggestion_names += suggestions["name_[v]"]
		else
			src << "<span class = 'danger'>There are no open suggestions right now.</span>"
			return
		var/suggestion = input("Please select a suggestion to work with.") in suggestion_names + "Cancel"
		if (!suggestion || suggestion == "Cancel")
			src << "<span class = 'warning'>No suggestion selected; cancelling proc.</span>"
			return
		else
			var/option = input(src, "Please select an option for suggestion '[suggestion]'.") in list("View", "Delete", "Cancel")
			switch (lowertext(option))
				if ("view")

					suggestions = database.execute("SELECT * FROM suggestions WHERE name = '[suggestion]';")
					if (!islist(suggestions) || isemptylist(suggestions))
						src << "<span class = 'danger'>Something went wrong - you can't see this suggestion. Contact someone with DB access or a coder and tell them to fix it.</span>"
						return

					if (!sepstring)
						for (var/v in TRUE to 50)
							sepstring += "-"

					src << "<span class = 'notice'>[sepstring]</span>"
					src << "<span class = 'notice'><big>[suggestion]</big></span>"
					for (var/key in suggestions)
						if (dd_hassuffix(key, "_"))
							continue
						if (findtext(key, "occurences"))
							continue
						var/value = suggestions[key]
						src << "<span class = 'notice'>[key] = [value]</span>"

					src << "<span class = 'notice'>[sepstring]</span>"

				if ("delete")
					if (database.execute("DELETE FROM suggestions WHERE name = '[suggestion]';"))
						src << "<span class = 'notice'>Suggestion '[suggestion]' successfully deleted.</span>"
						var/M = "[key_name(src)] has deleted the suggestion '[suggestion]'"
						log_admin(M)
						message_admins(M)
					else
						src << "<span class = 'warning'>A database error occured; suggestion '[suggestion]' was not deleted.</span>"
				if ("cancel")
					return
	else
		src << "<span class = 'danger'>A database error occured; you cannot see suggestions right now.</span>"