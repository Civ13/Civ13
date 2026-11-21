// Quench tub (docs/station-water.md).
//
// A wooden tub of water set beside an anvil. Each iron or steel tool, blade
// or part forged on that anvil is quenched in it as it comes off: 10 water,
// and the piece is hardened one quality step (Decent to Excellent). Without
// a tub, or with it dry, forging works as before. Bronze, copper and the
// other soft metals gain nothing and take no water. Like every water
// station it fills by bucket or pipe, or counts as full beside running
// water (station_water.dm).

// Quality a quenched piece reaches: the Excellent band of the examine text.
#define QUENCHED_QUALITY 1.2

/obj/structure/quench_tub
	name = "quench tub"
	desc = "A squat wooden tub of water. Set beside an anvil, it hardens the iron and steel forged there."
	icon = 'icons/obj/quench_tub.dmi'
	icon_state = "quench_tub"
	density = TRUE
	anchored = TRUE
	flammable = TRUE
	water_capacity = 60
	water_per_use = 10

/obj/structure/quench_tub/New()
	..()
	update_icon()

/obj/structure/quench_tub/update_icon()
	icon_state = station_has_water() ? "quench_tub_full" : "quench_tub"

/obj/structure/quench_tub/attackby(obj/item/I, mob/user)
	if (is_tool(I, TOOL_WRENCH) || is_tool(I, TOOL_HAMMER))
		toggle_anchor(user)
		return
	if (station_water_pour(I, user))
		update_icon()
		return
	return ..()

/obj/structure/quench_tub/fluid_receive(id, amount, data)
	. = ..()
	if (. && id == "water")
		update_icon()

/obj/structure/quench_tub/examine(mob/user, distance = -1)
	. = ..()
	station_water_examine(user)

// Whether forged work in this material is hardened by quenching.
/proc/quench_hardens(material_name)
	return material_name == "iron" || material_name == "steel"

// The watered quench tub beside this anvil, if any.
/obj/structure/anvil/proc/quench_tub()
	for (var/obj/structure/quench_tub/Q in range(1, src))
		if (Q.anchored && Q.station_has_water())
			return Q
	return null

// Quenches a freshly forged piece. TRUE when it was hardened.
/obj/structure/quench_tub/proc/quench(obj/item/weapon/material/W, mob/user)
	if (!istype(W))
		return FALSE
	// The steel's grade carries through: blister steel hardens less, fine steel more.
	var/hardened = QUENCHED_QUALITY * W.forged_grade
	if (W.crafting_quality >= hardened || !station_take_water(null))
		return FALSE
	W.crafting_quality = hardened
	W.update_force()
	playsound(src, 'sound/effects/watersplash.ogg', 30, TRUE)
	flick("quench_tub_steam", src)
	update_icon()
	if (user)
		to_chat(user, SPAN_NOTICE("You plunge \the [W] hissing into \the [src]. It comes out hard."))
	return TRUE

// Each piece forged from iron or steel sheet comes off the anvil into the
// tub: a steel Japanese blade is clay-hardened first when the smith can
// (tatara.dm), then everything gets the plain quench.
/obj/structure/anvil/finish_forged_piece(obj/item/made, mob/user, mob/living/human/H, material_name)
	..()
	var/obj/item/weapon/material/W = made
	if (!istype(W) || QDELETED(W) || !quench_hardens(material_name))
		return
	clay_harden(W, H)
	var/obj/structure/quench_tub/Q = quench_tub()
	if (Q)
		Q.quench(W, user)

#undef QUENCHED_QUALITY
