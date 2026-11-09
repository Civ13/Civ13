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
	sixth_batch_checks()
	seventh_batch_checks()
	eighth_batch_checks()
	ninth_batch_checks()

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

/proc/sixth_batch_checks()
	map.civilizations = FALSE
	map.faction1 = "Red"
	map.faction2 = "Blue"
	var/datum/job/SJ = new
	SJ.uses_squads = TRUE
	var/datum/job/LJ = new
	LJ.uses_squads = TRUE
	LJ.is_squad_leader = TRUE
	var/datum/job/CJ = new
	CJ.is_commander = TRUE

	// Squad colours
	probe_check(squad_colour_name(1) == "red" && squad_colour_name(4) == "blue" && !squad_colour_name(0) && !squad_colour_name(8), "squads 1-7 have colours")
	var/mob/living/human/grunt = probe_human(3, 3, "Grunt")
	grunt.faction_text = "Red"
	grunt.original_job = SJ
	grunt.squad = 2
	probe_check(grunt.in_squad(), "a squad job with a squad number is in a squad")

	// Tracker
	var/mob/living/human/sl = probe_human(3, 13, "Sergeant")
	sl.faction_text = "Red"
	sl.original_job = LJ
	sl.squad = 2
	map.faction1_squad_leaders[2] = sl
	probe_check(grunt.tracker_target() == sl, "a soldier's tracker points at the squad leader")
	probe_check(tracker_bearing(grunt, sl) == 0, "the leader due north is at bearing 0")
	probe_check(round(tracker_bearing(grunt, locate(13, 3, 1))) == 90 && round(tracker_bearing(grunt, locate(1, 3, 1))) == 270, "east is 90 and west is 270")
	probe_check(!sl.tracker_target(), "with no commander the squad leader's tracker shows nothing")
	var/mob/living/human/cmdr = probe_human(20, 20, "Colonel")
	cmdr.faction_text = "Red"
	cmdr.original_job = CJ
	human_clients_mob_list |= cmdr
	probe_check(sl.tracker_target() == cmdr, "a squad leader's tracker points at the commander")
	probe_check(!cmdr.tracker_target(), "the commander has no tracker")
	sl.stat = DEAD
	probe_check(grunt.tracker_target() == cmdr, "with the leader dead the soldier is pointed at the commander")
	sl.stat = CONSCIOUS
	map.civilizations = TRUE
	probe_check(!grunt.tracker_target(), "no tracker outside team rounds")
	map.civilizations = FALSE
	human_clients_mob_list -= cmdr

	var/obj/field_hud/FH = new(null, grunt)
	var/mob/living/human/mate = probe_human(4, 3, "Mate")
	mate.faction_text = "Red"
	mate.original_job = SJ
	mate.squad = 2
	var/mob/living/human/other = probe_human(5, 3, "Other")
	other.faction_text = "Red"
	other.original_job = SJ
	other.squad = 3
	var/list/imgs = FH.build()
	var/arrows = 0
	var/chevrons = 0
	for (var/image/I in imgs)
		if (I.icon_state == "tracker_arrow")
			arrows++
		if (I.icon_state == "squad_chevron")
			chevrons++
			probe_check(I.loc == mate && I.color == squad_colour_hex(2), "the chevron marks the squadmate in the squad colour")
	probe_check(arrows == 1 && chevrons == 1, "the HUD shows one arrow and only same-squad chevrons ([arrows], [chevrons])")
	FH.owner = null
	probe_check(FH.process_interval(2) == PROCESS_KILL, "a field HUD without an owner stops")
	probe_check(grunt.persistence_runtime_var("field_hud") && FH.persistence_runtime_var("shown"), "field HUDs are not saved")

	// Medic health icons
	var/mob/living/human/doc = probe_human(10, 5, "Doc")
	doc.faction_text = "Red"
	var/datum/job/MJ = new
	MJ.is_medic = TRUE
	doc.original_job = MJ
	var/mob/living/human/hurt = probe_human(11, 5, "Hurt")
	hurt.faction_text = "Red"
	probe_check(!hurt.medic_health_state(), "a healthy person shows nothing")
	var/obj/item/organ/external/arm = hurt.get_organ("l_arm")
	arm.status |= ORGAN_BLEEDING
	probe_check(hurt.medic_health_state() == "health_bleeding", "bleeding shows")
	hurt.stat = UNCONSCIOUS
	probe_check(hurt.medic_health_state() == "health_critical", "unconscious shows as critical")
	hurt.stat = DEAD
	probe_check(hurt.medic_health_state() == "health_dead", "the dead show as dead")
	var/mob/living/human/enemy = probe_human(12, 5, "Enemy")
	enemy.faction_text = "Blue"
	probe_check(medic_sees_patient(doc, hurt) && !medic_sees_patient(doc, enemy) && !medic_sees_patient(doc, doc), "in team rounds medics see only their own side")
	for (var/state in list("health_hurt", "health_bleeding", "health_critical", "health_dead", "tracker_arrow", "squad_chevron", "mine_detector", "mine_detector_on", "mine_ping"))
		probe_check(state in icon_states('icons/obj/cmss13_ports.dmi'), "[state] has a sprite")

	// Mine detector
	var/mob/living/human/sapper = probe_human(20, 5, "Sapper")
	var/obj/item/weapon/mine_detector/MDT = new(sapper.loc)
	sapper.put_in_hands(MDT)
	var/obj/item/mine/ap/armed/near = new(locate(22, 5, 1))
	var/obj/item/mine/ap/armed/far = new(locate(24, 5, 1))
	var/obj/item/mine/ap/loose = new(locate(21, 5, 1))
	var/obj/item/mine/ap/armed/out = new(locate(28, 5, 1))
	var/list/found = MDT.armed_mines_near(get_turf(sapper))
	probe_check(found.len == 2 && found[1] == near && found[2] == far && !(loose in found) && !(out in found), "the detector finds armed mines in range, nearest first")
	probe_check(MDT.holder() == sapper && MDT.persistence_runtime_var("marks"), "the detector works in hand and its marks are not saved")

	// High five
	var/mob/living/human/amy = probe_human(25, 25, "Amy")
	var/mob/living/human/ben = probe_human(26, 25, "Ben")
	probe_check(amy.gesture_with(ben, "high five") == "offered", "a high five is offered")
	probe_check(ben.gesture_with(amy, "fist bump") == "offered", "a different gesture does not answer it")
	probe_check(ben.gesture_with(amy, "high five") == "done" && !amy.gesture_kind, "answering completes the high five")
	probe_check(amy.gesture_with(ben, "fist bump") == "done", "the earlier fist bump offer can still be answered")
	amy.gesture_with(ben, "high five")
	amy.gesture_time = world.time - 100
	probe_check(ben.gesture_with(amy, "high five") == "offered", "an old offer expires")
	probe_check(!amy.gesture_with(locate(/mob/living/human) in locate(3, 3, 1), "high five"), "you can only high five someone next to you")
	map.civilizations = TRUE

