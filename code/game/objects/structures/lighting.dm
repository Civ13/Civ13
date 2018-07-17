// The lighting system
//
// consists of light fixtures (/obj/structure/light) and light tube/bulb items (/obj/item/weapon/light)


// status values shared between lighting fixtures and items
#define LIGHT_OK FALSE
#define LIGHT_EMPTY TRUE
#define LIGHT_BROKEN 2
#define LIGHT_BURNED 3
#define LIGHT_BULB_TEMPERATURE 400 //K - used value for a 60W bulb

/obj/structure/light_construct // Добавить понятие "базовая иконка"
	name = "light fixture frame"
	desc = "A light fixture under construction."
	icon = 'icons/obj/lighting.dmi'
	icon_state = "tube-construct-stage1"
	anchored = TRUE
	layer = 5
	var/stage = TRUE
	var/fixture_type = "tube"
	var/sheets_refunded = 2
	var/obj/structure/light/newlight = null

/obj/structure/light_construct/New()
	..()
	if (fixture_type == "bulb")
		icon_state = "bulb-construct-stage1"
	else if (istype(src, /obj/structure/light_construct/floor))
		icon_state = "floortube-construct-stage1"

/obj/structure/light_construct/examine(mob/user)
	if (!..(user, 2))
		return

	switch(stage)
		if (1)
			user << "It's an empty frame."
			return
		if (2)
			user << "It's wired."
			return
		if (3)
			user << "The casing is closed."
			return

/obj/structure/light_construct/attackby(obj/item/weapon/W as obj, mob/user as mob)
	add_fingerprint(user)
	if (istype(W, /obj/item/weapon/wrench))
		if (stage == TRUE)
			playsound(loc, 'sound/items/Ratchet.ogg', 75, TRUE)
			usr << "You begin deconstructing \a [src]."
			if (!do_after(usr, 30,src))
				return
			new /obj/item/stack/material/steel( get_turf(loc), sheets_refunded )
			user.visible_message("[user.name] deconstructs [src].", \
				"You deconstruct [src].", "You hear a noise.")
			playsound(loc, 'sound/items/Deconstruct.ogg', 75, TRUE)
			qdel(src)
		if (stage == 2)
			usr << "You have to remove the wires first."
			return

		if (stage == 3)
			usr << "You have to unscrew the case first."
			return

	if (istype(W, /obj/item/weapon/wirecutters))
		if (stage != 2) return
		stage = TRUE
		switch(fixture_type)
			if ("tube")
				if (!istype(src, /obj/structure/light_construct/floor)) // TODO Переделать это
					icon_state = "tube-construct-stage1"
				else
					icon_state = "floortube-construct-stage1"
			if ("bulb")
				icon_state = "bulb-construct-stage1"
		new /obj/item/stack/cable_coil(get_turf(loc), TRUE, "red")
		user.visible_message("[user.name] removes the wiring from [src].", \
			"You remove the wiring from [src].", "You hear a noise.")
		playsound(loc, 'sound/items/Wirecutter.ogg', 100, TRUE)
		return

	if (istype(W, /obj/item/stack/cable_coil))
		if (stage != TRUE) return
		var/obj/item/stack/cable_coil/coil = W
		if (coil.use(1))
			switch(fixture_type)
				if ("tube")
					if (!istype(src, /obj/structure/light_construct/floor)) // TODO Переделать это
						icon_state = "tube-construct-stage2"
					else
						icon_state = "floortube-construct-stage2"
				if ("bulb")
					icon_state = "bulb-construct-stage2"
			stage = 2
			user.visible_message("[user.name] adds wires to [src].", \
				"You add wires to [src].")
		return

	if (istype(W, /obj/item/weapon/screwdriver))
		if (stage == 2)
			switch(fixture_type)
				if ("tube")
					icon_state = "tube-empty"
				if ("bulb")
					icon_state = "bulb-empty"
			stage = 3
			user.visible_message("[user.name] closes [src]'s casing.", \
				"You close [src]'s casing.", "You hear a noise.")
			playsound(loc, 'sound/items/Screwdriver.ogg', 75, TRUE)

			switch(fixture_type)

				if ("tube")
					if (!istype(src, /obj/structure/light_construct/floor))
						newlight = new /obj/structure/light/built(loc)
					else
						newlight = new /obj/structure/light/floor/built(loc)
				if ("bulb")
					newlight = new /obj/structure/light/small/built(loc)

			newlight.dir = dir
			transfer_fingerprints_to(newlight)
			qdel(src)
			return
	..()

