// Pouring and dropping from above (docs/siege-engines.md#pouring-and-dropping).
//
// - A container held over a lit fire, brazier, hearth or stove on grab intent
//   heats what it holds; it stays hot for two minutes.
// - Murder holes, machicolations and hoardings pour it, or drop anything else
//   held, onto the tile below them. A big pour (60 units or more) also splashes
//   the eight tiles around that tile at half strength.
// - Anything that falls through open air hits whoever it lands on, harder the
//   heavier it is (building_levels.dm).
// - A tar kiln burns wood into pitch.

#define POUR_HOT_TIME 1200		// ds a heated container stays hot
#define POUR_BIG 60				// units that splash the tiles around the target too
#define TAR_KILN_WOOD 10		// wood a tar kiln burns per batch
#define TAR_KILN_TIME 1200		// ds a batch burns
#define TAR_KILN_YIELD 40		// units of pitch a batch gives
#define SOLID_TIP_UNITS 10		// units one piece of sand, quicklime or lead adds

/obj/item/weapon/reagent_containers
	var/heated_until = 0	// world.time this stays hot until (castle_pour.dm)

// world.time doesn't carry over a reload, and a reload cools everything anyway.
/obj/item/weapon/reagent_containers/persistence_runtime_var(key)
	return key == "heated_until" || ..()

/obj/item/weapon/reagent_containers/proc/is_hot()
	return heated_until > world.time

// ---- new liquids ---------------------------------------------------------------

/datum/reagent/pitch
	name = "Pitch"
	id = "pitch"
	description = "Pine tar boiled down thick and black. It sticks to whatever it touches and burns fiercely."
	taste_description = "smoke and resin"
	reagent_state = LIQUID
	color = "#1a120c"

/datum/reagent/sand_grains
	name = "Sand"
	id = "sand_grains"
	description = "Loose dry sand."
	taste_description = "grit"
	reagent_state = SOLID
	color = "#d8c08a"

/datum/reagent/quicklime_powder
	name = "Quicklime"
	id = "quicklime_powder"
	description = "Burnt lime ground to a caustic white powder. It burns eyes and wet skin."
	taste_description = "burning chalk"
	reagent_state = SOLID
	color = "#f2f0e6"

// ---- what is poured -------------------------------------------------------------

// The pour liquid that leads in RG, or null if none of these: the hot metal and
// pitch first, then whichever of the rest there is most of.
/proc/pour_liquid_of(obj/item/weapon/reagent_containers/RG)
	if (!RG || !RG.reagents || !RG.reagents.total_volume)
		return null
	for (var/id in list("lead", "pitch"))
		if (RG.reagents.has_reagent(id))
			return id
	var/best = null
	var/best_amount = 0
	for (var/id in list("cornoil", "olive_oil", "fat_oil", "quicklime_powder", "sand_grains", "water"))
		var/amount = RG.reagents.get_reagent_amount(id)
		if (amount > best_amount)
			best = id
			best_amount = amount
	if (best in list("cornoil", "olive_oil", "fat_oil"))
		return "oil"
	return best || "other"

/proc/pour_colour(liquid)
	switch (liquid)
		if ("water")
			return "#6fa8dc"
		if ("oil")
			return "#c89a3c"
		if ("pitch")
			return "#2a1e16"
		if ("sand_grains")
			return "#d8c08a"
		if ("quicklime_powder")
			return "#f4f2ea"
		if ("lead")
			return "#aab4bc"
	return "#9aa0a8"

// Seconds over a fire before it counts as hot.
/proc/pour_heat_time(liquid)
	switch (liquid)
		if ("oil")
			return 80
		if ("pitch")
			return 100
		if ("sand_grains")
			return 60
		if ("lead")
			return 200
	return 50

// Burn damage one person takes at full strength, before armour.
/proc/pour_burn_damage(liquid, hot)
	if (!hot)
		return 0
	switch (liquid)
		if ("water", "other")
			return rand(8, 12)
		if ("oil")
			return rand(20, 30)
		if ("pitch")
			return rand(15, 25)
		if ("sand_grains")
			return rand(10, 15)
		if ("lead")
			return rand(35, 45)
	return 0

// ---- heating ----------------------------------------------------------------------