/proc/seventh_batch_checks()
	map.civilizations = FALSE
	map.faction1 = "Red"
	map.faction2 = "Blue"
	var/datum/job/SJ = new
	SJ.uses_squads = TRUE
	var/datum/job/LJ = new
	LJ.uses_squads = TRUE
	LJ.is_squad_leader = TRUE

	// Squad fire teams
	var/mob/living/human/sgt = probe_human(2, 28, "Sarge")
	sgt.faction_text = "Red"
	sgt.original_job = LJ
	sgt.squad = 1
	var/mob/living/human/p1 = probe_human(3, 28, "Pvt One")
	p1.faction_text = "Red"
	p1.original_job = SJ
	p1.squad = 1
	var/mob/living/human/p2 = probe_human(9, 28, "Pvt Two")
	p2.faction_text = "Red"
	p2.original_job = SJ
	p2.squad = 1
	var/mob/living/human/stranger = probe_human(4, 28, "Stranger")
	stranger.faction_text = "Red"
	stranger.original_job = SJ
	stranger.squad = 2
	map.faction1_squad_leaders[1] = sgt
	var/key = squad_group_key(p1)
	probe_check(fire_team_organizer(sgt, "squad", key) && !fire_team_organizer(p1, "squad", key), "the squad leader runs the squad's fire teams")
	probe_check(!assign_fire_team(p1, p2, "squad", key, 1), "a private cannot assign fire teams")
	probe_check(!assign_fire_team(sgt, stranger, "squad", key, 1), "only members of the squad can join its fire teams")
	probe_check(assign_fire_team(sgt, p1, "squad", key, 1) && assign_fire_team(sgt, p2, "squad", key, 1, TRUE), "the leader assigns two soldiers to fire team 1, one as its leader")
	probe_check(p1.same_fire_team(p2) && p1.fire_team_leader() == p2 && p1.tracker_target() == p2, "the tracker points a fire team member at the fire team leader")
	probe_check(p2.tracker_target() == sgt, "the fire team leader is pointed at the squad leader")
	assign_fire_team(sgt, p1, "squad", key, 1, TRUE)
	probe_check(p1.fire_team_lead && !p2.fire_team_lead, "a fire team has one leader")
	var/datum/roster_view/RV = new(sgt)
	var/page = RV.html()
	probe_check(findtext(page, "Pvt One") && findtext(page, "FT 1") && !findtext(page, "Stranger"), "the squad leader's roster lists the squad with fire teams")
	var/datum/roster_view/RV2 = new(p2)
	page = RV2.html()
	probe_check(findtext(page, "Fire team 1") && findtext(page, "Pvt One") && !findtext(page, "Sarge"), "a member's roster shows only their fire team")
	var/datum/roster_view/RV3 = new(stranger)
	probe_check(!RV3.html(), "someone without a group or team has no roster")
	p1.squad = 3
	probe_check(!p1.has_fire_team() && !p1.fire_team, "leaving the squad drops the fire team")
	p1.squad = 1
	probe_check(assign_fire_team(sgt, p2, "squad", key, 0) && !p2.has_fire_team(), "a fire team can be cleared")
	probe_check("fireteam_1" in icon_states('icons/obj/cmss13_ports.dmi'), "fire team badges have sprites")

	// Player factions and companies
	map.civilizations = TRUE
	map.custom_civs["Probe Guild"] = list(0, 0, 0, null, 0)
	var/mob/living/human/chief = probe_human(12, 28, "Chief")
	chief.civilization = "Probe Guild"
	map.custom_civs["Probe Guild"][4] = chief
	var/mob/living/human/folk = probe_human(13, 28, "Folk")
	folk.civilization = "Probe Guild"
	probe_check(fire_team_organizer(chief, "faction", "Probe Guild") && !fire_team_organizer(folk, "faction", "Probe Guild"), "the faction leader runs the faction's fire teams")
	probe_check(assign_fire_team(chief, folk, "faction", "Probe Guild", 2, TRUE) && folk.has_fire_team(), "faction members join fire teams")
	folk.civilization = "none"
	probe_check(!folk.has_fire_team(), "leaving the faction drops the fire team")
	map.custom_company["Probe Co"] = list(list(chief, 60, 0), list(folk, 40, 0))
	map.custom_company_nr += "Probe Co"
	probe_check(company_majority_holder("Probe Co") == chief && fire_team_organizer(chief, "company", "Probe Co") && !fire_team_organizer(folk, "company", "Probe Co"), "the majority holder runs the company's fire teams")
	probe_check(assign_fire_team(chief, folk, "company", "Probe Co", 3) && folk.fire_team == 3, "shareholders join company fire teams")
	var/list/groups = chief.organized_groups()
	probe_check(groups.len == 2 && groups[1][1] == "faction" && groups[2][1] == "company", "organized groups list the faction and company the leader runs ([groups.len])")
	map.custom_company_nr -= "Probe Co"
	map.custom_company -= "Probe Co"
	map.custom_civs -= "Probe Guild"

	// Friendly fire
	map.civilizations = FALSE
	var/datum/round_facts/F = new
	var/mob/living/human/ally1 = probe_human(15, 28, "Ally One")
	ally1.faction_text = "Red"
	var/mob/living/human/ally2 = probe_human(16, 28, "Ally Two")
	ally2.faction_text = "Red"
	var/mob/living/human/foe = probe_human(17, 28, "Foe")
	foe.faction_text = "Blue"
	F.record_hit(foe, ally1, "rifle")
	probe_check(!F.friendly_hits.len, "hitting the enemy is not friendly fire")
	for (var/i = 1 to 3)
		F.record_hit(ally2, ally1, "rifle")
	probe_check(F.friendly_hits["Ally One"] == 3, "hits on your own side are counted")
	var/list/lines = F.fact_lines()
	probe_check(findtext(jointext(lines, "|"), "Friendly fire: 3 hits") && findtext(jointext(lines, "|"), "Ally One"), "round facts report friendly fire")

	// Machine gun heat
	var/obj/item/weapon/gun/projectile/automatic/dp28/MG = new(locate(20, 28, 1))
	var/obj/item/weapon/gun/projectile/automatic/stationary/HMG = new /obj/item/weapon/gun/projectile/automatic/stationary(locate(21, 28, 1))
	var/obj/item/weapon/gun/projectile/submachinegun/m16/ar15/rifle = new(locate(22, 28, 1))
	probe_check(MG.heat_per_shot() == 4 && HMG.heat_per_shot() == 2 && !rifle.heat_per_shot(), "only machine guns heat up, mounted ones more slowly ([MG.heat_per_shot()], [HMG.heat_per_shot()], [rifle.heat_per_shot()], [rifle.stat])")
	for (var/i = 1 to 25)
		MG.add_heat(null)
	probe_check(MG.overheated && MG.current_heat() >= 99, "25 shots overheat a light machine gun")
	MG.heat_time = world.time - 80
	probe_check(MG.current_heat() <= 40 && !MG.overheated, "eight seconds of cooling make it usable again")
	probe_check(MG.persistence_runtime_var("heat"), "barrel heat is not saved")

	// Autoinjectors
	var/obj/item/weapon/reagent_containers/syringe/autoinjector/clotting/C = new(locate(23, 28, 1))
	var/obj/item/weapon/reagent_containers/syringe/autoinjector/morphine/Mo = new(locate(23, 28, 1))
	probe_check(C.time == 10 && C.reagents.has_reagent("clotting_agent", 10) && Mo.reagents.has_reagent("morphine", 5), "autoinjectors come filled and inject in a second")
	var/mob/living/human/bleeder = probe_human(24, 28, "Bleeder")
	var/obj/item/organ/external/leg = bleeder.get_organ("l_leg")
	leg.createwound(CUT, 30)
	var/bleeding_before = 0
	for (var/datum/wound/W in leg.wounds)
		if (W.bleeding())
			bleeding_before++
	var/datum/reagent/clotting_agent/CA = new
	CA.affect_blood(bleeder, 0, 1)
	var/bleeding_after = 0
	for (var/datum/wound/W in leg.wounds)
		if (W.bleeding())
			bleeding_after++
	probe_check(bleeding_before >= 1 && bleeding_after == bleeding_before - 1, "the clotting agent seals a bleeding wound ([bleeding_before] -> [bleeding_after])")
	var/obj/item/weapon/storage/firstaid/combat/modern/kit = new(locate(25, 28, 1))
	probe_check((locate(/obj/item/weapon/reagent_containers/syringe/autoinjector/clotting) in kit) && (locate(/obj/item/weapon/reagent_containers/syringe/autoinjector/morphine) in kit), "modern combat medicine kits carry autoinjectors")

	// Observer HUD
	var/mob/observer/ghost/G = new
	G.forceMove(locate(26, 26, 1))
	probe_check(G.persistence_runtime_var("field_hud"), "observer HUDs are not saved")
	var/obj/field_hud/OH = new(null, G)
	var/mob/living/human/hurtling = probe_human(27, 26, "Hurtling")
	hurtling.stat = DEAD
	var/found_dead = FALSE
	for (var/image/I in OH.build())
		if (I.loc == hurtling && I.icon_state == "health_dead")
			found_dead = TRUE
	probe_check(found_dead, "the observer HUD shows health badges for everyone in view")
	map.civilizations = TRUE