/obj/structure/light_construct/small
	name = "small light fixture frame"
	desc = "A small light fixture under construction."
	icon = 'icons/obj/lighting.dmi'
	icon_state = "bulb-construct-stage1"
	anchored = TRUE
	layer = 5
	stage = TRUE
	fixture_type = "bulb"
	sheets_refunded = TRUE

/obj/structure/light_construct/floor //floorlight
	name = "floorlight fixture frame"
	icon_state = "floortube-construct-stage1"
	layer = 2.5

// the standard tube light fixture
/obj/structure/light
	name = "light fixture"
	icon = 'icons/obj/lighting.dmi'
	var/base_state = "tube"		// base description and icon_state
	icon_state = "tube1"
	desc = "A lighting fixture."
	anchored = TRUE
	layer = 5  					// They were appearing under mobs which is a little weird - Ostaf
//	use_power = 2
//	idle_power_usage = 2
//	active_power_usage = 20
//	power_channel = LIGHT //Lights are calc'd via area so they dont need to be in the machine list
	var/on = FALSE					// TRUE if on, FALSE if off
	var/on_gs = FALSE
	var/brightness_range = 7	// luminosity when on, also used in power calculation
	var/brightness_power = 2
	var/brightness_color = null
	var/status = LIGHT_OK		// LIGHT_OK, _EMPTY, _BURNED or _BROKEN
	var/flickering = FALSE
	var/light_type = /obj/item/weapon/light/tube		// the type of light item
	var/fitting = "tube"
	var/switchcount = FALSE			// count of number of times switched on/off
								// this is used to calc the probability the light burns out
	var/needsound
	var/rigged = FALSE				// true if rigged to explode
	var/firealarmed = FALSE
	var/atmosalarmed = FALSE
// the smaller bulb light fixture

/obj/structure/light/bullet_act(var/obj/item/projectile/proj)
	if (proj && !proj.nodamage)
		visible_message("<span class = 'warning'>\The [src] is hit by \the [proj]!</span>")
		return broken()
	return FALSE

/obj/structure/light/floor
	name = "floorlight fixture"
	base_state = "floortube"
	icon_state = "floortube1"
	layer = 2.5

/obj/structure/light/floor/streetlight
	icon = 'icons/obj/lighting_32x64.dmi'
	name = "streetlight"
	base_state = "streetlight"
	icon_state = "streetlight1"
	brightness_range = 5
	brightness_power = 2
	density = TRUE
	layer = MOB_LAYER + 0.5

/obj/structure/light/floor/streetlight/New()
	..()
	if (prob(40) && (!map || !istype(map, /obj/map_metadata/camp)))
		broken(TRUE)

/obj/structure/light/floor/streetlight/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if (istype(mover, /obj/effect/effect/smoke))
		return TRUE
	else if (istype(mover, /obj/item/projectile))
		if (prob(66))
			return TRUE
		else
			visible_message("<span class = 'warning'>The [mover.name] riochetes off \the [src]!</span>")
			return FALSE
	else
		return ..()

/obj/structure/light/floor/streetlight/ex_act(severity)
	switch(severity)
		if (1.0)
			qdel(src)
			return
		if (2.0)
			if (prob(25))
				qdel(src)
				return
		if (3.0)
			return

/obj/structure/light/small
	icon_state = "bulb1"
	base_state = "bulb"
	fitting = "bulb"
	brightness_range = 7
	brightness_power = 2
	brightness_color = "#a0a080"
	desc = "A small lighting fixture."
	light_type = /obj/item/weapon/light/bulb

/obj/structure/light/small/emergency
	brightness_range = 6
	brightness_power = 2
	brightness_color = "#da0205"

/obj/structure/light/small/red
	brightness_range = 5
	brightness_power = TRUE
	brightness_color = "#da0205"

/obj/structure/light/spot
	name = "spotlight"
	fitting = "large tube"
	light_type = /obj/item/weapon/light/tube/large
	brightness_range = 12
	brightness_power = 4

