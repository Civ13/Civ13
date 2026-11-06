// Raiders who take prisoners, and raiders who give chase (docs/nomad-raids.md#captives).
//
// Some raiders carry restraints. In a fight, a raider with restraints next to
// the person they are fighting wrenches weapons out of their hands, knocks them
// down, binds their wrists, and strips everything they wear and carry, one
// piece at a time. A bound person is no longer fought. Stripped gear goes into
// the raider's pack while there is room and is otherwise left on the ground
// for the looting that follows.
//
// A raider whose foe runs off keeps after them while they stay within
// NOMAD_RAID_CHASE_RANGE of the target and the fight lasts.

#define NOMAD_RAID_DISARM_CHANCE 50
#define NOMAD_RAID_KNOCKDOWN_CHANCE 40
#define NOMAD_RAID_KNOCKDOWN_TIME 4 // weakened ticks, long enough to bind them
#define NOMAD_RAID_CHASE_RANGE 30 // farthest from the target a fleeing foe is chased

/mob/living/simple_animal/hostile/human/nomad_raider
	var/tmp/obj/item/weapon/handcuffs/cuffs // unsaved until they are on someone

/datum/nomad_raid
	var/tmp/list/captives = list() // member = the person they bound and are stripping
	var/tmp/list/quarry = list() // member = the person they last fought
	var/tmp/bound = 0
	var/tmp/stripped = 0

// Rope before metalworking spreads, iron cuffs before industry, then handcuffs.
/proc/nomad_raid_cuff_type(age)
	if (age >= 6)
		return /obj/item/weapon/handcuffs
	if (age >= 4)
		return /obj/item/weapon/handcuffs/old
	return /obj/item/weapon/handcuffs/rope

/mob/living/simple_animal/hostile/human/nomad_raider/proc/give_cuffs(age)
	if (cuffs)
		return cuffs
	var/path = nomad_raid_cuff_type(age)
	cuffs = new path(src)
	cuffs.should_save = FALSE
	return cuffs

/mob/living/simple_animal/hostile/human/nomad_raider/proc/lose_cuffs()
	if (cuffs && !QDELETED(cuffs) && cuffs.loc == src)
		qdel(cuffs)
	cuffs = null

// A bound person can be stripped: anyone who can be reached and is restrained.
/proc/nomad_raid_bound(mob/living/human/H)
	return istype(H) && H.handcuffed

// One step of taking a prisoner. Returns TRUE when M spent its turn on it.
/datum/nomad_raid/proc/capture_step(mob/living/simple_animal/hostile/human/nomad_raider/M)
	if (kind != "raid" || !M || M.stat != CONSCIOUS)
		return FALSE
	var/mob/living/human/V = captives[M]
	if (V && (QDELETED(V) || V.stat == DEAD || !nomad_raid_bound(V)))
		captives -= M
		V = null
	if (!V)
		if (!M.cuffs)
			return FALSE
		V = M.target_mob
		if (!ishuman(V) || !foe_ok(V))
			return FALSE
	if (get_dist(M, V) > 1 || V.z != M.z)
		if (captives[M])
			order_move(M, V)
			return TRUE
		return FALSE
	M.set_dir(get_dir(M, V))
	if (!nomad_raid_bound(V))
		var/list/held = list()
		if (V.l_hand)
			held += V.l_hand
		if (V.r_hand)
			held += V.r_hand
		if (held.len)
			if (prob(NOMAD_RAID_DISARM_CHANCE))
				for (var/obj/item/I in held)
					V.drop_from_inventory(I)
				M.visible_message(SPAN_DANGER("\The [M] wrenches [english_list(held)] out of [V]'s hands!"))
				event("disarm", "[M.name] disarmed [V.real_name]")
			return TRUE
		if (!V.lying)
			if (prob(NOMAD_RAID_KNOCKDOWN_CHANCE))
				V.Weaken(NOMAD_RAID_KNOCKDOWN_TIME)
				M.visible_message(SPAN_DANGER("\The [M] knocks [V] to the ground!"))
				event("knockdown", "[M.name] knocked down [V.real_name]")
			return TRUE
		if (!V.has_organ_for_slot(slot_handcuffed))
			return FALSE
		var/obj/item/weapon/handcuffs/C = M.cuffs
		M.cuffs = null
		C.should_save = TRUE // a normal item once someone wears it
		if (!V.equip_to_slot(C, slot_handcuffed) && V.handcuffed != C)
			M.cuffs = C
			C.should_save = FALSE
			return FALSE
		playsound(get_turf(V), C.cuff_sound, 30, 1, -2)
		M.visible_message(SPAN_DANGER("\The [M] binds [V]'s wrists with \the [C]!"))
		admin_attack_log(M, V, "Bound [V.real_name]", "Was bound by a nomad raider", "bound")
		captives[M] = V
		bound++
		event("bound", "[M.name] bound [V.real_name]")
		if (M.target_mob == V)
			M.target_mob = null
		return TRUE
	// Bound: take one thing they wear or carry.
	var/list/gear = V.get_equipped_items(TRUE)
	gear -= V.handcuffed
	if (!gear.len)
		captives -= M
		stripped++
		event("stripped", "[M.name] stripped [V.real_name]")
		return TRUE
	var/obj/item/I = gear[1]
	if (!V.unEquip(I, TRUE, get_turf(V)))
		V.drop_from_inventory(I, get_turf(V))
	if (I.loc != get_turf(V))
		I.forceMove(get_turf(V))
	M.visible_message(SPAN_DANGER("\The [M] strips \the [I] off [V]."))
	M.take_item(I)
	return TRUE

// A foe M fought who ran: chase while they are close enough to the target.
/datum/nomad_raid/proc/chase_ok(mob/living/L)
	return foe_ok(L) && ishuman(L) && target && L.z == target.z && get_dist(L, target) <= NOMAD_RAID_CHASE_RANGE

/datum/nomad_raid/proc/chase_step(mob/living/simple_animal/hostile/human/nomad_raider/M)
	var/mob/living/L = quarry[M]
	if (!L)
		return FALSE
	if (!chase_ok(L))
		quarry -= M
		return FALSE
	order_move(M, L)
	return TRUE

// TRUE while anyone a member fought is still within chasing range.
/datum/nomad_raid/proc/quarry_left()
	for (var/M in quarry)
		if (chase_ok(quarry[M]))
			return TRUE
	return FALSE

#undef NOMAD_RAID_DISARM_CHANCE
#undef NOMAD_RAID_KNOCKDOWN_CHANCE
#undef NOMAD_RAID_KNOCKDOWN_TIME