/proc/eighth_batch_checks()
	map.civilizations = FALSE
	field_marks.Cut()
	var/datum/job/SJ = new
	SJ.uses_squads = TRUE
	var/datum/job/LJ = new
	LJ.uses_squads = TRUE
	LJ.is_squad_leader = TRUE
	var/mob/living/human/lead = probe_human(2, 29, "Lead")
	lead.faction_text = "Red"
	lead.original_job = LJ
	lead.squad = 4
	var/mob/living/human/scout = probe_human(3, 29, "Scout")
	scout.faction_text = "Red"
	scout.original_job = SJ
	scout.squad = 4
	var/mob/living/human/outsider = probe_human(4, 29, "Outsider")
	outsider.faction_text = "Red"
	outsider.original_job = SJ
	outsider.squad = 5
	map.faction1_squad_leaders[4] = lead

	// Spot Enemy
	var/datum/field_mark/S = scout.spot_enemy_at(locate(10, 29, 1))
	probe_check(S && S.kind == "spot" && S.scope[1] == "squad", "spotting marks the spot for the squad")
	probe_check(field_mark_visible_to(S, lead) && !field_mark_visible_to(S, outsider), "only the spotter's squad sees the mark")
	probe_check(!scout.spot_enemy_at(locate(11, 29, 1)), "spotting again right away is refused")
	var/list/seen = field_marks_for(lead)
	probe_check(S in seen, "the field HUD lists the spot for the squad leader")
	var/obj/field_hud/FH = new(null, lead)
	var/found_spot = FALSE
	for (var/image/I in FH.build())
		if (I.icon_state == "spot_marker" && I.loc == S.where)
			found_spot = TRUE
	probe_check(found_spot, "the field HUD draws the spot marker")
	S.expires = world.time - 1
	probe_check(!(S in field_marks_for(lead)), "spot marks expire")
	var/mob/living/human/loner = probe_human(5, 29, "Loner")
	loner.faction_text = "Red"
	probe_check(!loner.spot_enemy_at(locate(10, 29, 1)), "someone with no group has nobody to warn")
	probe_check(scout.persistence_runtime_var("last_spot_time") && scout.persistence_runtime_var("recent_hits"), "spot cooldowns and recent hits are not saved")

	// Rally point
	var/list/scopes = lead.rally_scopes()
	probe_check(scopes.len == 1 && scopes[1] == "Squad 4", "a squad leader can rally their squad")
	probe_check(!scout.rally_scopes().len, "a private cannot set a rally point")
	var/datum/field_mark/R = lead.set_rally_point(scopes["Squad 4"], locate(20, 29, 1))
	probe_check(rally_point_for(scout) == R && scout.tracker_target() == R.where, "the tracker points the squad at the rally point")
	probe_check(!rally_point_for(outsider) && !rally_point_for(lead), "other squads and the leader are not pointed at it")
	lead.set_rally_point(scopes["Squad 4"], locate(21, 29, 1))
	var/rallies = 0
	for (var/datum/field_mark/M in field_marks)
		if (M.kind == "rally")
			rallies++
	probe_check(rallies == 1, "a new rally point replaces the old one")
	lead.clear_rally_point(scopes["Squad 4"])
	probe_check(!rally_point_for(scout) && scout.tracker_target() == lead, "clearing the rally point points the tracker back at the leader")
	probe_check(("rally_marker" in icon_states('icons/obj/cmss13_ports.dmi')) && ("spot_marker" in icon_states('icons/obj/cmss13_ports.dmi')), "spot and rally markers have sprites")

	// Death recap and personal stats
	var/datum/round_facts/F = new
	var/mob/living/human/victim = probe_human(6, 29, "Victim")
	var/mob/living/human/gunner = probe_human(7, 29, "Gunner")
	var/mob/living/human/stabber = probe_human(8, 29, "Stabber")
	F.record_hit(victim, gunner, "rifle")
	F.record_hit(victim, gunner, "rifle")
	F.record_hit(victim, stabber, "bayonet")
	var/recap = jointext(victim.death_recap_lines(), "|")
	probe_check(findtext(recap, "<b>Gunner</b> hit you 2 times (rifle)") && findtext(recap, "<b>Stabber</b> hit you once (bayonet)"), "the recap lists who hurt you and with what: [recap]")
	probe_check(findtext(recap, "Killing blow: <b>Stabber</b> with a bayonet"), "the recap names the killing blow")
	for (var/list/hit in victim.recent_hits)
		hit[1] = world.time - 700
	probe_check(findtext(jointext(victim.death_recap_lines(), "|"), "No one hurt you"), "old hits drop out of the recap")
	for (var/i = 1 to 40)
		F.record_hit(victim, gunner, "rifle")
	probe_check(victim.recent_hits.len == 30, "the recap keeps the last 30 hits")
	F.record_shot(gunner)
	F.record_death(victim)
	F.medals_received["Gunner"] = 1
	var/line = F.personal_line("Gunner")
	probe_check(findtext(line, "1 shot") && findtext(line, "42 hits") && findtext(line, "1 kill") && findtext(line, "1 medal"), "personal stats list shots, hits, kills and medals: [line]")
	probe_check(!F.personal_line("Nobody"), "someone who did nothing gets no line")

	// Searchlight
	var/obj/structure/searchlight/SL = new(locate(2, 30, 1))
	SL.set_dir(EAST)
	probe_check(SL.beam_turf() == locate(8, 30, 1), "the beam reaches six tiles ahead")
	var/turf/wall = locate(6, 30, 1)
	wall.density = TRUE
	probe_check(SL.beam_turf() == locate(5, 30, 1), "walls stop the beam")
	wall.density = FALSE
	SL.attack_hand(lead)
	probe_check(SL.on && SL.beam && SL.beam.loc == locate(8, 30, 1) && SL.icon_state == "searchlight_on", "switching it on lights the far end")
	SL.set_dir(turn(SL.dir, -90))
	SL.update_beam()
	probe_check(SL.dir == SOUTH && SL.beam.loc == locate(2, 24, 1), "turning it moves the beam")
	probe_check(SL.persistence_runtime_var("beam") && !SL.persistence_runtime_var("on"), "the switch is saved, the beam is rebuilt")
	SL.attack_hand(lead)
	probe_check(!SL.on && !SL.beam, "switching it off removes the beam")
	probe_check("searchlight_on" in icon_states('icons/obj/cmss13_ports.dmi'), "the searchlight has sprites")

	// Fire teams are saved with the character
	probe_check(!scout.persistence_runtime_var("fire_team") && !scout.persistence_runtime_var("fire_team_kind") && !scout.persistence_runtime_var("fire_team_group") && !scout.persistence_runtime_var("fire_team_lead"), "fire teams are saved with the character")
	map.faction1_squad_leaders[4] = null
	map.civilizations = TRUE