// A lit fire, brazier, hearth or stove that heats a held container.
/proc/pour_heat_source_lit(atom/A)
	if (istype(A, /obj/structure/brazier))
		var/obj/structure/brazier/B = A
		return B.on
	if (istype(A, /obj/structure/oven))
		var/obj/structure/oven/O = A
		return O.on
	return FALSE

// Grab intent with an open container over a lit fire heats it. Returns TRUE
// if it handled the click.
/proc/pour_heat_attackby(atom/source, obj/item/W, mob/user)
	if (!istype(W, /obj/item/weapon/reagent_containers) || !user || user.a_intent != I_GRAB)
		return FALSE
	var/obj/item/weapon/reagent_containers/RG = W
	if (!RG.is_open_container() || !RG.reagents || !RG.reagents.total_volume)
		return FALSE
	if (!pour_heat_source_lit(source))
		to_chat(user, SPAN_WARNING("\The [source] isn't lit."))
		return TRUE
	var/liquid = pour_liquid_of(RG)
	if (liquid == "quicklime_powder")
		to_chat(user, SPAN_NOTICE("Quicklime needs no heating; it burns as it is."))
		return TRUE
	user.visible_message(SPAN_NOTICE("[user] holds \the [RG] over \the [source]."), SPAN_NOTICE("You hold \the [RG] over \the [source] to heat it."))
	if (!do_after(user, pour_heat_time(liquid), source) || !pour_heat_source_lit(source))
		return TRUE
	RG.heated_until = world.time + POUR_HOT_TIME
	to_chat(user, SPAN_NOTICE(liquid == "lead" ? "The lead in \the [RG] melts and glows." : "\The [RG] is steaming hot. It stays hot for about two minutes."))
	return TRUE

/obj/structure/brazier/attackby(obj/item/W, mob/user)
	if (pour_heat_attackby(src, W, user))
		return
	return ..()

/obj/structure/oven/attackby(obj/item/I, mob/living/human/H)
	if (pour_heat_attackby(src, I, H))
		return TRUE
	return ..()

/obj/item/weapon/reagent_containers/examine(mob/user, distance = -1)
	. = ..(user, distance)
	if (is_hot())
		to_chat(user, SPAN_WARNING("It is hot."))

// ---- solids into a container --------------------------------------------------

// Tips one piece of a stack into an open container as SOLID_TIP_UNITS of id.
/proc/tip_solid_into(obj/item/stack/S, obj/item/weapon/reagent_containers/C, id, mob/user)
	if (!istype(C) || !C.is_open_container() || !C.reagents)
		return FALSE
	if (C.reagents.total_volume + SOLID_TIP_UNITS > C.reagents.maximum_volume)
		to_chat(user, SPAN_WARNING("\The [C] is too full."))
		return TRUE
	if (!S.use(1))
		return TRUE
	C.reagents.add_reagent(id, SOLID_TIP_UNITS)
	to_chat(user, SPAN_NOTICE("You put some [S.singular_name ? S.singular_name : S.name] into \the [C]."))
	return TRUE

/obj/item/stack/ore/glass/afterattack(atom/target, mob/user, proximity_flag, params)
	if (proximity_flag && istype(target, /obj/item/weapon/reagent_containers) && tip_solid_into(src, target, "sand_grains", user))
		return TRUE
	return ..()

/obj/item/stack/material/lead/afterattack(atom/target, mob/user, proximity_flag, params)
	if (proximity_flag && istype(target, /obj/item/weapon/reagent_containers) && tip_solid_into(src, target, "lead", user))
		return TRUE
	return ..()

// ---- pouring and dropping ------------------------------------------------------

// Where something poured or dropped through `opening` lands.
/obj/structure/proc/pour_target()
	return null

