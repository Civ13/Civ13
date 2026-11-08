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
	second_batch_checks()
	third_batch_checks()
	fourth_batch_checks()
	fifth_batch_checks()

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

/proc/second_batch_checks()
	// Megaphone
	var/mob/living/human/S = probe_human(2, 25, "Speaker")
	probe_check(S.speech_range_bonus(7) == 7, "normal speech range without a megaphone")
	var/obj/item/weapon/megaphone/M = new(S.loc)
	S.put_in_hands(M)
	probe_check(S.speech_range_bonus(7) == 14, "a megaphone in hand doubles speech range")

	// Glowstick
	var/obj/item/flashlight/flare/glowstick/blue/G = new(locate(3, 25, 1))
	probe_check(G.fuel == 1800 && !G.on, "a new glowstick has 30 minutes and is dark")
	G.attack_self(S)
	probe_check(G.on && G.icon_state == "glowstick_blue_on" && (G in processing_objects), "bending a glowstick lights it")
	probe_check(!G.attack_self(S), "a lit glowstick cannot be switched off")
	G.fuel = 1
	G.process_interval(2)
	probe_check(G.burnt_out && !G.on && findtext(G.name, "spent"), "a glowstick burns out when its fuel runs out")
	probe_check(!G.attack_self(S), "a spent glowstick cannot be relit")

	// Labels
	var/obj/structure/closet/crate/C = new(locate(4, 25, 1))
	var/base = C.name
	probe_check(C.set_container_label("Grain") && C.name == "[base] (Grain)" && C.container_label == "Grain", "a label is added to the name")
	probe_check(C.set_container_label("") && C.name == base && !C.container_label, "an empty label restores the name")
	C.set_container_label("abcdefghijklmnopqrstuvwxyz0123")
	probe_check(length(C.container_label) <= 24, "labels are capped at 24 characters")

	// Display case
	var/obj/structure/display_case/D = new(locate(5, 25, 1))
	var/mob/living/human/O = probe_human(5, 24, "Collector")
	var/obj/item/weapon/whistle/W = new(O.loc)
	O.put_in_hands(W)
	D.attackby(W, O)
	probe_check(D.shown_item() == W && W.loc == D, "an item goes into the case")
	var/obj/item/weapon/key/K = new(O.loc)
	K.code = 4242
	D.attackby(K, O)
	probe_check(D.locked && D.custom_code == 4242, "a key locks the case")
	D.attack_hand(O)
	probe_check(W.loc == D, "a locked case keeps its item")
	D.attackby(K, O)
	D.attack_hand(O)
	probe_check(!D.locked && W.loc != D && !D.shown_item(), "an unlocked case gives the item back")

	// Tripwire
	var/obj/structure/tripwire_alarm/T = new(locate(8, 25, 1))
	var/mob/living/human/setter = probe_human(9, 25, "Setter")
	setter.faction_text = "Red"
	T.set_owner(setter)
	var/mob/living/human/friend = probe_human(10, 25, "Friend")
	friend.faction_text = "Red"
	var/mob/living/human/stranger = probe_human(11, 25, "Stranger")
	stranger.faction_text = "Blue"
	probe_check(!T.trip(setter) && !T.trip(friend), "the setter's side walks through quietly")
	probe_check(T.trip(stranger), "a stranger sets off the alarm")
	probe_check(!T.trip(stranger), "the alarm does not rattle again within 3 seconds")
	probe_check(T.persistence_runtime_var("next_rattle"), "the rattle cooldown is not saved")

	// Rally flag
	var/mob/living/human/L = probe_human(15, 15, "Flag Leader")
	L.faction_text = "Green"
	var/datum/job/J = new
	J.is_squad_leader = TRUE
	L.original_job = J
	var/mob/living/human/A = probe_human(15, 23, "Flag Ally")
	A.faction_text = "Green"
	probe_check(!L.leader_order_near_flag(), "no flag nearby at first")
	new /obj/structure/flag/pole(locate(16, 15, 1))
	probe_check(!L.leader_order_near_flag(), "a bare flagpole is not a rally flag")
	new /obj/structure/flag/white(locate(16, 16, 1))
	probe_check(L.leader_order_near_flag(), "a flag within 2 tiles counts")
	probe_check(L.issue_leader_order("move") == 2 && A.order_move_strength == 1.5, "an order by a flag gains half a strength and reaches 9 tiles")

	// Codebook
	var/list/red = codebook_pairs("Red")
	var/list/blue = codebook_pairs("Blue")
	probe_check(red.len == 10 && codebook_pairs("Red") == red, "a side keeps the same ten codes all round")
	var/list/flat = list()
	for (var/list/pair in red)
		flat |= pair
	probe_check(flat.len == 20, "every call and response is different")
	probe_check(red[1][1] != blue[1][1] || red[1][2] != blue[1][2], "sides get different codes")
	var/obj/item/weapon/paper/codebook/CB = new(locate(20, 25, 1), "Red")
	probe_check(findtext(CB.info, red[1][1]) && findtext(CB.info, red[1][2]) && CB.name == "Red codebook", "the codebook lists the side's codes")
	var/mob/living/human/officer = probe_human(21, 25, "Officer")
	officer.faction_text = "Red"
	var/datum/job/OJ = new
	OJ.is_officer = TRUE
	officer.original_job = OJ
	var/obj/item/weapon/paper/codebook/given = officer.give_codebook()
	probe_check(istype(given) && given.code_faction == "Red", "officers get their side's codebook in team rounds")
	var/mob/living/human/private = probe_human(22, 25, "Private")
	private.faction_text = "Red"
	private.original_job = new /datum/job
	probe_check(!private.give_codebook(), "ordinary soldiers get no codebook")

	// Emote panel
	var/datum/emote_panel/P = new(S)
	var/list/acts = emote_panel_acts()
	var/html = P.html()
	var/links = 0
	var/pos = findtext(html, "emote=")
	while (pos)
		links++
		pos = findtext(html, "emote=", pos + 1)
	probe_check(links == acts.len && !("point" in acts) && !("custom" in acts), "the panel lists every simple emote and no targeted ones")

