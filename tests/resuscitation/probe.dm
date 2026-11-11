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
/obj/map_metadata/resuscitation_probe/New()
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
		map = new /obj/map_metadata/resuscitation_probe
		if (!all_species.len)
			makeDatumRefLists()
		for (var/turf/T in block(locate(1, 1, 1), locate(20, 20, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		resuscitation_checks()
	catch(var/exception/e)
		probe_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("checks" = probe_checks, "failures" = probe_failures, "runtime_error" = probe_runtime_error)), "result.json")
	del(world)

/proc/probe_body(x, name)
	var/mob/living/human/H = new(locate(x, 5, 1))
	H.name = name
	H.real_name = name
	H.vessel.add_reagent("blood", H.species.blood_volume - H.vessel.total_volume)
	H.fixblood()
	return H

/proc/probe_dead(x, name)
	var/mob/living/human/H = probe_body(x, name)
	H.death()
	H.timeofdeath = world.time - 3000 // the examine lines need a past time of death
	return H

/proc/resuscitation_checks()
	// A fresh death opens the window and stashes what the person knew.
	var/mob/living/human/A = probe_body(2, "Abel")
	A.known_recipe_nodes = list("probe_node")
	A.death()
	A.timeofdeath = world.time - 3000
	probe_check(A.stat == DEAD && A.revival_clock > 0, "a death starts the revival clock")
	probe_check(!length(A.known_recipe_nodes) && ("probe_node" in A.revival_recipe_nodes), "the dead forget, but the knowledge is kept for a revival")
	probe_check(!A.resuscitation_blocker(), "a fresh, intact body can be revived: [A.resuscitation_blocker()]")
	probe_check(A.revivable_now(), "the medic hint says a revive could work")
	probe_check(findtext(jointext(A.death_time_lines(probe_medic()), "|"), "CPR or a defibrillator might still"), "medics are told CPR or a defibrillator could help")
	probe_check(A.restart_from_death(null), "a fresh body comes back")
	probe_check(A.stat != DEAD && (A in living_mob_list) && !(A in dead_mob_list), "the revived are living again")
	probe_check(("probe_node" in A.known_recipe_nodes) && !A.revival_recipe_nodes, "the revived remember what they knew")
	probe_check(!A.revival_clock && !A.start_to_rot && !A.corpse_decay_record, "a revival clears the death clock and decay")
	probe_check(!A.restart_from_death(null), "the living cannot be revived again")

	// Too long dead.
	var/mob/living/human/B = probe_dead(4, "Bea")
	B.revival_clock = world.time - B.revival_window() - 1
	probe_check(findtext(B.resuscitation_blocker(), "dead too long") && !B.revivable_now(), "too long dead stays dead")
	probe_check(findtext(jointext(B.death_time_lines(probe_medic()), "|"), "too late"), "medics are told it is too late")
	B.revival_clock = 0
	probe_check(findtext(B.resuscitation_blocker(), "dead too long"), "a body without a fresh death (loaded from a save) stays dead")

	// Poison.
	var/mob/living/human/C = probe_dead(6, "Cass")
	C.reagents.add_reagent("toxin", 30)
	probe_check(findtext(C.resuscitation_blocker(), "poison") && !C.revivable_now(), "extreme poison keeps them dead")
	C.reagents.clear_reagents()
	C.reagents.add_reagent("toxin", 5)
	probe_check(!C.resuscitation_blocker(), "a little poison does not: [C.resuscitation_blocker()]")

	// Decapitation and missing organs.
	var/mob/living/human/D = probe_dead(8, "Dov")
	var/obj/item/organ/external/head = D.organs_by_name["head"]
	D.organs_by_name["head"] = null
	probe_check(findtext(D.resuscitation_blocker(), "no head"), "no head, no revival")
	D.organs_by_name["head"] = head
	var/obj/item/organ/heart = D.internal_organs_by_name["heart"]
	D.internal_organs_by_name -= "heart"
	probe_check(findtext(D.resuscitation_blocker(), "vital organ"), "a missing heart keeps them dead")
	D.internal_organs_by_name["heart"] = heart
	D.can_defib = FALSE
	probe_check(findtext(D.resuscitation_blocker(), "ruined"), "a ruined body stays dead")
	D.can_defib = TRUE
	var/obj/item/organ/brain/brain = D.internal_organs_by_name["brain"]
	brain.damage = 60
	probe_check(findtext(D.resuscitation_blocker(), "brain"), "a destroyed brain (succumbing) stays dead")
	brain.damage = 0

	// Rot.
	D.rotting_stage = 1
	probe_check(findtext(D.resuscitation_blocker(), "rot"), "a rotting body stays dead")
	D.rotting_stage = 0
	probe_check(!D.resuscitation_blocker(), "once restored the body could be revived again")

	// Wounds and blood loss need treatment first, but do not end the chance.
	var/mob/living/human/E = probe_dead(10, "Eda")
	E.adjustBruteLoss(250)
	probe_check(findtext(E.resuscitation_blocker(), "Treat them first") && E.revivable_now(), "lethal wounds must be treated first")
	probe_check(findtext(jointext(E.death_time_lines(probe_medic()), "|"), "might then bring them back"), "medics are told to treat first")
	probe_check(!E.restart_from_death(null), "a body with lethal wounds is not restarted")
	E.heal_overall_damage(250, 250)
	E.vessel.remove_reagent("blood", E.vessel.get_reagent_amount("blood") * 0.9)
	probe_check(findtext(E.resuscitation_blocker(), "blood"), "too little blood must be replaced first")

	// Spirit.
	var/mob/living/human/F = probe_dead(12, "Fen")
	F.revival_ckey = "probegone"
	probe_check(findtext(F.resuscitation_blocker(), "spirit"), "a player who left or moved on cannot be pulled back")
	F.ckey = "probegone"
	probe_check(!F.resuscitation_blocker(), "a logged-out player still bound to the body can be revived: [F.resuscitation_blocker()]")
	F.ckey = null

	// Corpse decorations.
	var/mob/living/human/corpse/G = new(locate(14, 5, 1))
	G.death()
	probe_check(G.stat != DEAD || findtext(G.resuscitation_blocker(), "beyond"), "mapped corpses are never revived")

	// CPR odds and brain damage.
	var/mob/living/human/rescuer = probe_body(15, "Rescuer")
	var/mob/living/human/H = probe_dead(16, "Hal")
	var/plain = H.cpr_revival_chance(rescuer)
	H.reagents.add_reagent("adrenaline", 10)
	probe_check(H.cpr_revival_chance(rescuer) > plain && plain > 0, "adrenaline improves the CPR odds ([plain] -> [H.cpr_revival_chance(rescuer)])")
	H.setBrainLoss(0)
	H.apply_revival_brain_damage(config.defib_braindamage_timer MINUTES)
	probe_check(H.getBrainLoss() == 0, "a quick revival does no brain damage")
	H.apply_revival_brain_damage(H.revival_window())
	probe_check(H.getBrainLoss() > 0 && H.getBrainLoss() < 60, "a late revival leaves survivable brain damage ([H.getBrainLoss()])")

	// The defibrillator uses the same rules.
	var/obj/item/weapon/shockpaddles/P = new(locate(18, 5, 1))
	var/mob/living/human/I = probe_dead(18, "Ida")
	probe_check(!P.can_revive(I), "a defibrillator can revive a fresh body")
	I.revival_clock = 0
	probe_check(findtext(P.can_revive(I), "dead too long"), "a defibrillator gives the same reason: [P.can_revive(I)]")

/proc/probe_medic()
	var/mob/living/human/doc = new(locate(1, 1, 1))
	var/datum/job/J = new
	J.is_medic = TRUE
	doc.original_job = J
	return doc
