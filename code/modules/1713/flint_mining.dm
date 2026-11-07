// Flint mining and knapping. See docs/flint-mining.md.
// Included after rocks.dm, ooga_booga_weapons.dm and animal_harvest.dm: the
// flint, branch and deer overrides below fall back to those definitions.

#define FLINT_NODULE_CHANCE 20
#define FLINT_NODULE_CHANCE_SANDY 5
#define GUNFLINT_SHOTS_MIN 25
#define GUNFLINT_SHOTS_MAX 40
#define GUNFLINT_WORN_MISFIRE 50

// Mined rock: one independent flint roll per wall, separate from the ore rolls,
// so the ore table in docs/mining-drop-balance.md is unchanged.
/turf/proc/mining_flint_nodules(mob/living/human/H, area/area_above)
	var/chance = FLINT_NODULE_CHANCE
	if (istype(src, /turf/floor/dirt/underground/sandy) || (area_above && area_above.climate == "desert"))
		chance = FLINT_NODULE_CHANCE_SANDY
	if (!prob(chance))
		return 0
	var/count = rand(1, 3)
	if (istype(get_area(src), /area/caribbean/void/caves/special))
		count *= 2
	for (var/i = 1, i <= count, i++)
		new /obj/item/weapon/flint(src)
	if (H)
		to_chat(H, SPAN_GREEN_BOLD("You found some <font color=#6f6a64><b>flint nodules</b></font>!"))
	return count

// Stags (and reindeer of either sex) give two antlers when butchered.
/mob/living/simple_animal/deer/proc/antler_count()
	if (babydeer || istype(src, /mob/living/simple_animal/deer/dikdik))
		return 0
	if (female && !istype(src, /mob/living/simple_animal/deer/reindeer))
		return 0
	return 2

/mob/living/simple_animal/deer/harvest_products(turf/site, skin)
	..()
	for (var/i = 1, i <= antler_count(), i++)
		new /obj/item/weapon/material/pickaxe/antler(site)

// A shed antler trimmed to its brow tine: the Neolithic flint miner's pick.
/obj/item/weapon/material/pickaxe/antler
	name = "antler pick"
	desc = "A deer antler trimmed down to its brow tine. Neolithic miners levered chalk and flint loose with picks like this."
	icon = 'icons/obj/flint_mining.dmi'
	icon_state = "antler_pick"
	item_state = "pickaxe"
	flags = 0
	default_material = "bone"
	applies_material_colour = FALSE
	usespeed = 0.8
	value = 2

/obj/item/weapon/material/pickaxe/antler/set_material(new_material)
	..()
	name = initial(name)
	health = 10
	maxhealth = 10

// Knapping: strike a flint with a hammerstone (unsharpened flint or stone).
/obj/item/stack/arrowhead/flint
	name = "flint arrowhead"
	desc = "A knapped flint point. Attach it to an arrow or bolt shaft."
	icon = 'icons/obj/flint_mining.dmi'
	icon_state = "flint_arrowheads"

/obj/item/weapon/flint_spearhead
	name = "flint spearhead"
	desc = "A long knapped flint point. Use it on a branch to make a spear."
	icon = 'icons/obj/flint_mining.dmi'
	icon_state = "flint_spearhead"
	w_class = ITEM_SIZE_SMALL
	force = 6
	sharp = FALSE
	edge = FALSE
	flammable = FALSE
	value = 2

/obj/item/weapon/material/kitchen/utensil/knife/flint
	desc = "A knapped flint blade with a wrapped grip. Sharp, but it chips with use."
	default_material = "flint"

/obj/item/weapon/material/spear/flint
	desc = "A wooden shaft tipped with a knapped flint point."
	default_material = "flint"
	force_divisor = 0.45

/obj/item/weapon/flint/proc/is_hammerstone(obj/item/I)
	if (istype(I, /obj/item/stack/material/stone))
		return TRUE
	if (istype(I, /obj/item/weapon/flint))
		var/obj/item/weapon/flint/F = I
		return !F.sharpened
	return FALSE

/obj/item/weapon/flint/proc/knap_reachable(mob/living/human/H, obj/item/hammer)
	if (QDELETED(src) || QDELETED(hammer) || hammer.loc != H || H.get_active_hand() != hammer || H.stat != CONSCIOUS || H.incapacitated())
		return FALSE
	return loc == H || (isturf(loc) && get_dist(src, H) <= 1)