/proc/third_batch_checks()
	// Bipod
	var/mob/living/human/gunner = probe_human(3, 5, "Gunner")
	var/obj/item/weapon/gun/projectile/submachinegun/m16/ar15/R = new(gunner.loc)
	gunner.put_in_hands(R)
	var/obj/item/weapon/attachment/under/bipod/B = new(gunner.loc)
	probe_check(R.configuration_compatible(B), "a bipod fits a rifle's underbarrel rail")
	probe_check(R.install_configuration(B, null, TRUE) && R.has_bipod(), "a bipod can be fitted")
	gunner.dir = NORTH
	gunner.last_movement = -1
	probe_check(!R.bipod_braced(gunner), "standing in the open the bipod does nothing")
	probe_check(R.bipod_recoil_mult(gunner) == 1, "no recoil change unbraced")
	gunner.prone = TRUE
	probe_check(R.bipod_braced(gunner), "lying prone braces the bipod")
	probe_check(R.bipod_recoil_mult(gunner) < 1 && R.bipod_accuracy_mult(gunner) < 1, "a braced bipod cuts recoil and spread")
	gunner.last_movement = world.time
	probe_check(!R.bipod_braced(gunner), "moving unbraces the bipod")
	gunner.prone = FALSE
	gunner.last_movement = -1
	var/turf/front = locate(3, 6, 1)
	front.density = TRUE
	probe_check(R.bipod_braced(gunner), "a wall ahead braces the bipod")
	gunner.dir = SOUTH
	probe_check(!R.bipod_braced(gunner), "facing away from the wall does not")
	front.density = FALSE
	var/obj/item/weapon/gun/projectile/submachinegun/m16/ar15/plain = new(locate(4, 5, 1))
	probe_check(!plain.bipod_braced(gunner), "a gun without a bipod is never braced")

	// Ammo count
	probe_check(R.ammo_count_text() == "empty", "an empty gun counts as empty")

	// Floor exercise
	var/mob/living/human/athlete = probe_human(6, 5, "Athlete")
	athlete.stats["strength"] = list(100, 100)
	probe_check(!athlete.floor_exercise_ready("push-ups"), "floor exercise stops at 100")
	athlete.stats["strength"] = list(40, 40)
	athlete.stats["stamina"] = list(40, 40)
	athlete.exercise_fatigue = 0
	probe_check(athlete.floor_exercise_ready("push-ups") && athlete.floor_exercise_ready("sit-ups"), "a fresh athlete can exercise on the floor")
	probe_check(floor_exercise_skill("push-ups") == "strength" && floor_exercise_skill("sit-ups") == "stamina", "push-ups train strength and sit-ups stamina")
	athlete.exercise_fatigue = 6
	probe_check(!athlete.floor_exercise_ready("sit-ups"), "fatigue blocks floor exercise")
	probe_check(athlete.persistence_runtime_var("floor_exercise_busy"), "an exercise in progress is not saved")

	// Lockbox
	var/mob/living/human/owner = probe_human(8, 5, "Owner")
	var/obj/item/weapon/storage/lockbox/LB = new(owner.loc)
	var/obj/item/weapon/key/K = new(owner.loc)
	K.code = 777
	var/obj/item/weapon/key/wrong = new(owner.loc)
	wrong.code = 778
	var/obj/item/weapon/coin = new /obj/item/weapon/whistle(owner.loc)
	probe_check(LB.can_be_inserted(coin, TRUE), "an unlocked lockbox takes small items")
	LB.attackby(K, owner)
	probe_check(LB.locked && LB.custom_code == 777 && LB.icon_state == "lockbox_locked", "the first key locks it and becomes its key")
	probe_check(!LB.can_be_inserted(coin, TRUE), "a locked lockbox takes nothing")
	LB.attackby(wrong, owner)
	probe_check(LB.locked, "the wrong key does nothing")
	LB.attackby(K, owner)
	probe_check(!LB.locked && LB.icon_state == "lockbox", "its key unlocks it")
	LB.attackby(K, owner)
	owner.a_intent = I_HARM
	var/obj/item/weapon/hammer = new /obj/item/weapon/whistle(owner.loc)
	hammer.force = 15
	for (var/i = 1 to 4)
		LB.attackby(hammer, owner)
	probe_check(LB.broken && !LB.locked && LB.icon_state == "lockbox_broken", "four heavy blows beat the lock off")
	probe_check(LB.can_be_inserted(coin, TRUE), "a broken lockbox opens freely")

