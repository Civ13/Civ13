// Native probe: playstyle traits change the numbers they promise.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/character_traits/playstyle_probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 20
	maxy = 20
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/ps_probe/New()
	return
/mob/living/human/ps_probe/New()
	return
/mob/living/human/ps_probe/update_icons()
	return

var/ps_failures = 0
var/ps_runtime_error = FALSE
/proc/ps_check(condition, label)
	if (!condition)
		ps_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	ps_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/ps_probe
		ps_checks()
	catch(var/exception/e)
		ps_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = ps_failures, "runtime_error" = ps_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/ps_human(x, y, trait = null)
	var/mob/living/human/ps_probe/H = new(locate(x, y, 1))
	H.stat = CONSCIOUS
	H.mood_modifier = 1
	H.stats = list("strength" = list(100, 100), "crafting" = list(100, 100), "swords" = list(100, 100), "rifle" = list(100, 100), "farming" = list(100, 100), "hunting" = list(100, 100), "stamina" = list(100, 100), "dexterity" = list(100, 100), "philosophy" = list(100, 100), "medical" = list(100, 100), "pistol" = list(100, 100), "bows" = list(100, 100), "machinegun" = list(100, 100), "throwing" = list(100, 100), "magic" = list(0, 0))
	H.traits = trait ? list(trait) : list()
	H.traits_dirty = TRUE
	return H

/proc/ps_gain(mob/living/human/H, stat)
	H.stats[stat] = list(100, 100)
	H.adaptStat(stat, 10)
	return H.stats[stat][1] - 100

/proc/ps_checks()
	var/mob/living/human/plain = ps_human(1, 1)
	var/base_swords = ps_gain(plain, "swords")
	var/base_crafting = ps_gain(plain, "crafting")
	var/base_farming = ps_gain(plain, "farming")
	var/base_rifle = ps_gain(plain, "rifle")
	var/base_hunting = ps_gain(plain, "hunting")
	ps_check(plain.trait_skill_gain_mult("swords") == 1 && plain.recluse_rate() == 1 && plain.pull_drag_mult() == 1 && plain.trait_pain_mult() == 1 && plain.trait_food_mult() == 1, "no trait changes nothing")
	plain.loc = null

	var/mob/living/human/F = ps_human(10, 10, "Hardened Fighter")
	ps_check(ps_gain(F, "swords") > base_swords, "fighter trains swords faster ([base_swords])")
	ps_check(ps_gain(F, "crafting") < base_crafting, "fighter trains crafting slower")
	ps_check(F.trait_pain_mult() == 0.85, "fighter feels less pain")
	ps_check(F.trait_scholarship_gain_mult("engineering") == 0.75, "fighter learns scholarship slower")
	F.loc = null

	var/mob/living/human/G = ps_human(10, 10, "Green Thumb")
	ps_check(ps_gain(G, "farming") > base_farming, "green thumb trains farming faster")
	ps_check(ps_gain(G, "hunting") < base_hunting && ps_gain(G, "rifle") < base_rifle, "green thumb trains hunting and combat slower")
	ps_check(harvest_skill_user_bonus(G, "farming") >= 0.1, "green thumb harvests more")
	G.stats["hunting"] = list(100, 100)
	ps_check(harvest_skill_user_bonus(G, "hunting") == 0, "green thumb leaves butchering alone")
	G.loc = null

	var/mob/living/human/Q = ps_human(10, 10, "Quartermaster")
	ps_check(Q.pull_drag_mult() == 0.6, "quartermaster drags 40% less")
	ps_check(ps_gain(Q, "rifle") < base_rifle, "quartermaster trains combat slower")
	ps_check(ps_gain(Q, "farming") == base_farming, "quartermaster farming unchanged")
	Q.loc = null

	var/mob/living/human/T = ps_human(10, 10, "Tinkerer")
	var/mob/living/human/plain2 = ps_human(1, 1)
	ps_check(abs(T.getStatCoeff("crafting") - plain2.getStatCoeff("crafting") * 1.1) < 0.001, "tinkerer crafting x1.1")
	ps_check(abs(T.getStatCoeff("strength") - plain2.getStatCoeff("strength") * 0.9) < 0.001, "tinkerer strength x0.9")
	ps_check(T.trait_scholarship_gain_mult("engineering") == 1.5 && T.trait_scholarship_gain_mult("medicine") == 1, "tinkerer learns engineering faster")
	T.loc = null
	plain2.loc = null

	var/mob/living/human/R = ps_human(10, 10, "Recluse Scholar")
	ps_check(R.recluse_rate() == 1.25, "recluse alone is faster")
	var/mob/living/human/visitor = ps_human(12, 10)
	ps_check(R.recluse_rate() == 0.8, "recluse with company is slower")
	visitor.stat = DEAD
	ps_check(R.recluse_rate() == 1.25, "the dead are no company")
	visitor.loc = null
	R.loc = null

	var/mob/living/human/W = ps_human(10, 10, "Wanderer")
	ps_check(W.trait_food_mult() == 0.9, "wanderer eats less")
	W.last_movement = world.time
	ps_check(W.trait_stamina_recovery_mult() == 1.5, "wanderer recovers faster on the move")
	W.last_movement = -1
	ps_check(W.trait_stamina_recovery_mult() == 1, "wanderer standing still recovers normally")
	W.handle_wanderer()
	ps_check(W.wander_anchor == get_turf(W), "wanderer anchors where they are")
	W.loc = null

	var/mob/living/human/M = ps_human(10, 10, "Menacing")
	var/mob/living/human/victim = ps_human(12, 10)
	victim.mood = 50
	ps_check(M.tutor_rate() == 1.25 && victim.tutor_rate() == SCHOLAR_TUTOR_RATE, "menacing tutors slower")
	ps_check(!M.intimidate_problem() && victim.intimidate_problem(), "only the menacing can intimidate")
	ps_check(victim in M.intimidate_targets(), "nearby people can be intimidated")
	M.do_intimidate(victim)
	ps_check(victim.mood == 48, "intimidation sours mood a little ([victim.mood])")
	ps_check(M.intimidate_problem(), "intimidation has a cooldown")
	M.last_intimidate = -1000
	M.do_intimidate(victim)
	ps_check(victim.mood == 48, "the same person is not soured twice in a row")
	victim.loc = null
	M.loc = null

	var/mob/living/human/V = ps_human(10, 10, "Rallying Voice")
	var/mob/living/human/friend = ps_human(12, 10)
	friend.mood = 50
	V.rally_shout()
	ps_check(friend.mood == 51, "a rallying shout lifts a listener ([friend.mood])")
	V.rally_shout()
	ps_check(friend.mood == 51, "listeners are lifted at most once per cooldown")
	friend.civilization = "Rivals"
	V.civilization = "Friends"
	friend.last_rallied = -10000
	V.rally_shout()
	ps_check(friend.mood == 51, "rival factions are not rallied")
	var/mob/living/human/plain3 = ps_human(14, 10)
	friend.last_rallied = -10000
	friend.civilization = "none"
	plain3.rally_shout()
	ps_check(friend.mood == 51, "an ordinary shout rallies no one")

	var/mob/living/human/W2 = ps_human(10, 10, "Wanderer")
	W2.stats["stamina"] = list(10, 100)
	W2.last_movement = world.time
	W2.wanderer_recover_stamina()
	ps_check(W2.stats["stamina"][1] == 11, "wanderer on the move gets extra stamina ([W2.stats["stamina"][1]])")
	W2.last_movement = -1
	W2.wanderer_recover_stamina()
	ps_check(W2.stats["stamina"][1] == 11, "resting wanderer gets no extra stamina")