/obj/item/weapon/flint/attackby(obj/item/M as obj, mob/user as mob)
	if (ishuman(user) && M != src && is_hammerstone(M))
		knap(user, M)
		return
	..()

/obj/item/weapon/flint/proc/knap(mob/living/human/H, obj/item/hammer)
	if (!H.may_do_after || !knap_reachable(H, hammer))
		return
	var/list/options = list()
	if (!sharpened)
		options += "Sharp flake"
	options += list("Three arrowheads", "Flint knife", "Spearhead", "Cancel")
	var/choice = WWinput(H, "What do you want to knap from \the [src]?", "Knapping", "Cancel", options)
	if (!choice || choice == "Cancel" || (choice == "Sharp flake" && sharpened) || !knap_reachable(H, hammer))
		return
	var/delay = 40
	var/fail_chance = 10
	switch (choice)
		if ("Three arrowheads")
			delay = 60
			fail_chance = 25
		if ("Flint knife")
			delay = 80
			fail_chance = 35
		if ("Spearhead")
			delay = 80
			fail_chance = 30
	H.visible_message(SPAN_NOTICE("[H] starts knapping \the [src] with \the [hammer]."), SPAN_NOTICE("You start knapping \the [src] with \the [hammer]."))
	playsound(get_turf(src), 'sound/effects/chop.ogg', 60, TRUE)
	if (!do_after(H, delay / max(0.5, H.getStatCoeff("dexterity")), src) || !knap_reachable(H, hammer))
		return
	H.adaptStat("crafting", 1)
	var/turf/T = get_turf(src)
	var/in_hand = loc == H
	if (prob(fail_chance / max(0.5, H.getStatCoeff("crafting"))))
		H.visible_message(SPAN_WARNING("\The [src] shatters under [H]'s blow."), SPAN_WARNING("The flint shatters. Only a sharp shard is left."))
		qdel(src)
		var/obj/item/weapon/material/shard/S = new /obj/item/weapon/material/shard(T, "flint")
		if (S && !QDELETED(S))
			S.name = "flint shard"
			if (in_hand)
				H.put_in_hands(S)
		return
	var/obj/item/result = null
	switch (choice)
		if ("Sharp flake")
			sharpen()
			to_chat(H, SPAN_NOTICE("You strike off a sharp flake."))
			return
		if ("Three arrowheads")
			result = new /obj/item/stack/arrowhead/flint(T, 3)
		if ("Flint knife")
			result = new /obj/item/weapon/material/kitchen/utensil/knife/flint(T)
		if ("Spearhead")
			result = new /obj/item/weapon/flint_spearhead(T)
	qdel(src)
	if (result && in_hand)
		H.put_in_hands(result)
	to_chat(H, SPAN_NOTICE("You knap \a [result]."))

/obj/item/weapon/branch/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (!istype(W, /obj/item/weapon/flint_spearhead) || !ishuman(user))
		return ..()
	var/mob/living/human/H = user
	if (!H.may_do_after)
		return
	to_chat(H, SPAN_NOTICE("You start lashing \the [W] to \the [src]..."))
	if (!do_after(H, 50, src) || QDELETED(W) || QDELETED(src) || W.loc != H || !(loc == H || (isturf(loc) && get_dist(src, H) <= 1)))
		return
	var/turf/T = get_turf(src)
	qdel(W)
	qdel(src)
	var/obj/item/weapon/material/spear/flint/S = new /obj/item/weapon/material/spear/flint(T)
	H.put_in_hands(S)
	to_chat(H, SPAN_NOTICE("You make \a [S]."))


// Steel fire striker: strike it against a flint held in the other hand to
// throw sparks. A lighter subtype, so candles, pipes and cigarettes accept it,
// but it only stays "lit" for a few seconds and needs a flint each time.
/obj/item/weapon/flame/lighter/striker
	name = "fire striker"
	desc = "A curved steel strike-a-light. Hold a flint in your other hand and strike it to throw sparks for lighting candles and pipes."
	icon = 'icons/obj/flint_mining.dmi'
	icon_state = "striker"
	item_state = "zippo"
	base_state = "striker"
	flammable = FALSE
	value = 3
	sound_toggleON = 'sound/effects/chop.ogg'
	sound_toggleOFF = null
	var/spark_chance = 70

