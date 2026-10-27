/obj/item/remains
	name = "remains"
	gender = PLURAL
	icon = 'icons/effects/blood.dmi'
	icon_state = "remains"
	anchored = FALSE
	value = 0
/obj/item/remains/human
	desc = "They look like human remains. They have a strange aura about them."

/obj/item/remains/mouse
	desc = "They look like the remains of a small rodent."
	icon_state = "mouse"

/obj/item/remains/lizard
	desc = "They look like the remains of a small reptile."
	icon_state = "lizard"

/obj/item/remains/attack_hand(mob/user as mob)
	to_chat(user, SPAN_NOTICE("[src] sinks together into a pile of ash."))
	var/turf/floor/F = get_turf(src)
	if (istype(F))
		new /obj/effect/decal/cleanable/ash(F)
	qdel(src)