/obj/structure/light/built/New()
	status = LIGHT_EMPTY
	update(0)
	..()

/obj/structure/light/small/built/New()
	status = LIGHT_EMPTY
	update(0)
	..()

/obj/structure/light/floor/built/New() //WHAT IT IS?!?!??!?!?
	status = LIGHT_EMPTY
	update(0)
	..()

// create a new lighting fixture
/obj/structure/light/New()
	..()

	if (config.lighting_is_rustic)
		if (brightness_range >= 7)
			brightness_range -= 2 // dim powerful lights a bit

	spawn(2)
		var/area/A = get_area(src)
		if (A && !A.requires_power)
			on = TRUE
/*
		if (z == 1 || z == 5)
			switch(fitting)
				if ("tube","bulb")
					if (prob(2))
						broken(1)*/

		spawn(1)
			update(0)

	processing_objects += src

/obj/structure/light/Destroy()
	var/area/A = get_area(src)
	if (A)
		on = FALSE
//		A.update_lights()
	..()

/obj/structure/light/update_icon()

	switch(status)		// set icon_states
		if (LIGHT_OK)
			if (firealarmed && on && cmptext(base_state,"tube"))
				icon_state = "[base_state]_alert"
			else if (atmosalarmed && on && cmptext(base_state,"tube"))
				icon_state = "[base_state]_alert_atmos"
			else
				icon_state = "[base_state][on]"
		if (LIGHT_EMPTY)
			icon_state = "[base_state]-empty"
			on = FALSE
		if (LIGHT_BURNED)
			icon_state = "[base_state]-burned"
			on = FALSE
		if (LIGHT_BROKEN)
			icon_state = "[base_state]-broken"
			on = FALSE
	return

/obj/structure/light/proc/set_blue()
	if (on)
		if (cmptext(base_state,"tube"))
			atmosalarmed = TRUE
			firealarmed = FALSE
			brightness_color = "#6D6DFC"
		update()

/obj/structure/light/proc/set_red()
	if (on)
		if (cmptext(base_state,"tube"))
			firealarmed = TRUE
			atmosalarmed = FALSE
			brightness_color = "#FF3030"
		update()

/obj/structure/light/proc/reset_color()
	if (on)
		if (cmptext(base_state,"tube"))
			firealarmed = FALSE
			atmosalarmed = FALSE
			brightness_color = "#FFFFFF"
		update()

/obj/structure/light/proc/fix_TOD_lights()
	if (on)
		set_light(brightness_range, brightness_power, brightness_color)

// update the icon_state and luminosity of the light depending on its state
/obj/structure/light/proc/update(var/trigger = TRUE, var/fastupdate = FALSE, var/nosound = FALSE)

	update_icon()

	if (on == TRUE)
		if (needsound == TRUE)
			if (!nosound)
				playsound(loc, 'sound/effects/Custom_lights.ogg', 65, TRUE)
				needsound = FALSE
	else
		needsound = TRUE

	if (on)

		if (fastupdate)
//			use_power = 2
			set_light(brightness_range, brightness_power, brightness_color)
			return

		if (light_range != brightness_range || light_power != brightness_power || light_color != brightness_color)
			switchcount++
			if (rigged)
				if (status == LIGHT_OK && trigger)

					log_admin("LOG: Rigged light explosion, last touched by [fingerprintslast]")
					message_admins("LOG: Rigged light explosion, last touched by [fingerprintslast]")

					explode()
			else if ( prob( min(60, switchcount*switchcount*0.01) ) )
				if (status == LIGHT_OK && trigger)
					status = LIGHT_BURNED
					icon_state = "[base_state]-burned"
					on = FALSE
					set_light(0)
			else
//				use_power = 2
				set_light(brightness_range, brightness_power, brightness_color)
	else
//		use_power = TRUE
		set_light(0)

//	active_power_usage = ((light_range + light_power) * 10)
	if (on != on_gs)
		on_gs = on

/obj/structure/light/attack_generic(var/mob/user, var/damage)
	if (!damage)
		return
	if (status == LIGHT_EMPTY||status == LIGHT_BROKEN)
		user << "That object is useless to you."
		return
	if (!(status == LIGHT_OK||status == LIGHT_BURNED))
		return
	visible_message("<span class='danger'>[user] smashes the light!</span>")
	attack_animation(user)
	broken()
	return TRUE

