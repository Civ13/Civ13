// Death notices for ghosts, last words when succumbing and the time since
// death on a body. Ideas from CM-SS13 (cmss13-devs/cmss13, AGPL-3.0): the
// observer death announcements, last words on succumb and the "dead for"
// line when examining a corpse. Reimplemented for Civ13.

//////////////////////////////////////////////////////////////////////////////
// DEATH NOTICES: ghosts hear who died and where, with a link to follow.
//////////////////////////////////////////////////////////////////////////////

/client/var/tmp/no_death_notices = FALSE

/proc/death_notice_text(mob/living/human/H, mob/observer/ghost/G)
	var/area/A = get_area(H)
	var/where = A ? " in [A.name]" : ""
	var/link = G ? " (<a href='?src=\ref[G];track=\ref[H]'>follow</a>)" : ""
	return "<span class='deadsay'><b>[round_fact_name(H)]</b> has died[where].[link]</span>"

// Only player characters: a body with a mind or a key.
/proc/death_notice_wanted(mob/living/human/H)
	return istype(H) && !istype(H, /mob/living/human/corpse) && (H.mind || H.ckey)

/proc/send_death_notices(mob/living/human/H)
	var/n = 0
	if (!death_notice_wanted(H))
		return n
	for (var/mob/observer/ghost/G in dead_mob_list)
		if (!G.client || G.client.no_death_notices)
			continue
		if (G.mind && G.mind.current == H)
			continue
		to_chat(G, death_notice_text(H, G))
		n++
	return n

/hook/death/proc/ghost_death_notices(mob/living/human/H, gibbed)
	send_death_notices(H)
	return TRUE

/mob/observer/ghost/verb/toggle_death_notices()
	set name = "Toggle Death Notices"
	set category = "Ghost"
	set desc = "Hear who dies and where while you watch."
	if (!client)
		return
	client.no_death_notices = !client.no_death_notices
	to_chat(src, "<span class='notice'>Death notices [client.no_death_notices ? "off" : "on"].</span>")

//////////////////////////////////////////////////////////////////////////////
// LAST WORDS: succumbing lets you say one final line to those nearby.
//////////////////////////////////////////////////////////////////////////////

#define LAST_WORDS_MAX 120

/datum/fallen_roll/var/list/last_words = list() // name -> text, team rounds

/proc/clean_last_words(text)
	text = trim(sanitize(text, LAST_WORDS_MAX))
	return length(text) ? text : null

/mob/living/human/proc/say_last_words(text)
	text = clean_last_words(text)
	if (!text)
		return null
	for (var/mob/M in hearers(3, get_turf(src)))
		to_chat(M, "<span class='notice'><b>[real_name]</b> whispers with a last breath, \"[text]\"</span>")
	if (team_round_active() && fallen_roll && faction_text)
		fallen_roll.last_words[round_fact_name(src)] = text
	log_say("[key_name(src)] last words: [text]")
	return text

/mob/living/human/succumb()
	if (map && map.ID == MAP_WIZARD_BOY)
		var/area/H_area = get_area(src)
		if (H_area && istype(H_area, /area/caribbean/houses/nml_three))
			to_chat(src, "<span class = 'notice'>You cannot succumb while in prison.</span>")
			return
	if (getTotalDmg() <= 50)
		to_chat(src, "<span class = 'notice'>You can only succumb when you are badly hurt (more than 50 total damage). You have [round(getTotalDmg())].</span>")
		return
	if (WWinput(src, "Are you sure you want to succumb? You only live once.", "", "Cancel", list("Succumb", "Cancel")) != "Succumb")
		return
	if (stat == DEAD)
		return
	var/words = player_input(src, "Any last words? Leave it empty to say nothing.", "Last Words", null, "text", null, TRUE)
	if (stat == DEAD)
		return
	if (words)
		say_last_words(words)
	adjustBrainLoss(300)
	death()
	to_chat(src, "<span class = 'notice'>You have given up life and succumbed to death.</span>")

/datum/fallen_roll/proc/last_words_lines()
	var/list/out = list()
	var/shown = 0
	for (var/name in last_words)
		if (++shown > 6)
			break
		out += "<b>[name]</b>: \"[last_words[name]]\""
	return out

/hook/roundend/proc/announce_last_words()
	if (!fallen_roll)
		return TRUE
	var/list/lines = fallen_roll.last_words_lines()
	if (lines.len)
		to_chat(world, "<br><span class='notice'><big><b>Last words</b></big></span>")
		for (var/line in lines)
			to_chat(world, "<span class='notice'>[line]</span>")
	return TRUE

#undef LAST_WORDS_MAX

//////////////////////////////////////////////////////////////////////////////
// TIME SINCE DEATH: examining a body gives a rough time; medics also learn
// whether a defibrillator could still help.
//////////////////////////////////////////////////////////////////////////////

/proc/time_since_death_text(deciseconds)
	var/minutes = round(deciseconds / 600)
	if (minutes < 1)
		return "moments ago"
	if (minutes < 60)
		return "about [minutes] minute\s ago"
	var/hours = round(minutes / 60)
	return "about [hours] hour\s ago"

/mob/living/human/proc/revivable_now()
	if (stat != DEAD || !species)
		return FALSE
	if (!species.has_organ["brain"])
		return TRUE
	var/obj/item/organ/brain/B = internal_organs_by_name["brain"]
	return B && B.damage < 60 && B.defib_timer > 0

/mob/living/human/proc/death_time_lines(mob/user)
	var/list/out = list()
	if (stat != DEAD || !timeofdeath || timeofdeath > world.time)
		return out
	out += "[src] died [time_since_death_text(world.time - timeofdeath)]."
	if (ishuman(user) && can_triage(user))
		out += revivable_now() ? "A defibrillator might still bring them back." : "It is too late to revive them."
	return out

/mob/living/human/examine(mob/user)
	. = ..()
	if (user && user != src && get_dist(user, src) <= 1)
		for (var/line in death_time_lines(user))
			to_chat(user, "<span class='notice'>[line]</span>")
