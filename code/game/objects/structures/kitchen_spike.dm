//////Kitchen Spike

/obj/structure/kitchenspike
	name = "a meat spike"
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "spike"
	desc = "A spike for collecting meat from animals."
	density = FALSE
	anchored = TRUE
	layer = MOB_LAYER + 0.01
	var/meat = FALSE
	var/occupied
	var/meat_type
	var/victim_name = "corpse"
	not_movable = FALSE
	not_disassemblable = TRUE
/obj/structure/kitchenspike/attackby(obj/item/weapon/grab/G as obj, mob/user as mob)
	if (!istype(G, /obj/item/weapon/grab) || !G.affecting)
		return
	if (occupied)
		user << "<span class = 'danger'>The spike already has something on it, finish collecting its meat first!</span>"
	else
		if (spike(G.affecting))
			visible_message("<span class = 'danger'>[user] has forced [G.affecting] onto the spike, killing them instantly!</span>")
			qdel(G.affecting)
			qdel(G)
		else
			user << "<span class='danger'>They are too big for the spike, try something smaller!</span>"

/obj/structure/kitchenspike/proc/spike(var/mob/living/victim)

	if (!istype(victim))
		return

	if (istype(victim, /mob/living/human))
		var/mob/living/human/H = victim
		if (!issmall(H))
			return FALSE
		meat_type = H.species.meat_type
		icon_state = "spikebloody"
	else
		return FALSE

	victim_name = victim.name
	occupied = TRUE
	meat = 5
	return TRUE

/obj/structure/kitchenspike/attack_hand(mob/user as mob)
	if (..() || !occupied)
		return
	meat--
	new meat_type(get_turf(src))
	if (meat > 1)
		user << "You remove some meat from \the [victim_name]."
	else if (meat == TRUE)
		user << "You remove the last piece of meat from \the [victim_name]!"
		icon_state = "spike"
		occupied = FALSE