// attempt to set the light's on/off status
// will not switch on if broken/burned/empty
/obj/structure/light/proc/seton(var/s, var/trigger = TRUE, var/fastupdate = FALSE, var/nosound = FALSE)
	on = (s && status == LIGHT_OK)
	update(trigger, fastupdate, nosound)

// examine verb
/obj/structure/light/examine(mob/user)
	switch(status)
		if (LIGHT_OK)
			user << "[desc] It is turned [on? "on" : "off"]."
		if (LIGHT_EMPTY)
			user << "[desc] The [fitting] has been removed."
		if (LIGHT_BURNED)
			user << "[desc] The [fitting] is burnt out."
		if (LIGHT_BROKEN)
			user << "[desc] The [fitting] has been smashed."



// attack with item - insert light (if right type), otherwise try to break the light

/obj/structure/light/attackby(obj/item/W, mob/user)

	// attempt to insert light
	if (istype(W, /obj/item/weapon/light))
		if (status != LIGHT_EMPTY)
			user << "There is a [fitting] already inserted."
			return
		else
			add_fingerprint(user)
			var/obj/item/weapon/light/L = W
			if (istype(L, light_type))
				status = L.status
				user << "You insert the [L.name]."
				switchcount = L.switchcount
				rigged = L.rigged
				brightness_range = L.brightness_range
				brightness_power = L.brightness_power
				brightness_color = L.brightness_color
				on = has_power()
				update()

				user.drop_item()	//drop the item to update overlays and such
				qdel(L)

				if (on && rigged)

					log_admin("LOG: Rigged light explosion, last touched by [fingerprintslast]")
					message_admins("LOG: Rigged light explosion, last touched by [fingerprintslast]")

					explode()
			else
				user << "This type of light requires a [fitting]."
				return

		// attempt to break the light
		//If xenos decide they want to smash a light bulb with a toolbox, who am I to stop them? /N

	else if (status != LIGHT_BROKEN && status != LIGHT_EMPTY)


		if (prob(1+W.force * 5))

			user << "You hit the light, and it smashes!"
			for (var/mob/M in viewers(src))
				if (M == user)
					continue
				M.show_message("[user.name] smashed the light!", 3, "You hear a tinkle of breaking glass", 2)
		//	if (on && (W.flags & CONDUCT))
				//if (!user.mutations & COLD_RESISTANCE)
		//		if (prob(12))
		//			electrocute_mob(user, get_area(src), src, 0.3)
			broken()

		else
			user << "You hit the light!"

	// attempt to stick weapon into light socket
	else if (status == LIGHT_EMPTY)
		if (istype(W, /obj/item/weapon/screwdriver)) //If it's a screwdriver open it.
			playsound(loc, 'sound/items/Screwdriver.ogg', 75, TRUE)
			user.visible_message("[user.name] opens [src]'s casing.", \
				"You open [src]'s casing.", "You hear a noise.")
			var/obj/structure/light_construct/newlight = null
			switch(fitting)
				if ("tube")
					newlight = new /obj/structure/light_construct(loc)
					newlight.icon_state = "tube-construct-stage2"

				if ("bulb")
					newlight = new /obj/structure/light_construct/small(loc)
					newlight.icon_state = "bulb-construct-stage2"
			newlight.dir = dir
			newlight.stage = 2
			newlight.fingerprints = fingerprints
			newlight.fingerprintshidden = fingerprintshidden
			newlight.fingerprintslast = fingerprintslast
			qdel(src)
			return

		user << "You stick \the [W] into the light socket!"
		if (has_power() && (W.flags & CONDUCT))
			var/datum/effect/effect/system/spark_spread/s = new /datum/effect/effect/system/spark_spread
			s.set_up(3, TRUE, src)
			s.start()
			//if (!user.mutations & COLD_RESISTANCE)
		//	if (prob(75))
			//	electrocute_mob(user, get_area(src), src, rand(0.7,1.0))


// returns whether this light has power
// true if area has power and lightswitch is on
/obj/structure/light/proc/has_power()
	var/area/A = get_area(src)
	return A && A.lightswitch && (!A.requires_power || A.power_light)

