/obj/structure/vehicle/magic
	name = "magical vehicle"
	icon = 'icons/obj/magic_weapons.dmi'
	var/magic_energy = TRUE

/obj/item/vehicleparts/wheel/handle/mop_handle
	name = "mop handle"
	attack_self(mob/user)
		if(istype(origin, /obj/structure/vehicle/magic/mop))
			var/obj/structure/vehicle/magic/mop/M = origin
			M.toggle_power(user)
	secondary_attack_self(mob/user)
		if(istype(origin, /obj/structure/vehicle/magic/mop))
			var/obj/structure/vehicle/magic/mop/M = origin
			M.dismount_driver(user)

/obj/structure/vehicle/magic/mop
	name = "flying mop"
	desc = "A sturdy cleaning mop etched with silver runes. It hums with a faint, magical energy and smells of lavender soap."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "mop"
	vehicle_m_delay = 1
	health = 50
	not_movable = TRUE
	not_disassemblable = FALSE
	flammable = TRUE
	mobcapacity = 1
	leave_time = 5
	wheeled = TRUE
	var/on = FALSE
	var/image/mop_overlay = null

/obj/structure/vehicle/magic/mop/New()
	..()
	// Brooms don't use mechanical engines or fuel tanks, but need an axis/wheel for movement logic
	engine = null
	fueltank = null
	axis = new/obj/structure/vehicleparts/axis/bike
	dwheel = new/obj/item/vehicleparts/wheel/handle/mop_handle
	dwheel.origin = src
	mop_overlay = image(icon, "mop_overlay")
	mop_overlay.layer = MOB_LAYER + 2.1

/obj/structure/vehicle/magic/mop/do_vehicle_check()
	if (!driver)
		return FALSE

	// Check driver status - magic requires concentration
	if (driver.stat != CONSCIOUS)
		visible_message(SPAN_WARNING("<b>[driver]</b> loses concentration and falls from \the [src]!"))
		dismount_driver()
		return FALSE

	if (!on)
		return FALSE

	if (driver.juice < 1)
		visible_message(SPAN_WARNING("<b>[driver]</b> runs out of magical energy and falls from \the [src]!"))
		on = FALSE
		dismount_driver()
		return FALSE

	var/turf/T = get_turf(get_step(src, driver.dir))
	if (!T) return FALSE

	if (!check_engine())
		moving = FALSE
		stopmovementloop()
		return FALSE

	var/blocked = FALSE
	if (T.density)
		blocked = TRUE
	else
		for (var/obj/structure/O in T)
			if (O.density && O != src)
				blocked = TRUE
				break

	if (blocked)
		visible_message(SPAN_DANGER("\The [src] crashes into \the [T]!"))
		health -= rand(5, 10)
		driver.adjustBruteLoss(rand(10, 20))
		driver.Weaken(3)
		if (prob(60))
			dismount_driver()
		return FALSE

	return TRUE

/obj/structure/vehicle/magic/mop/MouseDrop_T(atom/A, mob/living/human/user)
	if (!istype(A, /mob/living/human))
		return

	var/mob/living/human/H = A
	if (H != user)
		return
	if (H.anchored || H.driver || (H in ontop) || ontop.len >= mobcapacity)
		return

	user.visible_message(SPAN_NOTICE("[H] begins to mount \the [src]..."), SPAN_NOTICE("You begin to mount \the [src]..."))
	if (do_after(user, 20, src))
		if (H != user || H.anchored || H.driver || (H in ontop) || ontop.len >= mobcapacity)
			return
		if (H.put_in_active_hand(dwheel) == FALSE)
			to_chat(H, SPAN_WARNING("You need a free hand to hold the [dwheel.name]!"))
			return
		H.forceMove(get_turf(src))
		H.driver = TRUE
		H.driver_vehicle = src
		driver = H
		buckle_mob(H)
		ontop += H
		to_chat(H, SPAN_NOTICE("Click \the [src] to start flying!"))
		update_icon()
/obj/structure/vehicle/magic/mop/attackby(obj/item/weapon/W as obj, mob/living/human/user as mob)
	if (user == driver && istype(W, /obj/item/vehicleparts/wheel))
		user.visible_message(SPAN_NOTICE("[user] hops off \the [src]."), SPAN_NOTICE("You hop off \the [src]."))
		dismount_driver()
		return
	..()

/obj/structure/vehicle/magic/mop/proc/toggle_power(mob/user)
	
	if (!driver || user != driver)
		return
	on = !on
	to_chat(driver, SPAN_NOTICE("You [on ? "focus your energy into" : "stop channeling magic into"] \the [src]."))
	if (on)
		axis.currentspeed = 2
		startmovementloop()
	else
		stopmovementloop()
	update_icon()

/obj/structure/vehicle/magic/mop/attack_hand(mob/living/human/user)
	if (user in ontop)
		user.visible_message(SPAN_NOTICE("[user] hops off \the [src]."), SPAN_NOTICE("You hop off \the [src]."))
		dismount_driver()
	else
		..()

/obj/structure/vehicle/magic/mop/proc/dismount_driver(mob/user)
	if (user && user != driver)
		return
	if (!driver)
		return

	var/mob/living/human/H = driver
	if (H.l_hand == dwheel)
		H.remove_from_mob(dwheel)
	else if (H.r_hand == dwheel)
		H.remove_from_mob(dwheel)
	dwheel.forceMove(src)

	on = FALSE
	stopmovementloop()
	ontop -= H
	H.driver = FALSE
	H.driver_vehicle = null
	unbuckle_mob()
	driver = null

	// Reset positioning
	H.pixel_x = 0
	H.pixel_y = 0
	H.update_icons()
	update_icon()

/obj/structure/vehicle/magic/mop/update_icon()
	if (driver)
		dir = driver.dir
	update_overlay()
	..()

/obj/structure/vehicle/magic/mop/update_overlay()
	if (driver)
		add_overlay(mop_overlay)
	else
		overlays -= mop_overlay

/obj/structure/vehicle/magic/mop/check_engine()
	if (!on || !driver || driver.juice < 1)
		return FALSE
	return TRUE

/obj/structure/vehicle/magic/mop/do_move(var/m_dir = null)
	if (driver && ishuman(driver))
		var/mob/living/human/H = driver
		H.juice = max(0, H.juice - 0.7)
		if (H.juice <= 0)
			on = FALSE
			stopmovementloop()
			do_vehicle_check()
			return

	var/turf/T = get_step(src, m_dir)
	if (T && !T.density) // Mops can fly over water/trenches unlike bikes
		..()
	else if (T)
		do_vehicle_check()