// The Ides of March mode, headless (run.py).
/world
	maxx = 20
	maxy = 20
	maxz = 1
	turf = /turf/floor/plating/marble
	area = /area

/mob/living/human/ides_probe/New()
	return

var/im_failures = 0
/proc/im_check(cond, msg)
	if (!cond)
		im_failures++
	text2file("[cond ? "ok" : "FAIL"]: [msg]\n", "im_log.txt")

/world/Error(exception/e)
	im_check(FALSE, "runtime error [e] [e.file]:[e.line]")

/world/New()
	makeDatumRefLists()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new
	GLOB.dir_set_event = new
	GLOB.destroyed_event = new
	spawn(5)
		im_run()

/proc/im_run()
	try
		im_cases()
	catch (var/exception/e)
		im_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file("DONE\n", "im_log.txt")
	del(world)

/proc/im_cases()
	var/list/party = list(/datum/job/roman/ides/caesar, /datum/job/roman/ides/lictor, /datum/job/roman/ides/friend)
	var/list/plot = list(/datum/job/civilian/ides/brutus, /datum/job/civilian/ides/senator)
	for (var/path in party + plot)
		var/datum/job/J = new path
		im_check((MAP_IDES_OF_MARCH in J.allowed_maps), "[J.title] can be picked on the Ides of March")
		var/want = (path in party) ? "JoinLateIdesCaesar" : "JoinLateIdesSenate"
		im_check(J.spawn_location == want, "[J.title] spawns at [want]")
		im_check(J.base_type_flag() == ((path in party) ? ROMAN : CIVILIAN), "[J.title] is on the right side")
	var/datum/job/civilian/ides/senator/S = new
	im_check(S.default_language == "Latin", "the conspirators speak Latin")
	var/obj/item/weapon/material/kitchen/utensil/knife/dagger/iron/pugio/P = new(locate(1, 1, 1))
	im_check((P.slot_flags & SLOT_POCKET) && P.w_class <= ITEM_SIZE_SMALL, "a pugio fits in a pocket, out of sight")

	var/obj/map_metadata/ides_of_march/IM = new
	im_check(IM.faction1 == ROMAN && IM.faction2 == CIVILIAN, "Caesar's party and the conspirators are the two sides")
	im_check(!IM.caesar_fallen(), "no win for the conspirators before any Caesar has joined")
	var/mob/living/human/first = new /mob/living/human/ides_probe(locate(5, 5, 1))
	var/mob/living/human/second = new /mob/living/human/ides_probe(locate(6, 5, 1))
	IM.caesars |= first
	im_check(!IM.caesar_fallen(), "a living Caesar holds")
	first.stat = DEAD
	im_check(IM.caesar_fallen(), "the conspirators win when Caesar dies")
	IM.caesars |= second
	im_check(!IM.caesar_fallen(), "while any Caesar still lives the plot is not done")
	second.stat = DEAD
	im_check(IM.caesar_fallen(), "every Caesar dead ends it")
