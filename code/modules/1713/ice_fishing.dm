// Ice-hole fishing (docs/fishing-grounds.md, "Ice").
//
// Frozen water cannot be fished from above, but the fish are still under it.
// An axe, a pick or a chisel cuts a hole through the ice; a pole or rod used
// on the hole fishes the ground below, the same one the open water has in
// summer. The hole freezes over again after a while and goes when the ice
// does.

#define ICE_HOLE_LIFE (20 MINUTES)
#define ICE_HOLE_CHECK (2 MINUTES)
// Fish are slow in cold water.
#define ICE_HOLE_FACTOR 0.8

// Ticks to cut a hole with W, or 0 when it cannot cut ice.
/proc/ice_hole_tool_delay(obj/item/W)
	if (is_tool(W, TOOL_PICKAXE) || is_tool(W, TOOL_HATCHET))
		return 80
	if (is_tool(W, TOOL_CHISEL))
		return 120
	return 0

/proc/ice_hole_cut(turf/floor/beach/water/ice/T, obj/item/W, mob/living/human/H)
	if (locate(/obj/structure/ice_hole) in T)
		to_chat(H, SPAN_WARNING("There is already a hole here."))
		return null
	if (T.iscovered())
		to_chat(H, SPAN_WARNING("Something is built over the ice here."))
		return null
	H.visible_message(SPAN_NOTICE("[H] starts cutting a hole in the ice."), SPAN_NOTICE("You start cutting a hole in the ice."))
	playsound(T, 'sound/effects/pickaxe.ogg', 60, TRUE)
	if (!do_after(H, ice_hole_tool_delay(W), T) || QDELETED(W) || W.loc != H)
		return null
	if (!istype(T, /turf/floor/beach/water/ice) || (locate(/obj/structure/ice_hole) in T))
		return null
	var/obj/structure/ice_hole/hole = new(T)
	H.visible_message(SPAN_NOTICE("[H] breaks through to the water under the ice."), SPAN_NOTICE("You break through to dark water. A line will go down it."))
	return hole

/obj/structure/ice_hole
	name = "ice hole"
	desc = "A hole cut through the ice, with dark water below. A fishing pole or rod will go down it. It will freeze over again before long."
	icon = 'icons/obj/fishing_gear.dmi'
	icon_state = "ice_hole"
	anchored = TRUE
	density = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	layer = 2.05
	// When it was cut, in real minutes as text (trap_minutes_text), so a hole
	// carried over a save still closes on time.
	var/cut_at = ""
	var/tmp/check_epoch = 0

/obj/structure/ice_hole/persistence_runtime_var(key)
	return key == "check_epoch" || ..()

/obj/structure/ice_hole/New()
	..()
	if (!cut_at)
		cut_at = trap_minutes_text(trap_now_minutes())
	schedule_check()

/obj/structure/ice_hole/after_load()
	..()
	schedule_check()

/obj/structure/ice_hole/proc/schedule_check()
	check_epoch++
	addtimer(CALLBACK(src, PROC_REF(refreeze_check), check_epoch), ICE_HOLE_CHECK)

// TRUE while the hole is still open: on ice, and cut recently enough.
/obj/structure/ice_hole/proc/open(now = trap_now_minutes())
	if (!istype(loc, /turf/floor/beach/water/ice))
		return FALSE
	var/cut = trap_minutes(cut_at)
	return cut && now >= cut && (now - cut) * 600 < ICE_HOLE_LIFE

/obj/structure/ice_hole/proc/refreeze_check(epoch)
	if (QDELETED(src) || epoch != check_epoch)
		return FALSE
	if (!open())
		if (istype(loc, /turf/floor/beach/water/ice))
			visible_message(SPAN_NOTICE("The hole in the ice freezes over."))
		qdel(src)
		return TRUE
	schedule_check()
	return TRUE

// The ground under the ice: the one the open water has when it thaws.
/obj/structure/ice_hole/proc/ground(create = TRUE)
	if (!istype(loc, /turf/floor/beach/water/ice))
		return null
	if (istype(loc, /turf/floor/beach/water/ice/salty))
		return fishing_ground_cell(loc, FISH_WATER_SALT, 12, create)
	return fishing_ground_cell(loc, FISH_WATER_FRESH, 6, create)

/obj/structure/ice_hole/examine(mob/user)
	..()
	var/datum/fishing_ground/G = ground(FALSE)
	if (G && G.available() < 1)
		to_chat(user, "Nothing stirs in the water below. This stretch is fished out for now.")
	else
		to_chat(user, "Now and then something moves in the dark water.")

/obj/structure/ice_hole/attackby(obj/item/W, mob/user)
	var/list/profile = fishing_tool_profile(W)
	if (!profile || !ishuman(user))
		return ..()
	var/mob/living/human/H = user
	if (profile[3] || profile[4] > 1)
		to_chat(H, SPAN_WARNING("The hole is too narrow for that. Use a fishing pole or rod."))
		return
	if (H.ocean_fishing)
		to_chat(H, SPAN_WARNING("You are already fishing."))
		return
	var/datum/fishing_ground/G = ground()
	if (!G)
		return
	if (G.available() < 1)
		to_chat(H, SPAN_WARNING("Nothing stirs under the ice here. Try a hole further along."))
		return
	var/obj/item/weapon/fishing/line = W
	var/baited = istype(line) && line.bait_uses > 0
	H.ocean_fishing = TRUE
	H.visible_message(SPAN_NOTICE("[H] lowers \the [W] into the ice hole."), SPAN_NOTICE("You lower the line into the hole[baited ? " with bait on it" : ""]."))
	var/done = do_after(H, profile[1], src)
	H.ocean_fishing = FALSE
	if (!done || QDELETED(src) || QDELETED(W) || W.loc != H || !Adjacent(H))
		return
	if (baited && line.bait_uses > 0)
		line.bait_uses--
	var/chance = min(95, fish_tool_chance(profile, baited, G) * ICE_HOLE_FACTOR)
	fish_land(H, loc, G, G.kind, chance, 1, baited, FALSE)

#undef ICE_HOLE_LIFE
#undef ICE_HOLE_CHECK
#undef ICE_HOLE_FACTOR
