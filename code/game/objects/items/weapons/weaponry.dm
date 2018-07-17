/obj/item/weapon/energy_net
	name = "energy net"
	desc = "It's a net made of green energy."
	icon = 'icons/effects/effects.dmi'
	icon_state = "energynet"
	throwforce = FALSE
	force = FALSE
	var/net_type = /obj/effect/energy_net

/obj/item/weapon/energy_net/dropped()
	spawn(10)
		if(src) qdel(src)

/obj/item/weapon/energy_net/throw_impact(atom/hit_atom)
	..()

	var/mob/living/M = hit_atom

	if(!istype(M) || locate(/obj/effect/energy_net) in M.loc)
		qdel(src)
		return FALSE

	var/turf/T = get_turf(M)
	if(T)
		var/obj/effect/energy_net/net = new net_type(T)
		net.layer = M.layer+1
		M.captured = TRUE
		net.affecting = M
		T.visible_message("[M] was caught in an energy net!")
		qdel(src)

	// If we miss or hit an obstacle, we still want to delete the net.
	spawn(10)
		if(src) qdel(src)

/obj/effect/energy_net
	name = "energy net"
	desc = "It's a net made of green energy."
	icon = 'icons/effects/effects.dmi'
	icon_state = "energynet"

	density = TRUE
	opacity = FALSE
	mouse_opacity = TRUE
	anchored = TRUE

	var/health = 25
	var/mob/living/affecting = null //Who it is currently affecting, if anyone.
	var/mob/living/master = null    //Who shot web. Will let this person know if the net was successful.
	var/countdown = -1

/obj/effect/energy_net/teleport
	countdown = 60

/obj/effect/energy_net/New()
	..()
	processing_objects |= src

/obj/effect/energy_net/Destroy()

	if(affecting)
		var/mob/living/carbon/M = affecting
		M.anchored = initial(affecting.anchored)
		M.captured = FALSE
		M << "You are free of the net!"

	processing_objects -= src
	..()

/obj/effect/energy_net/proc/healthcheck()

	if(health <=0)
		density = FALSE
		visible_message("The energy net is torn apart!")
		qdel(src)
	return

/obj/effect/energy_net/process()

	if(isnull(affecting) || affecting.loc != loc)
		qdel(src)
		return

	// Countdown begin set to -1 will stop the teleporter from firing.
	// Clientless mobs can be netted but they will not teleport or decrement the timer.
	var/mob/living/M = affecting
	if(countdown == -1 || (istype(M) && !M.client))
		return

	if(countdown > 0)
		countdown--
		return

	// TODO: consider removing or altering this; energy nets are useful on their own
	// merits and the teleportation was never properly implemented; it's halfassed.
	density = FALSE
	invisibility = 101 //Make the net invisible so all the animations can play out.
	health = INFINITY  //Make the net invincible so that an explosion/something else won't kill it during anims.

	playsound(affecting.loc, 'sound/effects/sparks4.ogg', 50, TRUE)
	anim(affecting.loc,affecting,'icons/mob/mob.dmi',,"phaseout",,affecting.dir)

	affecting.visible_message("[affecting] vanishes in a flare of light!")

	if(holdingfacility.len)
		affecting.loc = pick(holdingfacility)

	affecting << "You appear in a strange place!"

	playsound(affecting.loc, 'sound/effects/phasein.ogg', 25, TRUE)
	playsound(affecting.loc, 'sound/effects/sparks2.ogg', 50, TRUE)
	anim(affecting.loc,affecting,'icons/mob/mob.dmi',,"phasein",,affecting.dir)

	qdel(src)

/obj/effect/energy_net/bullet_act(var/obj/item/projectile/Proj)
	health -= Proj.get_structure_damage()
	healthcheck()
	return FALSE

/obj/effect/energy_net/ex_act()
	health = FALSE
	healthcheck()

/obj/effect/energy_net/attack_hand(var/mob/user)

	var/mob/living/carbon/human/H = user
	if(istype(H))
		if(H.species.can_shred(H))
			playsound(loc, 'sound/weapons/slash.ogg', 80, TRUE)
			health -= rand(10, 20)
		else
			health -= rand(1,3)

	else if (HULK in user.mutations)
		health = FALSE
	else
		health -= rand(5,8)

	H << "<span class='danger'>You claw at the energy net.</span>"

	healthcheck()
	return

/obj/effect/energy_net/attackby(obj/item/weapon/W as obj, mob/user as mob)
	health -= W.force
	healthcheck()
	..()
