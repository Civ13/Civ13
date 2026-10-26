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

	// IC knowledge, not account preferences or editable player notes.
	// Null until first learning so the generic datum saver includes the list.
	var/list/learned_discoveries

	var/assigned_role
	var/special_role

	var/datum/job/assigned_job

	var/list/datum/objective/objectives = list()
	var/list/datum/objective/special_verbs = list()

	var/has_been_rev = FALSE//Tracks if this mind has been a rev or not

	var/datum/faction/faction 			//associated faction
	var/datum/changeling/changeling		//changeling holder

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
		GLOB.nanomanager.user_transferred(current, new_character) // transfer active NanoUI instances to new user

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

// Reject whole overlong fields: truncating an observation could change its meaning.
/datum/mind/proc/discovery_fields_valid(category, identity, context, label, observation)
	if (!istext(category) || !length(category) || length(category) > 64 || !istext(identity) || !length(identity) || length(identity) > 256)
		return FALSE
	if (!istext(context) || !length(context) || length(context) > 128 || !istext(label) || !length(label) || length(label) > 96 || !istext(observation) || !length(observation) || length(observation) > 256)
		return FALSE
	return TRUE

// Call only after an actual observation. No hidden effects, truncation or eviction.
// A rename is not new knowledge: keep the first label for this observation.
/datum/mind/proc/learn_discovery(category, identity, context, label, observation)
	if (!discovery_fields_valid(category, identity, context, label, observation))
		return FALSE
	var/discovery_key = md5(json_encode(list(category, identity, context, observation)))
	if (!islist(learned_discoveries))
		learned_discoveries = list()
	if (learned_discoveries[discovery_key] || learned_discoveries.len >= 256)
		return FALSE
	if (category == "berry_smell")
		var/berry_records = 0
		for (var/existing_key in learned_discoveries)
			if (!istext(existing_key) || length(existing_key) > 32)
				continue
			var/list/existing_record = learned_discoveries[existing_key]
			if (islist(existing_record) && existing_record["category"] == "berry_smell")
				berry_records++
		if (berry_records >= 64)
			return FALSE
	learned_discoveries[discovery_key] = list("category" = category, "identity" = identity, "context" = context, "label" = label, "observation" = observation)
	return TRUE

/datum/mind/proc/discoveries_html()
	var/output = "<br><br><b>Discoveries</b><br><br>"
	if (!islist(learned_discoveries) || !learned_discoveries.len)
		return output + "<i>No discoveries recorded.</i>"
	var/berry_context = berry_discovery_context()
	var/omitted = learned_discoveries.len > 256
	var/berry_records = 0
	// Bound inspected slots, not just valid output rows; imported lists may be bad.
	for (var/record_index = 1, record_index <= min(learned_discoveries.len, 256), record_index++)
		var/discovery_key = learned_discoveries[record_index]
		if (!istext(discovery_key) || length(discovery_key) > 32)
			omitted = TRUE
			continue
		var/list/record = learned_discoveries[discovery_key]
		if (!islist(record) || !discovery_fields_valid(record["category"], record["identity"], record["context"], record["label"], record["observation"]))
			omitted = TRUE
			continue
		output += "<b>[html_encode(record["label"])]</b>: [html_encode(record["observation"])]"
		if (record["category"] == "berry_smell")
			berry_records++
			output += "<br><i>Observation of a sample, not proof that these berries are safe to eat.</i>"
			if (!berry_context || record["context"] != berry_context)
				output += "<br><i>Historical observation: the world's berry configuration has changed or is unavailable.</i>"
		output += "<br><br>"
	if (learned_discoveries.len >= 256)
		output += "<i>Discovery notes are full (256 records). Existing knowledge is kept; new observations are not added. Personal notes remain available.</i><br>"
	if (berry_records >= 64)
		output += "<i>Berry smell notes are full (64 records). Existing observations are kept; other categories remain subject to the overall limit.</i><br>"
	if (omitted)
		output += "<i>Some stored discoveries exceed display limits or are invalid and are not shown. Stored records have not been changed.</i>"
	return output

/datum/mind/proc/store_memory(new_text)
	memory += "[new_text]<BR>"

/datum/mind/proc/show_memory(mob/recipient)
	if (!recipient || recipient.mind != src)
		return
	var/client/C = recipient.client
	if(!C)
		return
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

	output += discoveries_html()

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
	assigned_job =	null
	//faction =	   null //Uncommenting this causes a compile error due to 'undefined type', fucked if I know.
//	objectives =	  list()
//	special_verbs =   list()
	has_been_rev =	FALSE

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