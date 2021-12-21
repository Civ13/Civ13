/*	Note from Carnie:
		The way datum/mind stuff works has been changed a lot.
		Minds now represent IC characters rather than following a client around constantly.

	Guidelines for using minds properly:

	-	Never mind.transfer_to(ghost). The var/current and var/original of a mind must always be of type mob/living!
		ghost.mind is however used as a reference to the ghost's corpse

	-	When creating a new mob for an existing IC character (e.g. cloning a dead guy)
		the existing mind of the old mob should be transfered to the new mob like so:

			mind.transfer_to(new_mob)

	-	You must not assign key= or ckey= after transfer_to() since the transfer_to transfers the client for you.
		By setting key or ckey explicitly after transfering the mind with transfer_to you will cause bugs like DCing
		the player.

	-	IMPORTANT NOTE 2, if you want a player to become a ghost, use mob.ghostize() It does all the hard work for you.

	-	When creating a new mob which will be a new IC character (e.g. putting a shade in a construct or randomly selecting
		a ghost to become a xeno during an event). Simply assign the key or ckey like you've always done.

			new_mob.key = key

		The Login proc will handle making a new mob for that mobtype (including setting up stuff like mind.name). Simple!
		However if you want that mind to have any special properties like being a traitor etc you will have to do that
		yourself.

*/

/datum/mind
	var/key
	var/name				//replaces mob/var/original_name
	var/mob/living/current
	var/mob/living/original	//TODO: remove.not used in any meaningful way ~Carn. First I'll need to tweak the way silicon-mobs handle minds.
	var/active = FALSE

	var/memory

	var/list/notes = list()

	var/assigned_role
	var/special_role

	var/role_alt_title

	var/datum/job/assigned_job

	var/list/datum/objective/objectives = list()
	var/list/datum/objective/special_verbs = list()

	var/has_been_rev = FALSE//Tracks if this mind has been a rev or not

	var/datum/faction/faction 			//associated faction
	var/datum/changeling/changeling		//changeling holder

	var/rev_cooldown = FALSE

	// the world.time since the mob has been brigged, or -1 if not at all
	var/brigged_since = -1

	//put this here for easier tracking ingame
	var/datum/money_account/initial_account

	var/datum/martial_art/martial_art
	var/static/datum/martial_art/default_martial_art = new/datum/martial_art

/datum/mind/New(var/_key)
	key = _key
	..()

/datum/mind/proc/transfer_to(mob/living/new_character)
	if (!istype(new_character))
		world.log << "## DEBUG: transfer_to(): Some idiot has tried to transfer_to() a non mob/living mob. Please inform the coders."
	if (current)					//remove ourself from our old body's mind variable
		current.mind = null
		nanomanager.user_transferred(current, new_character) // transfer active NanoUI instances to new user

	if (new_character.mind)		//remove any mind currently in our new body's mind variable
		new_character.mind.current = null

	current = new_character		//link ourself to our new body
	new_character.mind = src	//and link our new body to ourself

	if (active)
		new_character.key = key		//now transfer the key to link the client to our new body

/datum/mind/proc/add_note(section, note)
	if (!notes.Find(section))
		notes[section] = list()
	notes[section] += note


/datum/mind/proc/remove_note(section, note)
	if (!notes.Find(section))
		notes[section] = list()
	notes[section] -= note

/datum/mind/proc/wipe_notes()
	for (var/title in notes)
		qdel_list(notes[title])
		notes -= title

/datum/mind/proc/store_memory(new_text)
	memory += "[new_text]<BR>"

/datum/mind/proc/show_memory(mob/recipient)
	var/output = "<b>You are <span style = 'font-size: 1.25em; color: #E1E1FF'>[current.real_name]</span></b><hr>"
	for (var/title in notes)
		output += "<br><br>"
		output += "<b><span style = 'font-size: 1.1em; color: #E1E1FF'>[title]</span></b>"
		output += "<br><br>"
		var/list/notelist = notes[title]
		for (var/v in 1 to notelist.len)
			output += "<i>[notelist[v]]</i>"
			if (v != notelist.len)
				output += "<br>"
		output += "<br>"

	output += "<br><br>"
	output += "<b><span style = 'font-size: 1.1em; color: #E1E1FF'>Memories</span></b>"
	output += "<br><br>"
	if (memory)
		output += "<i>[memory]</i>"
	else
		output += "<i>No memories stored.</i>"

	var/memory_stylized = {"
	<br>
	<html>
	<head>
	[common_browser_style]
	</head>
	<body><center>
	<big>PLACEHOLDER</big>
	<br><br><br>
	<i>Use the 'Notes' verb in the 'IC' tab to re-open this window.</i>
	</body></html>
	"}

	recipient << browse(replacetext(memory_stylized, "PLACEHOLDER", output),"window=memory;size=625x650")

/datum/mind/proc/edit_memory()
	if (!ticker)
		WWalert(current, "Not before round-start!", "Alert")
		return

	var/out = "<b>[name]</b>[(current&&(current.real_name!=name))?" (as [current.real_name])":""]<br>"
	out += "Mind currently owned by key: [key] [active?"(synced)":"(not synced)"]<br>"
	out += "Assigned role: [assigned_role]. <a href='?src=\ref[src];role_edit=1'>Edit</a><br>"
	out += "<hr>"
	out += "</table><hr>"

	usr << browse(out, "window=edit_memory[src]")

/datum/mind/Topic(href, href_list)
	if (!check_rights(R_ADMIN))	return

	else if (href_list["role_edit"])
		var/new_role = WWinput(usr, "Select new role", "Assigned role", assigned_role, WWinput_list_or_null(joblist))
		if (!new_role) return
		assigned_role = new_role

	else if (href_list["memory_edit"])
		var/new_memo = sanitize(WWinput(usr, "Write new memory", "Memory", memory, "text"))
		if (isnull(new_memo)) return
		memory = new_memo

	else if (href_list["common"])
		switch(href_list["common"])
			if ("undress")
				for (var/obj/item/W in current)
					current.drop_from_inventory(W)
			if ("takeuplink")
				take_uplink()
				memory = null//Remove any memory they may have had.

	edit_memory()

/datum/mind/proc/find_syndicate_uplink()
	return null

/datum/mind/proc/take_uplink()
	return FALSE


// check whether this mind's mob has been brigged for the given duration
// have to call this periodically for the duration to work properly
/datum/mind/proc/is_brigged(duration)
	return FALSE

/datum/mind/proc/reset()
	assigned_role =   null
	special_role =	null
	role_alt_title =  null
	assigned_job =	null
	//faction =	   null //Uncommenting this causes a compile error due to 'undefined type', fucked if I know.
//	objectives =	  list()
//	special_verbs =   list()
	has_been_rev =	FALSE
	rev_cooldown =	FALSE
	brigged_since =   -1

//Antagonist role check
/mob/living/proc/check_special_role(role)
	if (mind)
		if (!role)
			return mind.special_role
		else
			return (mind.special_role == role) ? TRUE : FALSE
	else
		return FALSE

//Initialisation procs
/mob/living/proc/mind_initialize()
	if (mind)
		mind.key = key
	else
		mind = new /datum/mind(key)
		mind.original = src
		if (ticker)
			ticker.minds += mind
		else
			world.log << "## DEBUG: mind_initialize(): No ticker ready yet! Please inform the coders."
	if (!mind.name)	mind.name = real_name
	mind.current = src

//HUMAN
/mob/living/human/mind_initialize()
	..()
	if (!mind.assigned_role)	mind.assigned_role = "Sailor"	//defualt