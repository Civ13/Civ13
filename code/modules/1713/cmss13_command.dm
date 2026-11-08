// Dog tags, the round-end roll of the fallen and commander medals, adapted
// from CM-SS13 (cmss13-devs/cmss13, AGPL-3.0): dogtag.dm, the memorial and
// medal.dm awards. Reimplemented for Civ13; team rounds only.

/proc/team_round_active()
	return map && !map.civilizations

var/global/datum/fallen_roll/fallen_roll = new

/datum/fallen_roll
	var/list/fallen = list()     // faction -> list of names, in order of death
	var/list/recovered = list()  // faction -> names whose tags a comrade brought back
	var/list/trophies = list()   // faction -> tags the enemy took
	var/list/citations = list()  // text lines, in award order
	var/announced = FALSE

/datum/fallen_roll/proc/record_death(mob/living/human/H)
	if (!team_round_active() || !istype(H) || istype(H, /mob/living/human/corpse) || !H.faction_text)
		return FALSE
	var/name = round_fact_name(H)
	var/list/L = fallen[H.faction_text]
	if (!L)
		L = list()
		fallen[H.faction_text] = L
	if (name in L)
		return FALSE
	L += name
	return TRUE

/datum/fallen_roll/proc/record_tag(faction, name, by_comrade)
	var/list/target = by_comrade ? recovered : trophies
	var/list/L = target[faction]
	if (!L)
		L = list()
		target[faction] = L
	L |= name

/datum/fallen_roll/proc/lines()
	var/list/out = list()
	for (var/faction in fallen)
		var/list/names = fallen[faction]
		var/shown = names.len > 12 ? names.Copy(1, 13) : names
		var/more = names.len > 12 ? " and [names.len - 12] more" : ""
		var/list/back = recovered[faction]
		var/list/taken = trophies[faction]
		var/line = "<b>[faction]</b> lost [names.len]: [jointext(shown, ", ")][more]."
		if (back && back.len)
			line += " Tags brought home: [back.len]."
		if (taken && taken.len)
			line += " Tags taken by the enemy: [taken.len]."
		out += line
	return out

/datum/fallen_roll/proc/announce()
	if (announced)
		return FALSE
	announced = TRUE
	var/list/roll = lines()
	if (roll.len)
		to_chat(world, "<br><span class='notice'><big><b>The fallen</b></big></span>")
		for (var/line in roll)
			to_chat(world, "<span class='notice'>[line]</span>")
	if (citations.len)
		to_chat(world, "<br><span class='notice'><big><b>Medals awarded</b></big></span>")
		for (var/line in citations)
			to_chat(world, "<span class='notice'>[line]</span>")
	return roll.len || citations.len

/hook/death/proc/fallen_roll_death(mob/living/human/H, gibbed)
	if (fallen_roll)
		fallen_roll.record_death(H)
	return TRUE

/hook/roundend/proc/fallen_roll_announce()
	if (fallen_roll)
		fallen_roll.announce()
	return TRUE

//////////////////////////////////////////////////////////////////////////////
// DOG TAGS: right-click a fallen soldier > Take Dog Tags.
//////////////////////////////////////////////////////////////////////////////

/mob/living/human/var/tmp/dog_tags_taken = FALSE

/mob/living/human/persistence_runtime_var(key)
	return key == "dog_tags_taken" || ..()

/obj/item/weapon/dogtag
	name = "dog tags"
	desc = "A soldier's identity tags."
	icon = 'icons/obj/cmss13_ports.dmi'
	icon_state = "dogtag_taken"
	w_class = ITEM_SIZE_TINY
	var/tag_name = null
	var/tag_faction = null

/obj/item/weapon/dogtag/New(newloc, name, faction)
	..(newloc)
	if (name)
		tag_name = name
		tag_faction = faction
		self_name()

/obj/item/weapon/dogtag/proc/self_name()
	name = "[tag_name]'s dog tags"
	desc = "The identity tags of [tag_name][tag_faction ? ", [tag_faction]" : ""]. Taken from the body to confirm the death."

/mob/living/human/proc/can_take_dog_tags(mob/living/human/taker)
	return team_round_active() && istype(taker) && taker != src && stat == DEAD && !dog_tags_taken && faction_text && !istype(src, /mob/living/human/corpse)

/mob/living/human/proc/take_dog_tags_by(mob/living/human/taker)
	if (!can_take_dog_tags(taker))
		return null
	dog_tags_taken = TRUE
	var/name = round_fact_name(src)
	var/obj/item/weapon/dogtag/T = new(get_turf(taker), name, faction_text)
	taker.put_in_hands(T)
	var/comrade = taker.faction_text == faction_text
	if (fallen_roll)
		fallen_roll.record_tag(faction_text, name, comrade)
	return T