/proc/ninth_batch_checks()
	// Ghillie camouflage
	var/mob/living/human/sniper = probe_human(3, 27, "Sniper")
	var/obj/item/clothing/suit/storage/ghillie/suit = new(locate(3, 27, 1))
	sniper.equip_to_slot(suit, slot_wear_suit)
	probe_check(sniper.wear_suit == suit && (suit in processing_objects), "wearing a ghillie suit starts watching for stillness")
	sniper.lying = TRUE
	sniper.ghillie_moved_at = world.time - 40
	suit.process_interval(2)
	probe_check(sniper.ghillie_hidden && sniper.alpha == 40, "lying still on grass in a ghillie suit fades you out")
	var/mob/living/human/bumper = probe_human(4, 27, "Bumper")
	sniper.Bumped(bumper)
	probe_check(!sniper.ghillie_hidden && sniper.alpha == 255, "being bumped reveals you")
	suit.process_interval(2)
	probe_check(!sniper.ghillie_hidden, "you must lie still again before you fade")
	sniper.ghillie_moved_at = world.time - 40
	sniper.lying = FALSE
	suit.process_interval(2)
	probe_check(!sniper.ghillie_hidden, "standing up keeps you visible")
	var/mob/living/human/snowman = probe_human(5, 27, "Snowman")
	var/obj/item/clothing/suit/storage/ghillie/winter/WS = new(locate(5, 27, 1))
	snowman.equip_to_slot(WS, slot_wear_suit)
	snowman.lying = TRUE
	snowman.ghillie_moved_at = world.time - 40
	probe_check(!snowman.ghillie_can_hide(), "a winter ghillie does not hide you on grass")
	probe_check(sniper.persistence_runtime_var("ghillie_hidden") && sniper.persistence_runtime_var("ghillie_moved_at"), "ghillie state is not saved")
	sniper.alpha = 40
	sniper.after_load()
	probe_check(sniper.alpha == 255, "a body saved while hidden comes back visible")

	// Night-vision goggles
	var/mob/living/human/watcher = probe_human(7, 27, "Watcher")
	var/obj/item/clothing/glasses/nvg/NV = new(locate(7, 27, 1))
	watcher.equip_to_slot(NV, slot_eyes)
	probe_check(!watcher.nvg_dazzle(), "goggles that are off are not dazzled")
	NV.active = TRUE
	probe_check(watcher.nvg_dazzle() && watcher.eye_blurry >= 5, "a bright light dazzles active goggles")

	// Respawn countdown
	probe_check(respawn_wait_text(0) == "now" && respawn_wait_text(135) == "2:15" && respawn_wait_text(5) == "0:05", "the respawn countdown reads minutes and seconds")
	probe_check(respawn_wait_seconds(null) == 0, "no client means no wait")

	// Cell timer
	map.civilizations = FALSE
	var/datum/job/OJ = new
	OJ.is_officer = TRUE
	var/mob/living/human/warden = probe_human(10, 26, "Warden")
	warden.original_job = OJ
	var/mob/living/human/inmate = probe_human(10, 28, "Inmate")
	inmate.original_job = new /datum/job
	probe_check(can_set_cell_timer(warden) && !can_set_cell_timer(inmate), "only officers set cell timers in battle")
	var/obj/structure/simple_door/key_door/anyone/wood/cell = new(locate(10, 27, 1))
	probe_check(cell.start_sentence(5, "Warden") && cell.cell_sentence_left == 3000 && (cell in processing_objects), "a sentence holds the door for its minutes")
	probe_check(!cell.canOpen(inmate) && !cell.canOpen(warden), "nobody opens a door serving a sentence")
	cell.process_interval(2)
	probe_check(cell.cell_sentence_left == 2980, "the timer counts down")
	probe_check(!cell.persistence_runtime_var("cell_sentence_left"), "the time left is saved")
	processing_objects -= cell
	cell.after_load()
	probe_check(cell in processing_objects, "a loaded cell keeps counting")
	cell.cell_sentence_left = 10
	probe_check(cell.process_interval(2) == PROCESS_KILL && !cell.cell_sentence_left && cell.isSwitchingStates, "the door opens itself when the time is served")
	var/obj/structure/simple_door/key_door/anyone/wood/cell2 = new(locate(12, 27, 1))
	cell2.start_sentence(99, "Warden")
	probe_check(cell2.cell_sentence_left == 18000, "sentences are capped at 30 minutes")
	cell2.end_sentence(TRUE)
	probe_check(!cell2.cell_sentence_left && cell2.canOpen(inmate), "a leader can release early")
	map.civilizations = TRUE

	// Breaching charge
	var/obj/item/weapon/breaching_charge/BC = new(locate(15, 25, 1))
	var/obj/item/weapon/reagent_containers/glass/beaker/NG = new(locate(15, 25, 1))
	NG.reagents.add_reagent("nitroglycerin", 5)
	var/mob/living/human/sapper = probe_human(15, 25, "Sapper")
	BC.attackby(NG, sapper)
	probe_check(BC.filled && NG.reagents.get_reagent_amount("nitroglycerin") == 2, "nitroglycerin fills the charge")
	var/obj/structure/simple_door/key_door/anyone/wood/target = new(locate(15, 26, 1))
	var/mob/living/human/behind = probe_human(15, 27, "Behind")
	var/mob/living/human/beside = probe_human(14, 25, "Beside")
	sapper.forceMove(locate(15, 25, 1))
	probe_check(BC.plant(target, sapper) && !BC.loc && BC.target == target, "the charge is planted on the door")
	BC.detonate()
	probe_check(QDELETED(target), "the door is blown open")
	probe_check(behind.weakened > 0 && !beside.weakened && !sapper.weakened, "whoever is behind the door is knocked down, the breacher's side is not ([behind.weakened], [beside.weakened], [sapper.weakened])")
	var/obj/structure/window/classic/WIN = new(locate(18, 25, 1))
	var/obj/structure/window/barrier/SB = new(locate(19, 25, 1))
	probe_check(breach_target_ok(WIN) && !breach_target_ok(SB) && !breach_target_ok(sapper), "charges fit doors and windows, not sandbags or people")