// Pours RG through `opening` onto T. Returns TRUE if anything was poured.
/proc/castle_pour(atom/opening, obj/item/weapon/reagent_containers/RG, mob/user, turf/T)
	var/liquid = pour_liquid_of(RG)
	if (!liquid || !T)
		return FALSE
	var/hot = RG.is_hot()
	if (liquid == "lead" && !hot)
		to_chat(user, SPAN_WARNING("The lead is solid. Melt it over a fire first."))
		return FALSE
	var/volume = RG.reagents.total_volume
	var/wet_with_lime = liquid == "quicklime_powder" && RG.reagents.has_reagent("water")
	user.visible_message(SPAN_DANGER("[user] pours \the [RG] down \the [opening]!"), SPAN_DANGER("You pour \the [RG] down \the [opening]."))
	var/list/strengths = list()
	strengths[T] = 1
	if (volume >= POUR_BIG)
		for (var/turf/N in orange(1, T))
			strengths[N] = 0.5
	for (var/turf/hit in strengths)
		pour_splash_effect(hit, liquid)
		for (var/mob/living/L in hit)
			pour_hit(L, liquid, hot, strengths[hit], wet_with_lime)
		if (liquid == "oil" || liquid == "pitch")
			var/obj/effect/castle_slick/old = locate() in hit
			if (old)
				old.expires_at = world.time + 600
			else
				var/obj/effect/castle_slick/S = new(hit)
				S.color = pour_colour(liquid)
	RG.reagents.splash(T, RG.reagents.total_volume)
	RG.heated_until = 0
	return TRUE

/proc/pour_splash_effect(turf/T, liquid)
	var/obj/effect/castle_splash/S = new(T)
	S.color = pour_colour(liquid)

// What one person takes from a pour at `strength` (1 under it, 0.5 beside it).
/proc/pour_hit(mob/living/L, liquid, hot, strength, wet_with_lime = FALSE)
	var/zone = pick("head", "chest", "l_arm", "r_arm")
	var/burn = round(pour_burn_damage(liquid, hot) * strength)
	if (liquid == "quicklime_powder")
		burn = round(rand(5, 10) * strength * (wet_with_lime ? 2 : 1))
		L.eye_blind = max(L.eye_blind, round(10 * strength))
	if (burn)
		var/blocked = 0
		// Sand gets in under mail and plate; liquids are partly turned by armour.
		if (liquid != "sand_grains")
			blocked = L.run_armor_check(zone, "melee") * 0.5
		L.apply_damage(burn, BURN, zone, blocked)
	switch (liquid)
		if ("water")
			L.ExtinguishMob()
			to_chat(L, hot ? SPAN_DANGER("Scalding water pours down on you from above!") : SPAN_WARNING("Water pours down on you from above."))
		if ("oil")
			to_chat(L, hot ? SPAN_DANGER("Boiling oil pours down on you from above!") : SPAN_WARNING("Oil pours down on you from above."))
		if ("pitch")
			if (hot)
				L.fire_stacks += round(3 * strength) + 1
				L.IgniteMob()
				to_chat(L, SPAN_DANGER("Burning pitch sticks to you and sets you alight!"))
			else
				to_chat(L, SPAN_WARNING("Sticky black pitch pours down on you."))
		if ("sand_grains")
			to_chat(L, hot ? SPAN_DANGER("Red-hot sand pours down on you and runs under your armour!") : SPAN_WARNING("Sand pours down on you."))
		if ("quicklime_powder")
			to_chat(L, SPAN_DANGER("Quicklime pours down on you, burning your eyes!"))
		if ("lead")
			to_chat(L, SPAN_DANGER("Molten lead pours down on you!"))
		else
			to_chat(L, hot ? SPAN_DANGER("Scalding liquid pours down on you from above!") : SPAN_WARNING("Something wet pours down on you from above."))

// Brute damage an item does to someone it falls on, before a helmet.
/proc/falling_item_damage(obj/item/I)
	if (!istype(I))
		return 0
	if (istype(I, /obj/item/stack/material/stone) || istype(I, /obj/item/stack/ore) || istype(I, /obj/item/stack/material/sandstone))
		return rand(15, 25)
	if (istype(I, /obj/item/stack/material/wood) || I.w_class >= ITEM_SIZE_HUGE)
		return rand(25, 35)
	switch (I.w_class)
		if (ITEM_SIZE_LARGE)
			return rand(15, 25)
		if (ITEM_SIZE_NORMAL)
			return rand(5, 10)
	return rand(0, 5)

