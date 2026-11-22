// Full-source probe for hand conditioning: sets on the makiwara, gravel pail
// and bare rock, caps, the injury rolls and what protection does to them,
// fading, the punch injury cut, and the unarmed skill. Real humans, gloves,
// posts and rock; the waits, the dice and the clock are the test's.
/world
	hub = ""
	visibility = 0
	maxx = 12
	maxy = 12
	maxz = 1
	fps = 20
	turf = /turf/floor/plating/conditioning_probe
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/conditioning_probe/New()
	map = src

/turf/floor/plating/conditioning_probe

/mob/living/human/conditioning_probe
var/conditioning_probe_checks = 0
var/conditioning_probe_wait = TRUE
var/conditioning_probe_now = 1000000
var/list/conditioning_probe_rolls
var/list/conditioning_probe_chances

/mob/living/human/conditioning_probe/hand_conditioning_clock()
	return conditioning_probe_now

/mob/living/human/conditioning_probe/conditioning_set_wait(atom/target)
	return conditioning_probe_wait

/mob/living/human/conditioning_probe/conditioning_roll(chance)
	conditioning_probe_chances += chance
	if (!conditioning_probe_rolls.len)
		return FALSE
	var/result = conditioning_probe_rolls[1]
	conditioning_probe_rolls.Cut(1, 2)
	return result

/proc/conditioning_probe_assert(ok, label)
	conditioning_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/conditioning_probe_wear(mob/living/human/H, path)
	if (H.gloves)
		var/obj/item/old = H.gloves
		H.drop_from_inventory(old)
		qdel(old)
	if (path)
		H.equip_to_slot_or_del(new path(H), slot_gloves)

/proc/conditioning_probe_heal(mob/living/human/H)
	for (var/zone in list("l_hand", "r_hand"))
		var/obj/item/organ/external/E = H.organs_by_name[zone]
		E.heal_damage(100, 100)
		E.mend_fracture()
	H.exercise_fatigue = 0
	H.nutrition = 400
	H.water = 400

