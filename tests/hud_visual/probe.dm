// Isolated test-only candidates. No production entry point or recovery verb.
var/hud_probe_assertions = 0
var/hud_probe_faults = 0
var/hud_probe_unexpected = FALSE
/world
	hub = ""
	hub_password = ""
	maxx = 3
	maxy = 3
	maxz = 1
/world/Error(exception/E)
	hud_probe_unexpected = TRUE
	text2file("UNEXPECTED [E]", "result.txt")
	world.log << "UNEXPECTED [E]"
/obj/map_metadata/hud_probe/New()
	return
/obj/screen/damageoverlay/hud_probe_fault
	var/inject_fault = TRUE
	var/health_calls = 0
/obj/screen/damageoverlay/hud_probe_fault/UpdateHealthState()
	health_calls++
	if (inject_fault)
		throw EXCEPTION("HUD_PROBE_INJECTED_HEALTH")
	return ..()
/obj/screen/damageoverlay/hud_probe_fault/reordered/update_icon()
	underlays.Cut()
	UpdateVisionState()
	overlays.Cut()
	UpdateHealthState()
/proc/hud_assert(ok, label)
	hud_probe_assertions++
	text2file(json_encode(list("assertion"=label, "pass"=!!ok)), "cases.jsonl")
	if (!ok)
		throw EXCEPTION("HUD ASSERT [label]")
/proc/hud_refs(list/L)
	var/list/result = list()
	for (var/V in L)
		result += "\ref[V]"
	return result
/proc/hud_black(obj/screen/damageoverlay/D)
	var/count = 0
	for (var/image/I in D.underlays)
		if (I.icon_state == "blackimageoverlay")
			count++
	return count
/proc/hud_state(mob/living/human/H, obj/screen/damageoverlay/D)
	var/list/state = list("body"="\ref[H]", "type"="[H.type]", "client"="\ref[H.client]", "mind"="\ref[H.mind]", "loc"="\ref[H.loc]", "parent"="\ref[D.parentmob]", "hud"="\ref[D]")
	for (var/key in list("key","ckey","real_name","lastx","lasty","lastz","stat","health","oxyloss","bruteloss","fireloss","halloss","damageoverlaytemp","sleeping","inducedSSD","paralysis","transforming","timeofdeath","eye_blind","blinded","eye_blurry","sdisabilities","equipment_tint_total","equipment_vision_flags","last_life_tick","traits_dirty","gcDestroyed"))
		if (key in H.vars)
			state[key] = H.vars[key]
	state["traits"] = H.traits.Copy()
	state["trait_cache"] = H.trait_cache ? H.trait_cache.Copy() : null
	state["contents"] = hud_refs(H.contents)
	state["living"] = hud_refs(living_mob_list)
	state["dead"] = hud_refs(dead_mob_list)
	state["HUDprocess"] = hud_refs(H.HUDprocess)
	state["species"] = "\ref[H.species]"
	var/list/organs_state = list()
	hud_assert(H.organs.len + H.internal_organs.len <= 64, "organ snapshot bound")
	for (var/obj/item/organ/O in (H.organs + H.internal_organs))
		var/list/entry = list("ref"="\ref[O]", "owner"="\ref[O.owner]", "loc"="\ref[O.loc]", "damage"=O.damage, "status"=O.status)
		for (var/key in list("brute_dam","burn_dam","germ_level","min_broken_damage"))
			if (key in O.vars)
				entry[key] = O.vars[key]
		organs_state += list(entry)
	state["organs"] = organs_state
	var/list/organ_index = list()
	for (var/key in H.internal_organs_by_name)
		var/obj/item/organ/O = H.internal_organs_by_name[key]
		organ_index[key] = "\ref[O]"
	state["organ_index"] = organ_index
	var/list/unrelated = list()
	for (var/image/I in D.underlays)
		if (I.icon_state != "blackimageoverlay")
			unrelated += list(list("icon"="[I.icon]", "state"=I.icon_state, "alpha"=I.alpha, "color"=I.color, "layer"=I.layer, "plane"=I.plane))
	state["unrelated_underlays"] = unrelated
	state["shared_blind_icon"] = list("icon"="[D.blind_icon.icon]", "state"=D.blind_icon.icon_state, "alpha"=D.blind_icon.alpha, "color"=D.blind_icon.color, "layer"=D.blind_icon.layer, "plane"=D.blind_icon.plane)
	var/list/gear = list()
	for (var/key in list("head","eyes","wear_mask","wear_suit","w_uniform","shoes","gloves","l_hand","r_hand","back","belt"))
		var/obj/item/I = H.vars[key]
		gear[key] = list("ref"="\ref[I]", "loc"=I ? "\ref[I.loc]" : null)
		if (istype(I, /obj/item/clothing))
			var/obj/item/clothing/C = I
			gear[key] += list("tint"=C.tint)
	state["gear"] = gear
	return json_encode(state)