// I has just landed on T from above: it hits whoever stands there.
/proc/falling_item_strike(obj/item/I, turf/T)
	if (!istype(I) || !T)
		return
	var/obj/effect/castle_falling_stone/F = new(T)
	F.icon_state = "falling_stone"
	for (var/mob/living/L in T)
		if (L.lying)
			continue
		var/damage = falling_item_damage(I)
		if (!damage)
			continue
		var/blocked = L.run_armor_check("head", "melee")
		L.apply_damage(damage, BRUTE, "head", blocked)
		L.visible_message(SPAN_DANGER("\The [I] falls from above and hits [L]!"), SPAN_DANGER("\The [I] falls from above and hits you on the head!"))
		if (damage >= 25 && ishuman(L))
			var/mob/living/human/H = L
			H.Weaken(2)
		break

// Drops a held item through `opening` onto T.
/proc/castle_drop(atom/opening, obj/item/I, mob/user, turf/T)
	if (!T || !user.unEquip(I))
		return FALSE
	user.visible_message(SPAN_DANGER("[user] drops \the [I] down \the [opening]!"), SPAN_DANGER("You drop \the [I] down \the [opening]."))
	I.forceMove(T)
	falling_item_strike(I, T)
	return TRUE

// Shared by every opening: a container is poured, anything else dropped.
/proc/castle_opening_attackby(obj/structure/opening, obj/item/W, mob/user)
	if (!W || !user || user.a_intent == I_HARM)
		return FALSE
	var/turf/T = opening.pour_target()
	if (!T)
		return FALSE
	if (istype(W, /obj/item/weapon/reagent_containers))
		var/obj/item/weapon/reagent_containers/RG = W
		if (RG.is_open_container() && RG.reagents && RG.reagents.total_volume)
			castle_pour(opening, RG, user, T)
			return TRUE
	if (is_tool(W, TOOL_HAMMER) || is_tool(W, TOOL_WRENCH))
		return FALSE
	castle_drop(opening, W, user, T)
	return TRUE

// ---- effects --------------------------------------------------------------------

/obj/effect/castle_splash
	name = "splash"
	icon = 'icons/obj/castle_defences.dmi'
	icon_state = "pour_splash"
	anchored = TRUE
	mouse_opacity = 0
	layer = TURF_LAYER + 2.3

/obj/effect/castle_splash/New()
	..()
	addtimer(CALLBACK(src, PROC_REF(expire)), 12)

/obj/effect/castle_splash/proc/expire()
	qdel(src)

/obj/effect/castle_falling_stone
	name = "falling stone"
	icon = 'icons/obj/castle_defences.dmi'
	icon_state = "falling_stone"
	anchored = TRUE
	mouse_opacity = 0
	layer = TURF_LAYER + 2.3

/obj/effect/castle_falling_stone/New()
	..()
	addtimer(CALLBACK(src, PROC_REF(expire)), 8)

/obj/effect/castle_falling_stone/proc/expire()
	qdel(src)

// A slick of oil or pitch. A torch or a fire arrow sets it alight.
/obj/effect/castle_slick
	name = "slick"
	desc = "A slippery, flammable slick. A torch would set it alight."
	icon = 'icons/obj/castle_defences.dmi'
	icon_state = "oil_slick"
	anchored = TRUE
	layer = TURF_LAYER + 2.1
	var/expires_at = 0

/obj/effect/castle_slick/persistence_runtime_var(key)
	return key == "expires_at" || ..()

/obj/effect/castle_slick/New()
	..()
	expires_at = world.time + 600
	addtimer(CALLBACK(src, PROC_REF(slick_check)), 50)

// A slick is a minute's work; it is gone after a reload.
/obj/effect/castle_slick/after_load()
	..()
	qdel(src)

/obj/effect/castle_slick/proc/slick_check()
	if (QDELETED(src))
		return
	if (world.time >= expires_at)
		qdel(src)
		return
	addtimer(CALLBACK(src, PROC_REF(slick_check)), 50)

/obj/effect/castle_slick/proc/ignite()
	var/turf/T = get_turf(src)
	if (!T)
		return
	T.visible_message(SPAN_DANGER("\The [src] bursts into flame!"))
	for (var/mob/living/L in T)
		L.fire_stacks += 3
		L.IgniteMob()
	new /obj/effect/fire(T)
	qdel(src)

/obj/effect/castle_slick/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/flashlight/torch))
		var/obj/item/flashlight/torch/TR = W
		if (TR.on)
			ignite()
			return
	return ..()

