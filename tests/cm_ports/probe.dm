/world
	hub = ""
	hub_password = ""
	maxx = 30
	maxy = 30
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
var/probe_failures = 0
var/probe_checks = 0
var/probe_runtime_error = FALSE
/obj/map_metadata/cm_ports_probe/New()
	return
/proc/probe_check(condition, label)
	probe_checks++
	if (!condition)
		probe_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	probe_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.stat_set_event = new
		movementMachine = new
		map = new /obj/map_metadata/cm_ports_probe
		if (!all_species.len)
			makeDatumRefLists()
		for (var/turf/T in block(locate(1, 1, 1), locate(30, 30, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		cm_ports_checks()
	catch(var/exception/e)
		probe_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("checks" = probe_checks, "failures" = probe_failures, "runtime_error" = probe_runtime_error)), "result.json")
	del(world)

/proc/probe_human(x, y, name)
	var/mob/living/human/H = new(locate(x, y, 1))
	H.name = name
	H.real_name = name
	return H

/proc/cm_ports_checks()
	blurb_checks()
	balloon_checks()
	round_fact_checks()
	canopy_checks()
	holiday_checks()

/proc/blurb_checks()
	map.title = "Probe Valley"
	map.age = "1713"
	season = "WINTER"
	var/area/A = get_area(locate(1, 1, 1))
	A.name = "Old Mill"
	var/text = location_blurb_text(A)
	probe_check(findtext(text, "Winter 1713"), "the blurb names the season and year: [text]")
	probe_check(findtext(text, "Probe Valley, Old Mill"), "the blurb names the map and area")
	probe_check(findtext(text, "\n"), "the blurb has two lines")
	A.name = "Probe Valley"
	probe_check(!findtext(location_blurb_text(A), "Probe Valley, Probe Valley"), "an area named like the map is not repeated")
	season = "Wet Season"
	probe_check(findtext(location_blurb_text(A), "Wet Season 1713"), "mixed-case seasons are kept")
	var/mob/living/human/H = probe_human(3, 3, "Blurb")
	probe_check(!H.show_location_blurb(), "no blurb without a client")

/proc/balloon_checks()
	var/mob/living/human/H = probe_human(4, 4, "Balloon")
	probe_check(!H.balloon_alert(H, "empty"), "no balloon without a client")
	probe_check(balloon_alert_lifetime("empty") == 10, "short balloons last one second")
	probe_check(balloon_alert_lifetime("a much longer balloon line") > 10, "long balloons stay longer")
	probe_check(H.balloon_alert_to_viewers("HOLD!") == 0, "viewers without clients get no balloon")

/proc/round_fact_checks()
	var/datum/round_facts/F = new
	var/mob/living/human/A = probe_human(5, 5, "Alice")
	var/mob/living/human/B = probe_human(6, 5, "Bob")
	var/mob/living/human/C = probe_human(7, 5, "Carol")
	probe_check(!F.fact_lines().len, "a quiet round has no facts")
	for (var/i = 1 to 25)
		F.record_shot(A)
	F.record_hit(A, A, "rifle")
	probe_check(A.lastattacker != A, "hurting yourself does not count")
	F.record_hit(B, A, "musket")
	F.record_death(B)
	F.record_hit(C, A, "musket")
	F.record_death(C)
	for (var/i = 1 to 3)
		F.record_death(B)
	probe_check(F.kills["Alice"] == 2, "kills are credited to the last attacker, once per body")
	var/mob/living/human/D = probe_human(8, 5, "Dave")
	F.record_hit(D, A, "musket")
	D.round_fact_hit_time = world.time - 601
	F.record_death(D)
	probe_check(F.kills["Alice"] == 2, "a hit more than a minute before death earns no kill")
	probe_check(F.first_blood_victim == "Bob" && F.first_blood_killer == "Alice" && F.first_blood_weapon == "musket", "first blood records killer, victim and weapon")
	var/joined = jointext(F.fact_lines(), "|")
	probe_check(findtext(joined, "First blood: <b>Alice</b> killed <b>Bob</b> with a musket"), "first blood line: [joined]")
	probe_check(findtext(joined, "Most kills: <b>Alice</b>, with 2 kills"), "most kills line")
	probe_check(findtext(joined, "Deadliest weapon: the <b>musket</b>, with 2 kills"), "deadliest weapon line")
	probe_check(findtext(joined, "fired 25 shots"), "most shots line")
	probe_check(findtext(joined, "<b>Bob</b>, who died 4 times"), "most deaths line")
	probe_check(F.announce() && !F.announce(), "facts are announced once")
	probe_check(A.persistence_runtime_var("round_fact_weapon") && A.persistence_runtime_var("round_fact_hit_time") && A.persistence_runtime_var("round_fact_counted"), "kill credit state is never saved")
	var/before = round_facts.deaths["Carol"] || 0
	C.lastattacker = null
	C.death()
	probe_check((round_facts.deaths["Carol"] || 0) == before + 1, "a real death reaches the round facts through the death hook")

/proc/canopy_checks()
	var/turf/open = locate(20, 20, 1)
	var/turf/covered = locate(21, 20, 1)
	new /obj/structure/tent(covered)
	probe_check(!under_canopy(open) && under_canopy(covered), "a canopy marks its tile as sheltered")
	probe_check(canopy_shelter_temperature(open, -10) == -10, "open ground is not warmed")
	probe_check(canopy_shelter_temperature(covered, -10) == -5, "a canopy is 5 C warmer in the cold")
	probe_check(canopy_shelter_temperature(covered, 12) == 15, "canopy warmth stops at 15 C")
	probe_check(canopy_shelter_temperature(covered, 25) == 25, "a canopy does not change mild air")

/proc/holiday_checks()
	var/datum/holiday/H = holiday_for_date(12, 25)
	probe_check(istype(H, /datum/holiday/christmas) && H.gives_gift, "Christmas Day is Christmas and gives gifts")
	probe_check(istype(holiday_for_date(12, 24), /datum/holiday/christmas) && istype(holiday_for_date(12, 26), /datum/holiday/christmas), "Christmas runs 24 to 26 December")
	probe_check(istype(holiday_for_date(10, 31), /datum/holiday/halloween), "31 October is Halloween")
	probe_check(istype(holiday_for_date(12, 31), /datum/holiday/new_years_eve), "31 December is New Year's Eve")
	probe_check(istype(holiday_for_date(1, 1), /datum/holiday/new_year), "1 January is New Year")
	probe_check(isnull(holiday_for_date(7, 4)), "an ordinary day has no holiday")
	var/mob/living/human/P = probe_human(10, 20, "Gifted")
	probe_check(!P.holiday_login(H), "no greeting or gift without a client")
	var/obj/item/weapon/holiday_gift/G = new(P.loc)
	P.put_in_hands(G)
	G.attack_self(P)
	var/obj/item/treat = P.get_active_hand()
	probe_check(G.gcDestroyed || !G.loc, "opening a gift uses it up")
	probe_check(istype(treat, /obj/item/weapon/reagent_containers/food/snacks/cookie) || istype(treat, /obj/item/weapon/reagent_containers/food/snacks/chocolatebar), "a gift holds a treat that lands in hand")