/obj/structure/light/proc/flicker(var/amount = 1, var/time = 2)
	if (flickering) return
	flickering = TRUE
	spawn(0)
		if (on && status == LIGHT_OK)
			for (var/i in 1 to amount)
				if (status != LIGHT_OK) break
				on = !on
				update(0, nosound = TRUE)
				sleep(time)
			on = (status == LIGHT_OK)
			update(0, nosound = TRUE)
		flickering = FALSE

/obj/structure/light/floor/streetlight/flicker()
	return

// attack with hand - remove tube/bulb
// if hands aren't protected and the light is on, burn the player
/obj/structure/light/attack_hand(mob/user)

	add_fingerprint(user)

	if (status == LIGHT_EMPTY)
		user << "There is no [fitting] in this light."
		return

	if (istype(user,/mob/living/carbon/human))
		var/mob/living/carbon/human/H = user
		if (H.species.can_shred(H))
			for (var/mob/M in viewers(src))
				M.show_message("<span class = 'red'>[user.name] smashed the light!</span>", 3, "You hear a tinkle of breaking glass", 2)
			broken()
			return

	// make it burn hands if not wearing fire-insulated gloves
	if (on)
		var/prot = FALSE
		var/mob/living/carbon/human/H = user

		if (istype(H))
			if (H.species.heat_level_1 > LIGHT_BULB_TEMPERATURE)
				prot = TRUE
			else if (H.gloves)
				var/obj/item/clothing/gloves/G = H.gloves
				if (G.max_heat_protection_temperature)
					if (G.max_heat_protection_temperature > LIGHT_BULB_TEMPERATURE)
						prot = TRUE
		else
			prot = TRUE

		if (prot > 0 || (COLD_RESISTANCE in user.mutations))
			user << "You remove the light [fitting]"
		else if (TK in user.mutations)
			user << "You telekinetically remove the light [fitting]."
		else
			user << "You try to remove the light [fitting], but it's too hot and you don't want to burn your hand."
			return				// if burned, don't remove the light
	else
		user << "You remove the light [fitting]."

	// create a light tube/bulb item and put it in the user's hand
	var/obj/item/weapon/light/L = new light_type()
	L.status = status
	L.rigged = rigged
	L.brightness_range = brightness_range
	L.brightness_power = brightness_power
	L.brightness_color = brightness_color

	// light item inherits the switchcount, then zero it
	L.switchcount = switchcount
	switchcount = FALSE

	L.update()
	L.add_fingerprint(user)

	user.put_in_active_hand(L)	//puts it in our active hand

	status = LIGHT_EMPTY
	update()

// break the light and make sparks if was on

/obj/structure/light/proc/broken(var/skip_sound_and_sparks = FALSE)
	if (status == LIGHT_EMPTY)
		return

	if (!skip_sound_and_sparks)
		if (status == LIGHT_OK || status == LIGHT_BURNED)
			playsound(loc, "shatter", 100)
		if (on)
			var/datum/effect/effect/system/spark_spread/s = new /datum/effect/effect/system/spark_spread
			s.set_up(3, TRUE, src)
			s.start()

	status = LIGHT_BROKEN
	update()

/obj/structure/light/proc/fix()
	if (status == LIGHT_OK)
		return
	status = LIGHT_OK
	on = TRUE
	update()

// explosion effect
// destroy the whole light fixture or just shatter it

/obj/structure/light/ex_act(severity)
	switch(severity)
		if (1.0)
			qdel(src)
			return
		if (2.0)
			if (prob(75))
				broken()
		if (3.0)
			if (prob(50))
				broken()
	return

/obj/structure/light/process()
	if (prob(1))
		flicker()
	// fixes lighting bug :agony:
	else if (on && loc && isturf(loc))
		var/turf/T = loc
		for (var/datum/lighting_corner/corner in T.corners)
			if (corner.lum_r == 0 || corner.lum_g == 0 || corner.lum_b == 0)
				flicker(1,0)
				break
	else
		on = FALSE
		update(0, nosound = TRUE)

/obj/structure/light/fire_act(temperature)
	if (prob(max(0, temperature - 330)))
		broken()

// explode the light