/obj/effect/castle_slick/bullet_act(obj/item/projectile/P, def_zone)
	if (istype(P, /obj/item/projectile/arrow/arrow/fire) || istype(P, /obj/item/projectile/arrow/bolt/fire))
		ignite()
	return PROJECTILE_CONTINUE

// ---- machicolations and hoardings ---------------------------------------------

// Built on the wall walk facing out: pours and drops one tile out and one
// level down, onto the foot of the wall (on one level, the tile in front).
/obj/structure/castle_overhang
	name = "machicolation"
	desc = "A stone parapet built out past the top of the wall on corbels, with openings in its floor. Pour hot liquids or drop stones through it onto whoever is at the foot of the wall."
	icon = 'icons/obj/castle_defences.dmi'
	icon_state = "machicolation"
	anchored = TRUE
	density = FALSE
	layer = 3.1
	not_movable = TRUE
	not_disassemblable = FALSE
	health = 600
	maxhealth = 600

/obj/structure/castle_overhang/pour_target()
	var/turf/T = get_turf(src)
	if (!T)
		return null
	var/turf/out = get_step(T, dir)
	if (!out)
		return null
	var/turf/below = GetBelow(out)
	return below ? below : out

/obj/structure/castle_overhang/attackby(obj/item/W, mob/user)
	if (castle_opening_attackby(src, W, user))
		return
	if (is_tool(W, TOOL_HAMMER) && user.a_intent == I_HELP)
		user.visible_message(SPAN_NOTICE("[user] starts taking down \the [src]."))
		if (do_after(user, 80, src))
			qdel(src)
		return
	return ..()

/obj/structure/castle_overhang/hoarding
	name = "hoarding"
	desc = "A timber gallery hung out over the top of the wall, with gaps in its floor. Pour or drop things through it onto the foot of the wall. It burns."
	icon_state = "hoarding"
	flammable = TRUE
	health = 250
	maxhealth = 250
	var/burning = FALSE

/obj/structure/castle_overhang/hoarding/get_saved_vars()
	. = ..()
	. -= "burning"

// A fire doesn't carry over a reload.
/obj/structure/castle_overhang/hoarding/after_load()
	..()
	icon_state = "hoarding"

/obj/structure/castle_overhang/hoarding/proc/catch_fire()
	if (burning || QDELETED(src))
		return
	burning = TRUE
	icon_state = "hoarding_burning"
	visible_message(SPAN_DANGER("\The [src] catches fire!"))
	addtimer(CALLBACK(src, PROC_REF(burn_tick)), 20)

/obj/structure/castle_overhang/hoarding/proc/burn_tick()
	if (QDELETED(src) || !burning)
		return
	health -= 25
	if (health <= 0)
		visible_message(SPAN_DANGER("\The [src] burns away and falls!"))
		qdel(src)
		return
	addtimer(CALLBACK(src, PROC_REF(burn_tick)), 20)

/obj/structure/castle_overhang/hoarding/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/flashlight/torch))
		var/obj/item/flashlight/torch/TR = W
		if (TR.on && user.a_intent == I_HARM)
			catch_fire()
			return
	if (burning && istype(W, /obj/item/weapon/reagent_containers) && user.a_intent != I_HARM)
		var/obj/item/weapon/reagent_containers/RG = W
		if (RG.reagents && RG.reagents.has_reagent("water", 10))
			RG.reagents.remove_reagent("water", 10)
			burning = FALSE
			icon_state = "hoarding"
			visible_message(SPAN_NOTICE("[user] puts out \the [src]."))
			return
	return ..()

/obj/structure/castle_overhang/hoarding/bullet_act(obj/item/projectile/P, def_zone)
	if (istype(P, /obj/item/projectile/arrow/arrow/fire) || istype(P, /obj/item/projectile/arrow/bolt/fire))
		if (prob(60))
			catch_fire()
	return ..()

/obj/structure/castle_overhang/hoarding/fire_act(temperature)
	catch_fire()

// A fire arrow or bolt that lands lights a slick on its tile, and may set
// alight a hoarding hanging over it.
/proc/fire_shot_landed(atom/A)
	var/turf/T = get_turf(A)
	if (!T)
		return
	var/obj/effect/castle_slick/S = locate() in T
	if (S)
		S.ignite()
	var/turf/up = GetAbove(T)
	if (!up)
		return
	for (var/obj/structure/castle_overhang/hoarding/H in range(1, up))
		if (H.pour_target() == T && prob(40))
			H.catch_fire()

