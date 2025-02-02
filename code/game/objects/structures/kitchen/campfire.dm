//////////////
// Campfire //
//////////////

/obj/structure/oven/fireplace
	name = "campfire"
	desc = "A campfire made with wood logs."
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "fireplace"
	layer = 2.9
	density = FALSE
	anchored = TRUE
	flags = OPENCONTAINER | NOREACT
	base_state = "fireplace"
	on = FALSE
	max_space = 5
	fuel = 4
	consume_itself = TRUE
	looping = TRUE
	cooking_time = 300
	light_power = 0.75
	light_color = "#E38F46"

// SFX
/obj/structure/oven/fireplace/proc/keep_sound_on()
	if (on && looping && fuel > 0)
		playsound(get_turf(src), "sound/effects/fireplace-[rand(1, 6)].ogg", 75, TRUE, -1)
		spawn(50) // 6 seconds
			keep_sound_on()


// Fire Loop
/obj/structure/oven/fireplace/proc/keep_fire_on()
	if (on && looping && fuel > 0)
		set_light(5)
		update_icon()
		fire_loop()
		spawn(600) // 1 minute
			keep_fire_on()
	else
		on = FALSE
		ignition_source = FALSE
		set_light(0)
		return


// Toggle State
/obj/structure/oven/fireplace/attack_hand(var/mob/living/human/H)
	if (!on && fuel > 0)
		H.visible_message(SPAN_NOTICE("[H] lights \the [name]."), SPAN_NOTICE("You light \the [name]."))
		on = TRUE
		ignition_source = TRUE
		keep_fire_on()
		keep_sound_on()
	else if (on)
		H.visible_message(SPAN_NOTICE("[H] extinguishes \the [name]."), SPAN_NOTICE("You extinguish \the [name]."))
		on = FALSE
		ignition_source = FALSE
		set_light(0)
		update_icon()
	H.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)


// Item Interactions
/obj/structure/oven/fireplace/attackby(var/obj/item/I, var/mob/living/human/H)
	if(on && istype(I, /obj/item/weapon/barrier))
		qdel(I)
		var/obj/structure/charcoal_mound/CM = new /obj/structure/charcoal_mound(get_turf(src))
		CM.fuel = fuel
		qdel(src)
		return
	if(on && (istype(I, /obj/item/stack/material/leather) || istype(I, /obj/item/stack/material/cloth)))
		H << "You produce some smoke signals."
		smoke_signals()
		return
	..()


// Smoke Signals
/obj/structure/oven/fireplace/proc/smoke_signals()
	for (var/mob/living/human/HH in range(25,src))
		if (!HH.blinded && !HH.paralysis && HH.sleeping <= 0 && HH.stat == 0)
			var/currdir = "somewhere"
			if (z == HH.z)
				if (y < HH.y)
					currdir = "south"
				if (y > HH.y)
					currdir = "north"
				if (y == HH.y)
					currdir = ""
				if (x <= HH.x)
					currdir = "[currdir]west"
				if (x > HH.x)
					currdir = "[currdir]east"
				if (x == HH.x)
					currdir = ""
			if (currdir != "somewhere" && currdir != "")
				to_chat(HH, "<b>You see some smoke signals [currdir] of you...</b>")


// Walk Over
/obj/structure/oven/fireplace/Crossed(mob/living/human/M as mob)
	if (icon_state == "[base_state]_on" && ishuman(M))
		M.apply_damage(rand(2,4), BURN, "l_leg")
		M.apply_damage(rand(2,4), BURN, "r_leg")
		M.visible_message(SPAN_WARNING("[M] gets <big>burnt</big> by \the [name]!"), SPAN_WARNING("You get <big>burnt</big> by \the [name]!"))


//////////////
// Fire Pit //
//////////////

/obj/structure/oven/fireplace/pit
	name = "fire pit"
	desc = "A small pit surrounded by stones used for housing fires."
	icon = 'icons/obj/structures.dmi'
	icon_state = "ringed_campfire"
	density = TRUE
	anchored = TRUE
	base_state = "ringed_campfire"
	consume_itself = FALSE
	cooking_time = 150
	light_power = 0.85
	light_color = "#E38F46"



//////////////
// Fire Pit //
//////////////

/obj/structure/charcoal_mound
	name = "charcoal mound"
	desc = "A mound of wood covered by dirt. It's smoking a little."
	icon = 'icons/obj/structures.dmi'
	icon_state = "charcoal_mound"
	density = FALSE
	anchored = TRUE
	light_power = 0.1
	light_color = "#E38F46"
	var/fuel

/obj/structure/charcoal_mound/New()
	..()
	spawn(300)
		var/obj/item/stack/S = new /obj/item/stack/ore/charcoal(get_turf(src))
		S.amount = round(fuel * 2 / 3)
		S.update_icon()
		qdel(src)