/obj/structure/light/proc/explode()
	var/turf/T = get_turf(loc)
	spawn(0)
		broken()	// break it first to give a warning
		sleep(2)
		explosion(T, FALSE, FALSE, 2, 2)
		sleep(1)
		qdel(src)

// the light item
// can be tube or bulb subtypes
// will fit into empty /obj/structure/light of the corresponding type

/obj/item/weapon/light
	icon = 'icons/obj/lighting.dmi'
	force = WEAPON_FORCE_HARMLESS
	throwforce = WEAPON_FORCE_HARMLESS
	w_class = 1
	var/status = FALSE		// LIGHT_OK, LIGHT_BURNED or LIGHT_BROKEN
	var/base_state
	var/switchcount = FALSE	// number of times switched
	matter = list(DEFAULT_WALL_MATERIAL = 60)
	var/rigged = FALSE		// true if rigged to explode
	var/brightness_range = 2 //how much light it gives off
	var/brightness_power = TRUE
	var/brightness_color = null

/obj/item/weapon/light/tube
	name = "light tube"
	desc = "A replacement light tube."
	icon_state = "ltube"
	base_state = "ltube"
	item_state = "c_tube"
	matter = list("glass" = 100)
	brightness_range = 8
	brightness_power = 3

/obj/item/weapon/light/tube/large
	w_class = 2
	name = "large light tube"
	brightness_range = 15
	brightness_power = 4

/obj/item/weapon/light/bulb
	name = "light bulb"
	desc = "A replacement light bulb."
	icon_state = "lbulb"
	base_state = "lbulb"
	item_state = "contvapour"
	matter = list("glass" = 100)
	brightness_range = 5
	brightness_power = 2
	brightness_color = "#a0a080"

/obj/item/weapon/light/throw_impact(atom/hit_atom)
	..()
	shatter()

/obj/item/weapon/light/bulb/fire
	name = "fire bulb"
	desc = "A replacement fire bulb."
	icon_state = "fbulb"
	base_state = "fbulb"
	item_state = "egg4"
	matter = list("glass" = 100)
	brightness_range = 5
	brightness_power = 2

// update the icon state and description of the light

/obj/item/weapon/light/proc/update()
	switch(status)
		if (LIGHT_OK)
			icon_state = base_state
			desc = "A replacement [name]."
		if (LIGHT_BURNED)
			icon_state = "[base_state]-burned"
			desc = "A burnt-out [name]."
		if (LIGHT_BROKEN)
			icon_state = "[base_state]-broken"
			desc = "A broken [name]."


/obj/item/weapon/light/New()
	..()
	switch(name)
		if ("light tube")
			brightness_range = rand(6,9)
		if ("light bulb")
			brightness_range = rand(4,6)
	update()


// attack bulb/tube with object
// if a syringe, can inject plasma to make it explode
/obj/item/weapon/light/attackby(var/obj/item/I, var/mob/user)
	..()
	if (istype(I, /obj/item/weapon/reagent_containers/syringe))
		var/obj/item/weapon/reagent_containers/syringe/S = I

		user << "You inject the solution into the [src]."

		if (S.reagents.has_reagent("plasma", 5))

			log_admin("LOG: [user.name] ([user.ckey]) injected a light with plasma, rigging it to explode.")
			message_admins("LOG: [user.name] ([user.ckey]) injected a light with plasma, rigging it to explode.")

			rigged = TRUE

		S.reagents.clear_reagents()
	else
		..()
	return

// called after an attack with a light item
// shatter light, unless it was an attempt to put it in a light socket
// now only shatter if the intent was harm

/obj/item/weapon/light/afterattack(atom/target, mob/user, proximity)
	if (!proximity) return
	if (istype(target, /obj/structure/light))
		return
	if (user.a_intent != I_HURT)
		return

	shatter()

/obj/item/weapon/light/proc/shatter()
	if (status == LIGHT_OK || status == LIGHT_BURNED)
		visible_message("<span class = 'red'>[name] shatters!</span>","<span class = 'red'>You hear a small glass object shatter.</span>")
		status = LIGHT_BROKEN
		force = WEAPON_FORCE_WEAK
		sharp = TRUE
		playsound(loc, 'sound/effects/Glasshit.ogg', 75, TRUE)
		update()