/obj/item/projectile/arrow/arrow/fire/on_impact(atom/A)
	fire_shot_landed(A)
	return ..()

/obj/item/projectile/arrow/bolt/fire/on_impact(atom/A)
	fire_shot_landed(A)
	return ..()

// ---- tar kiln -----------------------------------------------------------------------

/obj/structure/tar_kiln
	name = "tar kiln"
	desc = "A small clay and stone kiln for burning resinous wood slowly into pitch. Load it with ten pieces of wood, light it with a torch and wait two minutes."
	icon = 'icons/obj/castle_defences.dmi'
	icon_state = "tar_kiln"
	anchored = TRUE
	density = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE
	var/wood = 0
	var/burning = FALSE
	var/pitch = 0
	var/burn_left = 0		// ds of burning left; saved, so a reload resumes the batch

/obj/structure/tar_kiln/after_load()
	..()
	if (burning)
		addtimer(CALLBACK(src, PROC_REF(kiln_tick)), 50)

/obj/structure/tar_kiln/examine(mob/user)
	..()
	if (burning)
		to_chat(user, SPAN_NOTICE("It is burning; about [max(1, round(burn_left / 600, 0.5))] minute\s left."))
	else
		to_chat(user, SPAN_NOTICE("It holds [wood] of [TAR_KILN_WOOD] pieces of wood and [pitch] units of pitch."))

/obj/structure/tar_kiln/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/stack/material/wood) && !burning)
		var/obj/item/stack/material/wood/S = W
		var/need = TAR_KILN_WOOD - wood
		if (need <= 0)
			to_chat(user, SPAN_NOTICE("\The [src] is fully loaded. Light it with a torch."))
			return
		var/used = min(need, S.amount)
		if (S.use(used))
			wood += used
			to_chat(user, SPAN_NOTICE("You load [used] wood into \the [src] ([wood]/[TAR_KILN_WOOD])."))
		return
	if (istype(W, /obj/item/flashlight/torch))
		var/obj/item/flashlight/torch/TR = W
		if (!TR.on)
			return ..()
		if (burning)
			to_chat(user, SPAN_NOTICE("\The [src] is already burning."))
			return
		if (wood < TAR_KILN_WOOD)
			to_chat(user, SPAN_WARNING("\The [src] needs [TAR_KILN_WOOD] pieces of wood first ([wood] loaded)."))
			return
		wood = 0
		burning = TRUE
		burn_left = TAR_KILN_TIME
		icon_state = "tar_kiln_on"
		user.visible_message(SPAN_NOTICE("[user] lights \the [src]."))
		addtimer(CALLBACK(src, PROC_REF(kiln_tick)), 50)
		return
	if (istype(W, /obj/item/weapon/reagent_containers))
		var/obj/item/weapon/reagent_containers/RG = W
		if (!pitch)
			to_chat(user, SPAN_NOTICE("There is no pitch in \the [src] yet."))
			return
		if (!RG.is_open_container() || !RG.reagents)
			return ..()
		var/room = RG.reagents.maximum_volume - RG.reagents.total_volume
		var/amount = min(room, pitch)
		if (amount <= 0)
			to_chat(user, SPAN_WARNING("\The [RG] is full."))
			return
		RG.reagents.add_reagent("pitch", amount)
		pitch -= amount
		to_chat(user, SPAN_NOTICE("You draw [amount] units of pitch from \the [src]."))
		return
	return ..()

/obj/structure/tar_kiln/proc/kiln_tick()
	if (QDELETED(src) || !burning)
		return
	burn_left -= 50
	if (burn_left > 0)
		addtimer(CALLBACK(src, PROC_REF(kiln_tick)), 50)
		return
	burning = FALSE
	burn_left = 0
	pitch += TAR_KILN_YIELD
	icon_state = "tar_kiln"
	visible_message(SPAN_NOTICE("Thick black pitch has run into the pot of \the [src]."))

#undef POUR_HOT_TIME
#undef POUR_BIG
#undef TAR_KILN_WOOD
#undef TAR_KILN_TIME
#undef TAR_KILN_YIELD
#undef SOLID_TIP_UNITS