/proc/fourth_batch_checks()
	map.civilizations = FALSE
	// Fallen roll and dog tags
	var/datum/fallen_roll/roll = new
	fallen_roll = roll
	var/mob/living/human/red1 = probe_human(3, 12, "Red One")
	red1.faction_text = "Red"
	var/mob/living/human/red2 = probe_human(4, 12, "Red Two")
	red2.faction_text = "Red"
	var/mob/living/human/blue1 = probe_human(5, 12, "Blue One")
	blue1.faction_text = "Blue"
	probe_check(roll.record_death(red1) && !roll.record_death(red1), "a death is recorded once")
	probe_check(!red1.take_dog_tags_by(red2), "tags only come off the dead")
	red1.stat = DEAD
	var/obj/item/weapon/dogtag/T = red1.take_dog_tags_by(red2)
	probe_check(istype(T) && T.tag_name == "Red One" && T.tag_faction == "Red" && findtext(T.name, "Red One"), "a comrade takes named tags")
	probe_check(!red1.take_dog_tags_by(blue1), "a body has only one set of tags")
	var/list/lines = roll.lines()
	probe_check(lines.len == 1 && findtext(lines[1], "<b>Red</b> lost 1: Red One.") && findtext(lines[1], "Tags brought home: 1."), "the roll lists the fallen and tags brought home: [jointext(lines, " | ")]")
	red2.stat = DEAD
	roll.record_death(red2)
	red2.take_dog_tags_by(blue1)
	lines = roll.lines()
	probe_check(findtext(lines[1], "Tags taken by the enemy: 1."), "enemy-taken tags are counted apart")
	probe_check(red1.persistence_runtime_var("dog_tags_taken"), "taken tags are not saved")

	// Medals
	var/mob/living/human/cmdr = probe_human(8, 12, "Commander")
	cmdr.faction_text = "Blue"
	var/datum/job/CJ = new
	CJ.is_commander = TRUE
	cmdr.original_job = CJ
	var/mob/living/human/hero = probe_human(9, 12, "Hero")
	hero.faction_text = "Blue"
	probe_check(istext(blue1.award_medal_to(hero, "Gold", "Brave")), "a private cannot award medals")
	probe_check(istext(cmdr.award_medal_to(red1, "Gold", "Brave")), "medals go only to your own living side")
	probe_check(istext(cmdr.award_medal_to(hero, "Gold", "")), "a medal needs a citation")
	var/obj/item/clothing/accessory/medal/gold/M = cmdr.award_medal_to(hero, "Gold", "Held the bridge")
	probe_check(istype(M) && findtext(M.desc, "Held the bridge") && roll.citations.len == 1, "a medal carries its citation to the round end")
	cmdr.award_medal_to(hero, "Bronze", "Two")
	cmdr.award_medal_to(hero, "Bronze", "Three")
	probe_check(istext(cmdr.award_medal_to(hero, "Bronze", "Four")), "three medals per officer per round")
	map.civilizations = TRUE
	probe_check(!medal_can_award(cmdr) && !roll.record_death(hero), "no medals or roll outside team rounds")
	map.civilizations = FALSE

	// Weapon light and sling
	var/mob/living/human/scout = probe_human(12, 12, "Scout")
	var/obj/item/weapon/gun/projectile/submachinegun/m16/ar15/G = new(scout.loc)
	scout.put_in_hands(G)
	var/obj/item/weapon/attachment/under/weapon_light/WL = new(scout.loc)
	probe_check(G.install_configuration(WL, null, TRUE) && G.weapon_light() == WL, "a weapon light fits the underbarrel rail")
	WL.light_on = TRUE
	G.update_weapon_light()
	probe_check(G.weapon_light_shining() && G.light_range == WL.beam_range, "a lit weapon light shines while the gun is in hand")
	scout.drop_from_inventory(G)
	probe_check(!G.weapon_light_shining() && !G.light_range, "it goes dark once the gun leaves your hands")
	var/obj/item/weapon/gun_sling/SL = new(scout.loc)
	probe_check(G.fit_sling(null, SL) && G.has_sling, "a sling fits a long gun")
	scout.put_in_hands(G)
	probe_check(!G.sling_catches(scout), "a standing soldier drops a slung gun normally")
	scout.weakened = 5
	probe_check(G.sling_catches(scout), "a knocked-down soldier keeps a slung gun")
	scout.drop_from_inventory(G)
	probe_check(scout.shoulder == G, "the slung gun ends up on the shoulder")
	scout.weakened = 0

	// Motion detector
	var/mob/living/human/watcher = probe_human(15, 15, "Watcher")
	var/obj/item/weapon/motion_detector/MD = new(watcher.loc)
	watcher.put_in_hands(MD)
	var/mob/living/human/mover = probe_human(18, 15, "Mover")
	var/mob/living/human/still = probe_human(17, 15, "Still")
	var/mob/living/human/far = probe_human(28, 28, "Far")
	mover.last_movement = world.time
	far.last_movement = world.time
	still.last_movement = -1
	watcher.last_movement = world.time
	var/list/contacts = MD.moving_contacts(watcher)
	probe_check((mover in contacts) && !(still in contacts) && !(far in contacts) && !(watcher in contacts), "the detector sees only nearby movers, not the holder")
	probe_check(MD.holder() == watcher, "the detector works while held")
	probe_check(MD.persistence_runtime_var("blips"), "blips are not saved")

	// Rangefinder report
	var/turf/far_turf = locate(25, 15, 1)
	var/report = rangefinder_report(watcher, far_turf)
	probe_check(findtext(report, "Range: 10 meters east") && findtext(report, "Coordinates 25,15") && findtext(report, "offset 10,0"), "the rangefinder gives exact range, bearing and coordinates: [report]")