/obj/item/weapon/flame/lighter/striker/attack_self(mob/living/user)
	if (user.r_hand != src && user.l_hand != src)
		return
	if (lit)
		snuff()
		return
	var/obj/item/weapon/flint/F = user.get_inactive_hand()
	if (!istype(F))
		to_chat(user, SPAN_WARNING("You need a flint in your other hand to strike \the [src] against."))
		return
	user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	playsound(get_turf(src), sound_toggleON, 30, TRUE)
	if (!prob(spark_chance))
		to_chat(user, SPAN_NOTICE("You strike \the [src] against \the [F], but no spark catches."))
		return
	lit = TRUE
	icon_state = "strikeron"
	set_light(1)
	user.visible_message(SPAN_NOTICE("[user] strikes \the [src] against \the [F], throwing sparks."), SPAN_NOTICE("Sparks fly. You have a few seconds to light something."))
	if (prob(3))
		to_chat(user, SPAN_WARNING("\The [F] crumbles away."))
		qdel(F)
	addtimer(CALLBACK(src, PROC_REF(snuff)), 5 SECONDS)

/obj/item/weapon/flame/lighter/striker/proc/snuff()
	if (!lit)
		return
	lit = FALSE
	icon_state = base_state
	set_light(0)

// Gunflint wear: a flintlock's flint lasts a few dozen shots, then misfires
// half the time until a new sharpened flint is fitted.
/obj/item/weapon/gun/projectile/flintlock
	var/gunflint_shots = -1 // -1 = a fresh flint, rolled on first use
	var/tmp/gunflint_aim_check = FALSE // aiming asks special_check without firing

/obj/item/weapon/gun/projectile/flintlock/proc/gunflint_left()
	if (gunflint_shots < 0)
		gunflint_shots = rand(GUNFLINT_SHOTS_MIN, GUNFLINT_SHOTS_MAX)
	return gunflint_shots

/obj/item/weapon/gun/projectile/flintlock/special_check(mob/user)
	. = ..()
	if (!. || gunflint_aim_check || gunflint_left() > 0 || !prob(GUNFLINT_WORN_MISFIRE))
		return
	cocked = FALSE
	update_icon()
	playsound(get_turf(src), 'sound/weapons/guns/interact/bolt_close.ogg', 50, TRUE)
	to_chat(user, SPAN_WARNING("The worn flint in \the [src] fails to spark. Fit a new sharpened flint."))
	return FALSE

/obj/item/weapon/gun/projectile/flintlock/can_hit(atom/target, mob/living/user)
	gunflint_aim_check = TRUE
	. = ..()
	gunflint_aim_check = FALSE

/obj/item/weapon/gun/projectile/flintlock/handle_post_fire()
	..()
	if (gunflint_left() > 0)
		gunflint_shots--
		if (gunflint_shots == 0 && ismob(loc))
			to_chat(loc, SPAN_WARNING("The flint in \the [src] is worn down. It will misfire until you fit a new sharpened flint."))

/obj/item/weapon/gun/projectile/flintlock/examine(mob/user, distance = -1)
	. = ..()
	if (get_dist(user, src) <= 1)
		to_chat(user, gunflint_left() > 0 ? "Its flint still has an edge." : SPAN_WARNING("Its flint is worn down and will misfire."))

/obj/item/weapon/gun/projectile/flintlock/attackby(obj/item/I, mob/user)
	if (!istype(I, /obj/item/weapon/flint) || !ishuman(user))
		return ..()
	var/obj/item/weapon/flint/F = I
	var/mob/living/human/H = user
	if (!F.sharpened)
		to_chat(H, SPAN_WARNING("Only a sharpened flint will strike a spark in \the [src]."))
		return
	if (!H.may_do_after)
		return
	to_chat(H, SPAN_NOTICE("You start fitting \the [F] into the cock of \the [src]..."))
	if (!do_after(H, 30, src) || QDELETED(F) || F.loc != H || QDELETED(src) || !(loc == H || (isturf(loc) && get_dist(src, H) <= 1)))
		return
	qdel(F)
	gunflint_shots = rand(GUNFLINT_SHOTS_MIN, GUNFLINT_SHOTS_MAX)
	to_chat(H, SPAN_NOTICE("You fit a fresh flint into \the [src]."))

#undef GUNFLINT_SHOTS_MIN
#undef GUNFLINT_SHOTS_MAX
#undef GUNFLINT_WORN_MISFIRE
#undef FLINT_NODULE_CHANCE
#undef FLINT_NODULE_CHANCE_SANDY
