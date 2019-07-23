/obj/structure/TV
	name = "Television"
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "TV"
	anchored = TRUE
	var/destroyed = FALSE
	var/active = FALSE
	density = TRUE
	flammable = FALSE
	var/health = 100
	var/maxhealth = 100
	not_movable = TRUE
	not_disassemblable = TRUE
	
	var/protection_chance = 85 //odds of something hitting the TV
	
/obj/structure/TV/active
	icon_state = "TV_wn"
	active = TRUE
	
/obj/structure/TV/proc/try_destroy()
	if (health <= 0)
		visible_message("<span class='danger'>The TV is broken!</span>")
		qdel(src)
		return
		
/obj/structure/TV/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if (istype(mover, /obj/item/projectile))
		return prob(100-protection_chance)
	else
		return FALSE
		
/obj/structure/TV/bullet_act(var/obj/item/projectile/proj)
	health -= proj.damage/3
	visible_message("<span class='warning'>\The [src] is hit by the [proj.name]!</span>")
	try_destroy()