/proc/hud_visual_only(mob/living/human/H, obj/screen/damageoverlay/D, completed_vision)
	// Fixture-local classification capability; not a production freshness API.
	if (!H || !D || D.parentmob != H || !H.loc || !completed_vision || H.gcDestroyed || D.gcDestroyed || H.transforming || !(H in living_mob_list))
		return FALSE
	if (!H.species || H.stat || H.sleeping || H.inducedSSD || H.paralysis || (H.sdisabilities & BLIND) || ("Blind" in H.traits))
		return FALSE
	if (H.species.vision_organ)
		var/obj/item/organ/vision = H.internal_organs_by_name[H.species.vision_organ]
		if (!vision || vision.is_broken())
			return FALSE
	var/tint = 0
	for (var/obj/item/clothing/C in list(H.head,H.eyes,H.wear_mask))
		tint += C.tint
	if (istype(H.eyes, /obj/item/clothing/glasses/sunglasses/blindfold) || tint >= TINT_BLIND || H.equipment_tint_total >= TINT_BLIND)
		return FALSE
	// Remove only the known blindness appearance; retain unrelated underlays.
	D.underlays -= list(D.blind_icon)
	D.UpdateVisionState()
	return TRUE
/proc/hud_preservation_case(label, mob/living/human/H, obj/screen/damageoverlay/D, completed_vision, expected_accept, expected_black)
	D.underlays.Cut()
	D.underlays += D.blind_icon
	D.underlays += image('icons/mob/screen1_full.dmi', "brutedamageoverlay1")
	var/before = hud_state(H,D)
	var/accepted = hud_visual_only(H,D,completed_vision)
	hud_assert(accepted == expected_accept, "[label] acceptance")
	hud_assert(hud_state(H,D) == before, "[label] exact selected state preserved")
	hud_assert((hud_black(D) > 0) == expected_black, "[label] black outcome")
	hud_visual_only(H,D,completed_vision)
	hud_assert(hud_state(H,D) == before, "[label] repeated preservation")
	hud_assert((hud_black(D) > 0) == expected_black, "[label] repeated black outcome")
/proc/hud_fault_case(obj/screen/damageoverlay/hud_probe_fault/D, expected_black, label)
	D.underlays += D.blind_icon
	var/caught = FALSE
	var/mob/living/human/H = D.parentmob
	var/list/saved_process = H.HUDprocess
	H.HUDprocess = list(D)
	try
		// Production widget loop and real process(), not player_ui_probe stubs.
		H.handle_regular_hud_updates()
	catch (var/exception/E)
		if (!findtext("[E]", "HUD_PROBE_INJECTED_HEALTH"))
			throw E
		caught = TRUE
		hud_probe_faults++
	H.HUDprocess = saved_process
	hud_assert(caught && D.health_calls == 1, "[label] exact injected fault caught once")
	hud_assert((hud_black(D) > 0) == expected_black, "[label] underlay order")
