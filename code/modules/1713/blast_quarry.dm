// A game blast converts one native rock tile into one finite stock.
#define QUARRY_LOAD 5
#define QUARRY_OUTPUT_STACKS 12

/turf/proc/quarry_hardness()
	return 0

/turf/floor/dirt/underground/quarry_hard
	name = "hard quarry rock"
	desc = "A band of dense rock. A pickaxe or shovel will not open it. Requires a blasting charge and leaves a larger stone cluster."
	color = "#a39686"
	is_mineable = FALSE

/turf/floor/dirt/underground/quarry_hard/quarry_hardness()
	return 1

/turf/floor/dirt/underground/quarry_hard/deep
	name = "deep quarry rock"
	desc = "A band of especially dense rock. Only a reinforced quarry charge will open it. It leaves the largest stone clusters."
	color = "#837286"

/turf/floor/dirt/underground/quarry_hard/deep/quarry_hardness()
	return 2

// Accidental damage must not sidestep the excavation gate.
/turf/floor/dirt/underground/quarry_hard/ex_act(severity)
	return

/turf/floor/dirt/underground/quarry_hard/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/material/pickaxe) || is_tool(W, TOOL_SHOVEL))
		to_chat(user, SPAN_NOTICE(desc))
		return TRUE
	return ..()

/turf/proc/quarry_blast_eligible(charge_grade = 1)
	var/hardness = quarry_hardness()
	return charge_grade >= 1 && charge_grade >= hardness && istype(src, /turf/floor/dirt/underground) && !istype(src, /turf/floor/dirt/underground/empty) && (is_mineable || hardness) && !!density && !mining_in_progress && !pickaxe_mining_owner

// Sparse, deterministic pockets on naturally formed dry rock. Remain clear of
// the rim so region edge arrivals and ordinary access tunnels stay available.
/proc/quarry_band_type(x, y, depth, vein)
	if (depth < 1 || tutorial_region_here() || x <= 6 || y <= 6 || x > world.maxx - 6 || y > world.maxy - 6)
		return null
	if (dug_underground_noise("quarry-band:[depth]", x, y) < (vein > 0.65 ? 0.64 : 0.82))
		return null
	return depth >= 3 ? /turf/floor/dirt/underground/quarry_hard/deep : /turf/floor/dirt/underground/quarry_hard

// Change the terrain first, so a second blast cannot open the same stock.
/turf/proc/quarry_open(rock_type, stock)
	var/tx = x
	var/ty = y
	var/tz = z
	var/hardness = quarry_hardness()
	change_the_turf()
	var/turf/opened = locate(tx, ty, tz)
	if (!opened || opened.density || opened.is_mineable || stock < 1)
		return
	var/obj/structure/quarry_cluster/Q = new(opened)
	Q.stone_type = rock_type
	Q.stone_left = round(stock * (1.5 + hardness * 0.5))
	Q.update_icon()
	return Q

/obj/structure/quarry_cluster
	name = "blasted rock cluster"
	desc = "A finite heap of fractured rock. Work it with a pickaxe in small loads and clear away the stone as you go."
	icon = 'icons/obj/mining.dmi'
	icon_state = "boulder1"
	anchored = TRUE
	density = FALSE
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	layer = OBJ_LAYER
	var/stone_type = /obj/item/stack/material/stone
	var/stone_left = 0
	var/tmp/working = FALSE

/obj/structure/quarry_cluster/persistence_runtime_var(key)
	return key == "working" || ..()

/obj/structure/quarry_cluster/after_load()
	..()
	if (stone_left < 1)
		qdel(src)
	else
		update_icon()

/obj/structure/quarry_cluster/update_icon()
	var/scale = stone_left > 20 ? 1 : (stone_left > 10 ? 0.8 : 0.6)
	transform = matrix(scale, 0, 0, 0, scale, 0)

/obj/structure/quarry_cluster/examine(mob/user)
	..()
	var/obj/item/stack/S = stone_type
	to_chat(user, SPAN_NOTICE("About [stone_left] units of [initial(S.name)] remain."))

// The existing blasting charge damage is processed from an explosion queue. Do not let
// that same blast destroy resources it just uncovered.
/obj/structure/quarry_cluster/ex_act(severity)
	return

/obj/structure/quarry_cluster/proc/quarry_ready(mob/living/human/H, obj/item/W, turf/site, datum/identity)
	return !QDELETED(src) && !QDELETED(H) && !QDELETED(W) && site && loc == site && H.z == site.z && Adjacent(H) && H.pickaxe_mining_ready() && W.loc == H && (H.l_hand == W || H.r_hand == W) && !persistence_admission_changed(identity)

/obj/structure/quarry_cluster/attackby(obj/item/W, mob/user)
	if (!istype(W, /obj/item/weapon/material/pickaxe) || !ishuman(user))
		return ..()
	var/mob/living/human/H = user
	var/turf/site = get_turf(src)
	var/datum/identity = persistence_admission_identity
	if (tutorial_region_here() && !tutorial_workshop_access(H, src))
		return TRUE
	if (working || !quarry_ready(H, W, site, identity))
		return TRUE
	working = TRUE
	to_chat(H, SPAN_NOTICE("You start breaking usable stone off the cluster."))
	playsound(src, 'sound/effects/pickaxe.ogg', 60, TRUE)
	if (do_after(H, work_delay(H, 45, WORK_MINE, W), src) && quarry_ready(H, W, site, identity))
		if (!quarry_take_load())
			to_chat(H, SPAN_WARNING("Clear the loose stone beside the cluster before mining more."))
	working = FALSE
	return TRUE

/obj/structure/quarry_cluster/proc/quarry_take_load()
	var/turf/site = get_turf(src)
	var/amount = min(QUARRY_LOAD, stone_left)
	if (QDELETED(src) || persistence_admission_blocked() || !site || amount < 1 || !(stone_type in list(/obj/item/stack/material/stone, /obj/item/stack/material/marble, /obj/item/stack/material/sandstone)))
		return FALSE
	if (!site.deposit_small_resource(stone_type, amount, QUARRY_OUTPUT_STACKS))
		return FALSE
	stone_left -= amount
	if (!stone_left)
		visible_message(SPAN_NOTICE("The last of the fractured rock breaks loose."))
		qdel(src)
	else
		update_icon()
	return TRUE

/obj/structure/quarry_cluster/practice
	should_save = FALSE
	stone_left = 15

#undef QUARRY_LOAD
#undef QUARRY_OUTPUT_STACKS
