// Damage control: shoring kits and the thermal layer.
//
// A shoring kit is the quick, temporary answer to flooding. Timber shores and
// wedges with a canvas patch cut a breach to a seep in seconds, where a weld
// takes minutes; the shoring gives way the next time the hull is hit. On a
// bulkhead whose seals have buckled, the same kit wedges the seals back so the
// compartment is watertight again, though a crumpled bulkhead is beyond it.

/obj/item/weapon/shoring_kit
	name = "shoring kit"
	desc = "Timber shores, wedges and a canvas patch for damage control. Use it on a breached hull to stem the flooding until it can be welded, or on a buckled bulkhead to wedge its seals shut."
	icon = 'icons/obj/items.dmi'
	icon_state = "sandbag_new"
	w_class = ITEM_SIZE_NORMAL
	flammable = TRUE

/obj/item/weapon/shoring_kit/proc/use_on_hull(turf/wall/sub_hull/T, mob/user)
	if (!T.breached)
		to_chat(user, SPAN_NOTICE("The hull is not breached here."))
		return FALSE
	if (T.shored)
		to_chat(user, SPAN_NOTICE("The breach is already shored. It needs welding."))
		return FALSE
	to_chat(user, SPAN_NOTICE("You wedge shores and a patch against the breach..."))
	if (!do_after(user, 60, T) || QDELETED(src) || QDELETED(T) || !T.breached || T.shored)
		return FALSE
	T.shore_breach()
	qdel(src)
	return TRUE

/obj/item/weapon/shoring_kit/proc/use_on_bulkhead(turf/wall/sub_bulkhead/B, mob/user)
	if (B.watertight)
		to_chat(user, SPAN_NOTICE("The bulkhead seals are holding."))
		return FALSE
	if (B.health <= 0)
		to_chat(user, SPAN_WARNING("The bulkhead has crumpled. Shoring will not hold it; it needs welding."))
		return FALSE
	to_chat(user, SPAN_NOTICE("You wedge the bulkhead seals shut..."))
	if (!do_after(user, 60, B) || QDELETED(src) || QDELETED(B) || B.watertight || B.health <= 0)
		return FALSE
	B.shore_seals()
	qdel(src)
	return TRUE

// Sonar across the thermal layer: a boat below the layer and a listener above
// it (or the other way round) hear each other at half range.
/proc/sub_layer_factor(depth_a, depth_b)
	var/a_below = depth_a >= SUB_THERMOCLINE_DEPTH
	var/b_below = depth_b >= SUB_THERMOCLINE_DEPTH
	return a_below == b_below ? 1 : SUB_THERMOCLINE_SHADOW

/datum/submarine/proc/below_layer()
	return depth >= SUB_THERMOCLINE_DEPTH

// Where an enemy sits relative to the layer: ships and aircraft are on the
// surface, patrolling submarines run shallow above it.
/datum/vessel_contact/npc/proc/patrol_depth()
	return contact_type == SUB_CONTACT_SUBMERGED ? SUB_THERMOCLINE_DEPTH / 2 : 0
