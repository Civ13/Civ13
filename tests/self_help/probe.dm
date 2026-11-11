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
var/probe_failures = 0
var/probe_checks = 0
var/probe_runtime_error = FALSE
/obj/map_metadata/self_help_probe/New()
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
		map = new /obj/map_metadata/self_help_probe
		if (!all_species.len)
			makeDatumRefLists()
		for (var/turf/T in block(locate(1, 1, 1), locate(20, 20, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		get_up_checks()
		pressure_checks()
		tourniquet_checks()
		bleeding_checks()
		brace_checks()
	catch(var/exception/e)
		probe_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("checks" = probe_checks, "failures" = probe_failures, "runtime_error" = probe_runtime_error)), "result.json")
	del(world)

/proc/probe_body(x, name)
	var/mob/living/human/H = new(locate(x, 5, 1))
	H.name = name
	H.real_name = name
	H.stats["stamina"][1] = H.stats["stamina"][2]
	return H

/proc/probe_bleed(mob/living/human/H, zone)
	var/obj/item/organ/external/E = H.get_organ(zone)
	E.status |= ORGAN_BLEEDING
	return E

/proc/get_up_checks()
	var/mob/living/human/A = probe_body(2, "Abel")
	probe_check(A.get_up_blocker() == "You aren't knocked down.", "standing people have nothing to get up from")
	A.SetWeakened(5)
	probe_check(A.lying, "a knockdown puts you on the ground")
	probe_check(isnull(A.get_up_blocker()), "a conscious, knocked-down person can try to get up: [A.get_up_blocker()]")
	var/delay = A.get_up_delay()
	probe_check(delay >= 20 && delay < 5 * 20, "getting up is quicker than waiting it out ([delay] ds for 5 ticks)")
	A.SetWeakened(40)
	probe_check(A.get_up_delay() <= 160, "even a long knockdown takes at most a few seconds to push up from")
	A.SetWeakened(5)
	var/stamina = A.stats["stamina"][1]
	probe_check(A.try_get_up(), "the attempt succeeds when nothing interrupts it")
	probe_check(!A.weakened && !A.lying, "getting up ends the knockdown and stands you up")
	probe_check(A.stats["stamina"][1] < stamina, "getting up costs stamina")
	A.SetWeakened(5)
	probe_check(findtext(A.get_up_blocker(), "catch your breath"), "a second try waits for the cooldown")
	A.next_get_up = 0
	A.Stun(3)
	probe_check(findtext(A.get_up_blocker(), "dazed"), "a stun still keeps you down")
	A.SetStunned(0)
	A.shock_stage = 100
	probe_check(findtext(A.get_up_blocker(), "pain"), "heavy pain keeps you down")
	A.shock_stage = 0
	A.stats["stamina"][1] = 0
	probe_check(findtext(A.get_up_blocker(), "exhausted"), "an exhausted body can't push up")
	A.stats["stamina"][1] = A.stats["stamina"][2]
	var/obj/item/organ/external/LA = A.get_organ("l_arm")
	var/obj/item/organ/external/RA = A.get_organ("r_arm")
	LA.status |= ORGAN_DESTROYED
	RA.status |= ORGAN_DESTROYED
	probe_check(findtext(A.get_up_blocker(), "no arm"), "you need an arm to push up with")
	LA.status &= ~ORGAN_DESTROYED
	RA.status &= ~ORGAN_DESTROYED
	A.set_stat(UNCONSCIOUS)
	probe_check(findtext(A.get_up_blocker(), "out cold"), "the unconscious can't get up")
	A.set_stat(CONSCIOUS)

	// An interrupting blow knocks you back down.
	var/mob/living/human/B = probe_body(4, "Bea")
	B.SetWeakened(8)
	spawn(5)
		B.Weaken(12)
	probe_check(!B.try_get_up() && B.weakened, "a fresh knockdown during the attempt ends it")

/proc/pressure_checks()
	var/mob/living/human/C = probe_body(6, "Cal")
	probe_check(!C.try_self_pressure("chest"), "nothing to press when nothing bleeds")
	C.hand = 0 // right hand
	var/obj/item/organ/external/RA = probe_bleed(C, "r_arm")
	probe_check(!C.try_self_pressure("r_arm"), "a hand can't hold its own arm")
	var/obj/item/organ/external/LL = probe_bleed(C, "l_leg")
	probe_check(C.try_self_pressure("r_arm") && LL.applied_pressure == C && C.self_pressure_r == LL, "the free hand holds the worst bleed it can reach")
	probe_check(!C.try_self_pressure("l_leg"), "the same hand doesn't hold one wound twice")
	C.hand = 1 // left hand
	probe_check(C.try_self_pressure("r_arm") && RA.applied_pressure == C && C.self_pressure_l == RA, "the other hand holds a second bleed")
	probe_check(LL.applied_pressure == C, "both bleeds stay held, one per hand")
	var/obj/item/organ/external/CH = probe_bleed(C, "chest")
	probe_check(C.try_self_pressure("chest") && CH.applied_pressure == C && !RA.applied_pressure && C.self_pressure_l == CH, "pressing elsewhere moves that hand")
	probe_check(C.check_pressure(C, "l_leg", "r_hand"), "an empty hand keeps holding")
	var/obj/item/weapon/flint/rock = new(C)
	C.r_hand = rock
	probe_check(!C.check_pressure(C, "l_leg", "r_hand") && !LL.applied_pressure && !C.self_pressure_r, "filling the hand lets go of the wound")
	C.r_hand = null
	qdel(rock)
	CH.status &= ~ORGAN_BLEEDING
	probe_check(!C.check_pressure(C, "chest", "l_hand") && !CH.applied_pressure, "pressure ends once the bleeding stops")
	C.Weaken(5)
	probe_check(C.try_self_pressure("l_leg") && LL.applied_pressure == C, "you can hold a wound while knocked down")

/proc/tourniquet_checks()
	var/mob/living/human/D = probe_body(8, "Dee")
	var/obj/item/organ/external/LA = D.get_organ("l_arm")
	var/obj/item/organ/external/LH = D.get_organ("l_hand")
	probe_check(LH.tourniquet_grade() == TOURNIQUET_NONE, "no tourniquet, no grade")
	LA.apply_tourniquet(TOURNIQUET_ROPE_TICKS)
	probe_check(LA.tourniquet_grade() == TOURNIQUET_MAKESHIFT && LH.tourniquet_grade() == TOURNIQUET_MAKESHIFT, "rope makes a makeshift tourniquet for the limb and below")
	LH.apply_tourniquet()
	probe_check(LH.tourniquet_grade() == TOURNIQUET_FULL, "a proper tourniquet below still stops everything")
	LH.remove_tourniquet()
	LA.tourniquet_ticks = TOURNIQUET_ROPE_TICKS - 2
	LA.handle_tourniquet()
	probe_check(LA.tourniquet, "a rope tourniquet holds for a while")
	LA.handle_tourniquet()
	probe_check(!LA.tourniquet && !LA.tourniquet_makeshift, "then it slips loose and must be replaced")
	probe_check(TOURNIQUET_TWINE_TICKS < TOURNIQUET_ROPE_TICKS, "twine gives way sooner than rope")
	var/obj/item/stack/medical/bruise_pack/gauze = new(D.loc)
	probe_check(!stack_tourniquet(D, LA, D, gauze, 30), "gauze doesn't tourniquet an unhurt limb")
	var/obj/item/stack/material/rope/rope = new(D.loc)
	probe_check(!stack_tourniquet(D, LA, D, rope, 40, TOURNIQUET_ROPE_TICKS), "rope doesn't tourniquet an unhurt limb")
	LA.apply_tourniquet(TOURNIQUET_ROPE_TICKS)
	LA.status |= ORGAN_BLEEDING
	probe_check(!stack_tourniquet(D, LA, D, gauze, 30), "gauze bandages bleeding under a makeshift tourniquet instead of loosening it")
	probe_check(!D.get_organ("chest").can_take_tourniquet(), "tourniquets only go on arms and legs")

// Blood lost from a cut arm artery in one heart beat, with the arm prepared by setup.
/proc/probe_artery_loss(x, makeshift, full, held)
	var/mob/living/human/E = probe_body(x, "Eve[x]")
	E.vessel.add_reagent("blood", E.species.blood_volume - E.vessel.total_volume)
	var/obj/item/organ/heart/heart = E.internal_organs_by_name["heart"]
	heart.pulse = PULSE_NORM
	var/obj/item/organ/external/arm = E.get_organ("l_arm")
	arm.status |= ORGAN_ARTERY_CUT | ORGAN_BLEEDING
	if (makeshift)
		arm.apply_tourniquet(TOURNIQUET_ROPE_TICKS)
	if (full)
		arm.apply_tourniquet()
	if (held)
		arm.applied_pressure = E
	var/before = E.vessel.get_reagent_amount("blood")
	heart.handle_blood()
	return before - E.vessel.get_reagent_amount("blood")

/proc/bleeding_checks()
	var/open = probe_artery_loss(10, FALSE, FALSE, FALSE)
	var/makeshift = probe_artery_loss(11, TRUE, FALSE, FALSE)
	var/held = probe_artery_loss(12, TRUE, FALSE, TRUE)
	var/full = probe_artery_loss(13, FALSE, TRUE, FALSE)
	probe_check(open > 0, "a cut artery bleeds ([open])")
	probe_check(makeshift > 0 && makeshift < open, "a makeshift tourniquet slows it ([makeshift] < [open])")
	probe_check(held == 0, "a makeshift tourniquet plus a hand on the wound stops it ([held])")
	probe_check(full == 0, "a proper tourniquet stops it ([full])")

/proc/brace_checks()
	var/mob/living/human/F = probe_body(15, "Fay")
	var/obj/item/organ/external/CH = F.get_organ("chest")
	var/obj/item/organ/external/RA = F.get_organ("r_arm")
	var/obj/item/organ/external/LL = F.get_organ("l_leg")
	CH.fracture()
	CH.perma_injury = 20 // the brute the break was dealt with
	probe_check(CH.is_broken(), "a loose rib fracture counts as broken")
	F.hand = 1 // left hand
	probe_check(F.try_self_pressure("chest") && F.self_brace_l == CH, "a free hand holds a broken bone that isn't bleeding")
	probe_check(!CH.is_broken() && CH.is_held_still(), "a held break is kept still like a splint")
	probe_check(CH.get_damage() == CH.brute_dam + CH.burn_dam && CH.get_damage() < 20, "a held break drops the lasting fracture pain")
	probe_check(!F.try_self_pressure("chest"), "the same hand doesn't hold one bone twice")
	var/obj/item/weapon/flint/rock = new(F)
	F.l_hand = rock
	probe_check(CH.is_broken(), "filling the hand stops holding the bone at once")
	F.check_self_brace("l_hand", CH)
	probe_check(!F.self_brace_l, "and lets go of it")
	F.l_hand = null
	qdel(rock)
	probe_check(CH.is_broken(), "an emptied hand doesn't grab the bone again by itself")
	RA.fracture()
	F.hand = 0 // right hand
	probe_check(F.try_self_pressure("r_arm") && F.self_brace_r == CH, "a hand can't hold its own broken arm, so it holds the next break")
	F.hand = 1
	probe_check(F.try_self_pressure("r_arm") && F.self_brace_l == RA && F.self_brace_r == CH, "the other hand holds the broken arm")
	LL.fracture()
	LL.status |= ORGAN_BLEEDING
	probe_check(F.try_self_pressure("l_leg") && LL.applied_pressure == F && !F.self_brace_l && !LL.is_broken(), "pressing on a bleeding break also holds the bone")
	LL.status &= ~ORGAN_BLEEDING
	F.check_pressure(F, "l_leg", "l_hand")
	probe_check(F.self_brace_l == LL && !LL.is_broken(), "once it stops bleeding the hand keeps holding the bone")
	CH.status |= ORGAN_SPLINTED
	F.check_self_brace("r_hand", CH)
	probe_check(!F.self_brace_r, "a splint takes over from the hand")
	F.set_stat(UNCONSCIOUS)
	probe_check(LL.is_broken(), "an unconscious hand holds nothing")