/mob/living/human/verb/take_dog_tags()
	set name = "Take Dog Tags"
	set category = null
	set src in view(1)
	var/mob/living/human/taker = usr
	if (!istype(taker) || taker.stat != CONSCIOUS || !taker.Adjacent(src))
		return
	if (!can_take_dog_tags(taker))
		to_chat(taker, "<span class='warning'>[dog_tags_taken ? "Someone has already taken these tags." : "You can only take the tags of a fallen soldier in a team round."]</span>")
		return
	if (!do_after(taker, 20, src))
		return
	if (take_dog_tags_by(taker))
		taker.visible_message("<span class='notice'>[taker] takes the dog tags from [src].</span>", "<span class='notice'>You take [src]'s dog tags.</span>")

//////////////////////////////////////////////////////////////////////////////
// MEDALS: commanders and officers pin a medal with a short citation.
//////////////////////////////////////////////////////////////////////////////

#define MEDALS_PER_OFFICER 3

/mob/living/human/var/tmp/medals_awarded = 0

/mob/living/human/persistence_runtime_var(key)
	return key == "medals_awarded" || ..()

/proc/medal_can_award(mob/living/human/H)
	return team_round_active() && istype(H) && H.original_job && (H.original_job.is_commander || H.original_job.is_officer)

/mob/living/human/proc/make_medal_awarder()
	if (medal_can_award(src))
		verbs |= /mob/living/human/proc/Award_Medal

/proc/medal_type_for(grade)
	switch (grade)
		if ("Gold")
			return /obj/item/clothing/accessory/medal/gold
		if ("Silver")
			return /obj/item/clothing/accessory/medal/silver
	return /obj/item/clothing/accessory/medal/bronze

// Returns the medal, or a text reason it could not be awarded.
/mob/living/human/proc/award_medal_to(mob/living/human/R, grade, citation)
	if (!medal_can_award(src))
		return "Only commanders and officers can award medals, in team rounds."
	if (!istype(R) || R == src || R.stat == DEAD || R.faction_text != faction_text)
		return "Medals go to a living soldier of your own side."
	if (medals_awarded >= MEDALS_PER_OFFICER)
		return "You have already awarded [MEDALS_PER_OFFICER] medals this round."
	citation = trim(sanitize(citation, 140))
	if (!citation)
		return "Write a short citation."
	var/path = medal_type_for(grade)
	var/obj/item/clothing/accessory/medal/M = new path(get_turf(R))
	M.name = "[lowertext(grade)] medal of [round_fact_name(R)]"
	M.desc = "Awarded to [round_fact_name(R)] by [round_fact_name(src)]: \"[citation]\""
	if (!R.put_in_hands(M))
		M.forceMove(get_turf(R))
	medals_awarded++
	if (round_facts)
		round_facts.medals_received[round_fact_name(R)] = (round_facts.medals_received[round_fact_name(R)] || 0) + 1
	if (fallen_roll)
		fallen_roll.citations += "[grade] medal to <b>[round_fact_name(R)]</b> ([faction_text]) from [round_fact_name(src)]: \"[citation]\""
	return M

/mob/living/human/proc/Award_Medal()
	set category = "Officer"
	set name = "Award Medal"
	set desc = "Pin a medal with a short citation on a soldier of your side next to you. Citations are read out at the end of the round."
	var/list/choices = list()
	for (var/mob/living/human/R in oview(1, src))
		if (R.stat != DEAD && R.faction_text == faction_text)
			choices[round_fact_name(R)] = R
	if (!choices.len)
		to_chat(src, "<span class='warning'>Stand next to the soldier you want to decorate.</span>")
		return
	var/who = input(src, "Award a medal to whom?", "Award Medal") as null|anything in choices
	if (!who)
		return
	var/grade = WWinput(src, "Which medal?", "Award Medal", "Bronze", list("Bronze", "Silver", "Gold", "Cancel"))
	if (grade == "Cancel")
		return
	var/citation = input(src, "Citation, up to 140 letters. It is read out at the end of the round.", "Award Medal") as text|null
	var/mob/living/human/R = choices[who]
	if (!R || !Adjacent(R))
		to_chat(src, "<span class='warning'>[who] is no longer next to you.</span>")
		return
	var/result = award_medal_to(R, grade, citation)
	if (istext(result))
		to_chat(src, "<span class='warning'>[result]</span>")
		return
	visible_message("<span class='notice'>[src] pins a [lowertext(grade)] medal on [R].</span>")

#undef MEDALS_PER_OFFICER