/proc/probe_has_overlay(atom/A, state)
	for (var/O in A.overlays)
		if (O:icon_state == state)
			return TRUE
	return FALSE

/proc/fifth_batch_checks()
	// Typing indicator
	var/mob/living/human/talker = probe_human(3, 20, "Talker")
	probe_check(typing_indicator_state("emote") == "typing_emote" && typing_indicator_state("say") == "typing", "speech and emotes have their own bubbles")
	probe_check(("typing_emote" in icon_states('icons/mob/talk.dmi')) && ("typing" in icon_states('icons/mob/talk.dmi')), "both bubble sprites exist")
	var/image/bubble = talker.make_typing_indicator("emote")
	probe_check((bubble.appearance_flags & RESET_TRANSFORM) && bubble.icon_state == "typing_emote", "the bubble stays upright when its owner lies down")
	probe_check(!talker.set_typing_indicator("say") && !talker.typing_indicator, "no bubble without a client")
	talker.typing_indicator = bubble
	talker.typing = "emote"
	talker.overlays += bubble
	probe_check(probe_has_overlay(talker, "typing_emote"), "the probe sees overlays by state")
	talker.update_icons()
	probe_check(!talker.typing_indicator && !talker.typing && !probe_has_overlay(talker, "typing_emote"), "a stale bubble is cleared when the owner can no longer type")
	probe_check(talker.persistence_runtime_var("typing_indicator") && talker.persistence_runtime_var("typing"), "typing state is not saved")

	// Triage tags
	var/mob/living/human/medic = probe_human(5, 20, "Medic")
	var/mob/living/human/patient = probe_human(6, 20, "Patient")
	var/datum/job/MJ = new
	MJ.is_medic = TRUE
	medic.original_job = MJ
	probe_check(can_triage(medic), "a medic can triage")
	probe_check(!patient.set_triage_tag("blue"), "only the four triage colours are accepted")
	probe_check(patient.set_triage_tag("red") && patient.triage_tag == "red" && probe_has_overlay(patient, "triage_red"), "a red tag shows on the patient")
	patient.update_icons()
	probe_check(probe_has_overlay(patient, "triage_red"), "the tag survives an icon rebuild")
	var/image/old_tag = patient.triage_overlay
	patient.set_triage_tag("black")
	probe_check(old_tag && !probe_has_overlay(patient, "triage_red") && probe_has_overlay(patient, "triage_black"), "retagging replaces the old tag")
	patient.set_triage_tag(null)
	probe_check(!patient.triage_tag && !patient.triage_overlay && !probe_has_overlay(patient, "triage_black"), "the tag can be removed")
	probe_check(patient.persistence_runtime_var("triage_tag") && patient.persistence_runtime_var("triage_overlay"), "triage tags are not saved")
	for (var/colour in triage_tag_meanings())
		probe_check("triage_[colour]" in icon_states('icons/obj/cmss13_ports.dmi'), "the [colour] tag has a sprite")

	// Drag trails
	var/mob/living/human/wounded = probe_human(10, 22, "Wounded")
	probe_check(!wounded.is_bleeding_out(), "an unhurt body does not bleed")
	var/obj/item/organ/external/chest = wounded.get_organ("chest")
	chest.status |= ORGAN_BLEEDING
	probe_check(wounded.is_bleeding_out(), "a bleeding organ is noticed")
	var/turf/trail_turf = locate(10, 22, 1)
	var/obj/effect/decal/cleanable/blood/drag/D = wounded.leave_drag_trail(trail_turf, EAST)
	probe_check(istype(D) && D.dir == EAST && D.amount == 0, "a smear points the way the body went and is too thin to track")
	probe_check(!wounded.leave_drag_trail(trail_turf, EAST), "one smear per tile")
	var/mob/living/human/dragger = probe_human(12, 22, "Dragger")
	wounded.pulledby = dragger
	wounded.lying = TRUE
	var/turf/drag_from = locate(10, 26, 1)
	wounded.forceMove(drag_from)
	wounded.Move(locate(11, 26, 1), EAST)
	var/obj/effect/decal/cleanable/blood/drag/smear = locate() in drag_from
	probe_check(wounded.x == 11 && smear && smear.dir == EAST, "dragging a bleeding body smears its old tile")
	var/turf/clean_turf = locate(10, 24, 1)
	var/mob/living/human/walker = probe_human(10, 24, "Walker")
	walker.Move(locate(11, 24, 1), EAST)
	probe_check(!(locate(/obj/effect/decal/cleanable/blood/drag) in clean_turf), "walking leaves no smear")
	wounded.pulledby = null

	// Signal smoke
	for (var/colour in list("red", "green", "yellow", "purple"))
		var/path = text2path("/obj/item/weapon/grenade/smokebomb/marker/[colour]")
		var/obj/item/weapon/grenade/smokebomb/marker/S = new path(locate(20, 20, 1))
		var/list/states = icon_states(S.icon)
		probe_check(S.smoke && S.smoke.type == S.smoke_colour_type && (S.icon_state in states) && ("[S.icon_state]_active" in states), "[colour] signal smoke has its colour and sprites")
		qdel(S)

	// New-player marker
	var/datum/new_player_marks/NPM = new
	probe_check(!NPM.is_new(null) && !NPM.refresh(null) && !NPM.staff_can_see(null), "the marker ignores missing clients")
	probe_check("new_player" in icon_states('icons/obj/cmss13_ports.dmi'), "the marker has a sprite")
