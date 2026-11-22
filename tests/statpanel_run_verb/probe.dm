// Native probe for /client/proc/run_verb (code/modules/statpanel/statpanel.dm).
// run.py transplants the real proc onto /obj/run_verb_probe and swaps winset()
// for record_command(). The probe object stands in for the client: its own
// verbs are scanned first, then the mob's, as on a real client.
/world
	hub = ""
	visibility = 0
	maxx = 1
	maxy = 1
	maxz = 1

/client/New()
	del(src)

/obj/run_verb_probe
	var/mob/mob
	var/holder = null
	var/last_command = ""

/obj/run_verb_probe/proc/record_command(params)
	last_command = params

#define R_ADMIN 1

/datum/admins

/proc/check_rights()
	return FALSE

// Client-side verbs, as in code/modules/client/client_verbs.dm.
/obj/run_verb_probe/verb/open_web_crafting_atlas()
	set name = "Open Web Crafting Atlas"
	set category = "Help!"

/obj/run_verb_probe/verb/open_embed_wiki()
	set name = "Open Wiki"
	set category = "Help!"

/obj/run_verb_probe/verb/dont_panic()
	set name = "Don't Panic"
	set category = "Help!"

/obj/run_verb_probe/verb/unlisted_button()
	set name = "Unlisted Button"
	set category = null

// The in-game atlas, as in code/game/mob/crafting_atlas.dm.
/mob/verb/crafting_atlas()
	set name = "Crafting Atlas"
	set category = "IC"

/world/New()
	..()
	var/obj/run_verb_probe/P = new
	P.mob = new /mob
	var/list/result = list()
	for (var/name in list("Crafting Atlas", "Open Web Crafting Atlas", "Open Wiki", "Don't Panic", "Unknown Button", "unknown_button", "Unlisted Button"))
		P.last_command = ""
		var/accepted = P.run_verb(name)
		result[name] = list("accepted" = !!accepted, "command" = P.last_command)
	text2file(json_encode(result), "result.json")
	shutdown()
