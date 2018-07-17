
/client/proc/toggle_jobs()
	set name = "Toggle Jobs"
	set category = "Special"

	if (!check_rights(R_ADMIN))
		src << "<span class = 'danger'>You don't have the permissions.</span>"
		return

	var/list/jobs_linked_list = list()
	for (var/datum/job/j in job_master.occupations)
		if (istype(j))
			jobs_linked_list[j.title] = j

	var/list/choices = list()

	for (var/jobtitle in jobs_linked_list)
		var/datum/job/j = jobs_linked_list[jobtitle]
		if (j.enabled)
			choices += "[jobtitle] (ENABLED)"
		else
			choices += "[jobtitle] (DISABLED)"

	choices += "CANCEL"


	var/choice = input("Enable/Disable what job?") in choices
	if (choice == "CANCEL")
		return

	var/jobtitle = replacetext(choice, " (ENABLED)", "")
	jobtitle = replacetext(jobtitle, " (DISABLED)", "")

	world << jobtitle
	world << jobs_linked_list[jobtitle]

	var/datum/job/j = jobs_linked_list[jobtitle]
	if (j)
		j.enabled = !j.enabled
		world << "<span class = 'warning'>[j.title] is now <b>[j.enabled ? "ENABLED" : "DISABLED"]</b>.</span>"
		message_admins("[key_name(src)] [j.enabled ? "enabled" : "disabled"] the [j.title] job.")