/proc/conditioning_probe_run()
	// Set here, not in the global initialiser, which is at the compiler size limit.
	conditioning_probe_rolls = list()
	conditioning_probe_chances = list()
	config = new
	config.webhook_can_fire = FALSE
	makeDatumRefLists()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new
	GLOB.dir_set_event = new
	GLOB.destroyed_event = new
	GLOB.stat_set_event = new
	GLOB.name_set_event = new
	movementMachine = new
	map = new /obj/map_metadata/conditioning_probe
	map.ordinal_age = 0

	var/mob/living/human/conditioning_probe/H = new(locate(3, 3, 1))
	H.stat = CONSCIOUS
	H.canmove = TRUE
	H.hand = 0
	H.a_intent = I_HARM
	conditioning_probe_heal(H)
	var/obj/structure/striking_post/M = new(locate(4, 3, 1))
	var/obj/structure/striking_post/gravel_pail/G = new(locate(3, 4, 1))

	// --- unarmed skill --------------------------------------------------------
	conditioning_probe_assert(H.stats["unarmed"][1] == 100 && H.unarmed_damage_mult() == 1, "unarmed_starts_average")
	H.stats -= "unarmed"
	conditioning_probe_assert(H.unarmed_damage_mult() == 1, "old_save_without_unarmed_is_average")
	H.practice_unarmed(1)
	conditioning_probe_assert(islist(H.stats["unarmed"]) && H.stats["unarmed"][1] > 100, "practice_restores_and_raises_unarmed")
	H.stats["unarmed"] = list(200, 200)
	conditioning_probe_assert(abs(H.unarmed_damage_mult() - 1.25) < 0.001, "skilled_fists_hit_harder")
	H.stats["unarmed"] = list(100, 100)

	// --- a makiwara set -------------------------------------------------------
	var/unarmed_before = H.stats["unarmed"][1]
	M.attack_hand(H)
	conditioning_probe_assert(H.hand_conditioning == 2 && H.hand_conditioning_at == conditioning_probe_now, "makiwara_set_conditions")
	conditioning_probe_assert(H.exercise_fatigue == 2 && H.stats["unarmed"][1] > unarmed_before, "set_tires_and_teaches_unarmed")
	conditioning_probe_assert(conditioning_probe_chances.len == 1 && conditioning_probe_chances[1] == 5, "makiwara_bare_risk_5")
	// Help intent only touches it.
	H.a_intent = I_HELP
	M.attack_hand(H)
	conditioning_probe_assert(H.hand_conditioning == 2, "help_intent_does_not_train")
	H.a_intent = I_HARM
	// An interrupted set gives nothing.
	conditioning_probe_wait = FALSE
	M.attack_hand(H)
	conditioning_probe_wait = TRUE
	conditioning_probe_assert(H.hand_conditioning == 2, "interrupted_set_gives_nothing")
	// Something in the striking hand.
	var/obj/item/stack/material/cloth/C = new(H.loc, 1)
	H.put_in_active_hand(C)
	M.attack_hand(H)
	conditioning_probe_assert(H.hand_conditioning == 2, "full_hand_cannot_strike")
	H.drop_from_inventory(C)
	qdel(C)

	// --- caps -----------------------------------------------------------------
	conditioning_probe_heal(H)
	H.hand_conditioning = 30
	M.attack_hand(H)
	conditioning_probe_assert(H.hand_conditioning == 30, "makiwara_caps_at_30")
	conditioning_probe_heal(H)
	G.attack_hand(H)
	conditioning_probe_assert(H.hand_conditioning == 33, "gravel_builds_past_30")
	H.hand_conditioning = 60
	conditioning_probe_heal(H)
	G.attack_hand(H)
	conditioning_probe_assert(H.hand_conditioning == 60, "gravel_caps_at_60")

	// --- risk: wraps, boxing gloves, fatigue, a hurt hand ----------------------
	conditioning_probe_heal(H)
	conditioning_probe_assert(H.conditioning_set_chance(10) == 10 && H.conditioning_set_gain(3) == 3, "bare_full_risk_full_gain")
	conditioning_probe_wear(H, /obj/item/clothing/gloves/hand_wraps)
	conditioning_probe_assert(H.conditioning_set_chance(10) == 5 && H.conditioning_set_gain(3) == 1.5, "wraps_halve_both")
	conditioning_probe_wear(H, /obj/item/clothing/gloves/boxing)
	conditioning_probe_assert(H.conditioning_set_chance(10) == 0 && H.conditioning_set_gain(3) == 0, "boxing_gloves_stop_both")
	conditioning_probe_wear(H, null)
	H.exercise_fatigue = 4
	conditioning_probe_assert(H.conditioning_set_chance(10) == 20, "fatigue_doubles_risk")
	conditioning_probe_heal(H)
	H.apply_damage(2, BRUTE, "r_hand")
	conditioning_probe_assert(H.conditioning_set_chance(10) == 20, "hurt_hand_doubles_risk")

	// --- injuries ---------------------------------------------------------------
	conditioning_probe_heal(H)
	var/obj/item/organ/external/R = H.organs_by_name["r_hand"]
	conditioning_probe_rolls = list(TRUE)
	M.attack_hand(H)
	conditioning_probe_assert(R.brute_dam >= 3 && !(R.status & ORGAN_BROKEN), "makiwara_bruises")
	conditioning_probe_heal(H)
	conditioning_probe_rolls = list(TRUE, FALSE)
	G.attack_hand(H)
	conditioning_probe_assert(R.brute_dam >= 3 && !(R.status & ORGAN_BROKEN), "gravel_splits_knuckles")
	conditioning_probe_heal(H)
	// Bare rock: anywhere up to 100, one injury in four breaks the hand.
	var/turf/wall/rockwall/rock = new(locate(2, 3, 1))
	H.hand_conditioning = 60
	conditioning_probe_chances = list()
	conditioning_probe_rolls = list(TRUE, TRUE)
	rock.attack_hand(H)
	conditioning_probe_assert(H.hand_conditioning == 64 && conditioning_probe_chances[1] == 18 && conditioning_probe_chances[2] == 25, "rock_conditions_and_risks_most")
	conditioning_probe_assert(R.status & ORGAN_BROKEN, "rock_breaks_hand")
	var/before_broken = H.hand_conditioning
	rock.attack_hand(H)
	conditioning_probe_assert(H.hand_conditioning == before_broken, "broken_hand_cannot_train")
	conditioning_probe_heal(H)

	// --- fatigue limit ------------------------------------------------------------
	H.exercise_fatigue = 6
	var/tired = H.hand_conditioning
	M.attack_hand(H)
	conditioning_probe_assert(H.hand_conditioning == tired, "exhausted_cannot_train")
	conditioning_probe_heal(H)

	// --- fading and the punch cut -------------------------------------------------
	H.hand_conditioning = 50
	H.hand_conditioning_at = conditioning_probe_now
	conditioning_probe_assert(abs(H.hand_conditioning_factor() - 0.7) < 0.001, "50_cuts_punch_risk_30_percent")
	var/bare = H.punch_injury_chance("chest", 5, 0)
	H.hand_conditioning = 0
	conditioning_probe_assert(abs(bare - H.punch_injury_chance("chest", 5, 0) * 0.7) < 0.001, "punch_chance_uses_conditioning")
	H.hand_conditioning = 50
	conditioning_probe_now += 864000 * 3 + 10
	conditioning_probe_assert(H.current_hand_conditioning() == 47, "three_days_fade_three_points")
	conditioning_probe_assert(H.current_hand_conditioning() == 47, "fade_is_not_counted_twice")

	// --- drawn art exists -----------------------------------------------------------
	conditioning_probe_assert(("makiwara" in icon_states(M.icon)) && ("gravel_pail" in icon_states(G.icon)), "drawn_icon_states")

/world/New()
	OpenPort("none")
	var/error = null
	try
		conditioning_probe_run()
	catch (var/exception/probe_error)
		error = "[probe_error.name] ([probe_error.file]:[probe_error.line])"
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("checks" = conditioning_probe_checks, "error" = error, "byond_build" = byond_build)), "receipt.json")
	del(world)