/world/New()
	world.OpenPort(0)
	text2file("entered", "entered.txt")
	try
		hud_assert(world.byond_version == 516 && world.byond_build == 1681, "pinned native runtime")
		map = new /obj/map_metadata/hud_probe
		var/mob/living/human/H = new(locate(2,2,1))
		hud_assert(H.organs.len && H.internal_organs.len && (H in living_mob_list), "actual human constructor and organs")
		H.create_HUDtech()
		var/obj/screen/damageoverlay/D = H.HUDtech["damageoverlay"]
		hud_assert(istype(D) && D.parentmob == H && (D in H.HUDprocess), "actual production create_HUDtech registered real damageoverlay")
		H.eye_blind = 0
		D.underlays += D.blind_icon
		D.process()
		hud_assert(!D.underlays.len, "immutable production normal control clears stale black")
		var/obj/screen/damageoverlay/hud_probe_fault/F = new("fault",null,H)
		var/obj/screen/damageoverlay/hud_probe_fault/reordered/R = new("reordered",null,H)
		hud_fault_case(F,TRUE,"immutable deployed order")
		hud_fault_case(R,FALSE,"test-only reordered candidate")
		H.eye_blind = 1
		var/obj/screen/damageoverlay/hud_probe_fault/reordered/B = new("blind",null,H)
		hud_fault_case(B,TRUE,"reordered authoritative blindness")
		H.eye_blind = 0
		H.damageoverlaytemp = 37
		hud_preservation_case("healthy",H,D,TRUE,TRUE,FALSE)
		H.eye_blind = 5
		hud_preservation_case("transient blindness",H,D,TRUE,TRUE,TRUE)
		H.eye_blind = 0
		H.sleeping = 6
		hud_preservation_case("sleep pre-Life",H,D,TRUE,FALSE,TRUE)
		H.sleeping = 0
		H.inducedSSD = TRUE
		hud_preservation_case("induced sleep",H,D,TRUE,FALSE,TRUE)
		H.inducedSSD = FALSE
		H.stat = UNCONSCIOUS
		hud_preservation_case("unconscious",H,D,TRUE,FALSE,TRUE)
		H.stat = DEAD
		hud_preservation_case("dead",H,D,TRUE,FALSE,TRUE)
		H.stat = CONSCIOUS
		H.paralysis = 5
		hud_preservation_case("paralysis",H,D,TRUE,FALSE,TRUE)
		H.paralysis = 0
		H.sdisabilities |= BLIND
		hud_preservation_case("blind disability pre-Life",H,D,TRUE,FALSE,TRUE)
		H.sdisabilities &= ~BLIND
		H.traits += "Blind"
		hud_preservation_case("blind trait pre-Life",H,D,TRUE,FALSE,TRUE)
		H.traits -= "Blind"
		var/obj/item/organ/V = H.internal_organs_by_name[H.species.vision_organ]
		hud_assert(V != null, "actual vision organ available")
		H.internal_organs_by_name[H.species.vision_organ] = null
		hud_preservation_case("missing eyes pre-Life",H,D,TRUE,FALSE,TRUE)
		H.internal_organs_by_name[H.species.vision_organ] = V
		var/old_damage = V.damage
		V.damage = V.min_broken_damage
		hud_preservation_case("broken eyes damage",H,D,TRUE,FALSE,TRUE)
		V.damage = old_damage
		var/old_status = V.status
		for (var/broken_flag in list(ORGAN_BROKEN,ORGAN_CUT_AWAY))
			V.status = old_status | broken_flag
			hud_preservation_case("broken eyes status [broken_flag]",H,D,TRUE,FALSE,TRUE)
		V.status = old_status
		H.eyes = new /obj/item/clothing/glasses/sunglasses/blindfold(H)
		hud_preservation_case("actual blindfold pre-Life",H,D,TRUE,FALSE,TRUE)
		H.eyes = null
		var/obj/item/clothing/head/C = new(H)
		C.tint = TINT_BLIND
		H.head = C
		hud_preservation_case("actual equipment tint pre-Life",H,D,TRUE,FALSE,TRUE)
		H.head = null
		hud_preservation_case("unknown completion",H,D,FALSE,FALSE,TRUE)
		H.transforming = TRUE
		hud_preservation_case("transform early return",H,D,TRUE,FALSE,TRUE)
		H.transforming = FALSE
		living_mob_list -= H
		H.last_life_tick = world.realtime
		hud_preservation_case("stopped Life despite fresh timestamp",H,D,TRUE,FALSE,TRUE)
		living_mob_list += H
		H.loc = null
		hud_preservation_case("null location",H,D,TRUE,FALSE,TRUE)
		H.loc = locate(2,2,1)
		D.parentmob = null
		hud_preservation_case("foreign HUD parent",H,D,TRUE,FALSE,TRUE)
		D.parentmob = H
		hud_assert(H.damageoverlaytemp == 37 && hud_probe_faults == 3, "visual-only never consumed health sentinel; exactly three injected faults")
		hud_assert(!hud_probe_unexpected, "no unexpected runtimes")
		text2file("PASS assertions=[hud_probe_assertions] tagged_faults=[hud_probe_faults] headless_only=1", "result.txt")
	catch (var/exception/E)
		text2file("FAIL [E]", "result.txt")
		world.log << "FAIL [E]"
	del(world)
