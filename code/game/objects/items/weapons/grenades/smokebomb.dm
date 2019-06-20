/obj/item/weapon/grenade/smokebomb
	desc = "It is set to detonate in 2 seconds."
	name = "smoke bomb"
	icon = 'icons/obj/grenade.dmi'
	icon_state = "flashbang"
	det_time = 20
	item_state = "flashbang"
	slot_flags = SLOT_BELT
	var/datum/effect/effect/system/smoke_spread/bad/smoke

/obj/item/weapon/grenade/smokebomb/New()
	..()
	smoke = PoolOrNew(/datum/effect/effect/system/smoke_spread/bad)
	smoke.attach(src)

/obj/item/weapon/grenade/smokebomb/Destroy()
	qdel(smoke)
	smoke = null
	return ..()

/obj/item/weapon/grenade/smokebomb/prime()
	if (active)
		playsound(loc, 'sound/effects/smoke.ogg', 50, TRUE, -3)
		smoke.set_up(10, FALSE, usr ? usr.loc : loc)
		spawn(0)
			smoke.start()
			sleep(10)
			smoke.start()
			sleep(10)
			smoke.start()
			sleep(10)
			smoke.start()

		sleep(80)
		qdel(src)
		return

/obj/item/weapon/grenade/smokebomb/fast_activate()
	spawn(round(det_time/10))
		visible_message("<span class = 'warning'>\The [src] goes off!</span>")
		active = TRUE
		prime()

/obj/item/weapon/grenade/smokebomb/m18smoke
	desc = "It is set to detonate in 2 seconds."
	name = "M18 smoke grenade"
	icon_state = "m18smoke"
	det_time = 20
	item_state = "m18smoke"


/obj/item/weapon/grenade/incendiary
	desc = "It is set to detonate in 6 seconds."
	name = "incendiary grenade"
	icon = 'icons/obj/grenade.dmi'
	icon_state = "incendiary"
	det_time = 60
	item_state = "incendiary"
	slot_flags = SLOT_BELT
	var/spread_range = 2

/obj/item/weapon/grenade/incendiary/anm14
	name = "AN/M14 incendiary grenade"

/obj/item/weapon/grenade/incendiary/prime()
	if (active)
		playsound(loc, 'sound/effects/smoke.ogg', 50, TRUE, -3)
		var/turf/LT = get_turf(src)
		explosion(LT,0,1,1,3)
		for (var/turf/floor/T in range(spread_range,LT))
			for (var/mob/living/LS1 in T)
				LS1.adjustFireLoss(35)
				LS1.fire_stacks += rand(8,10)
				LS1.IgniteMob()
			new/obj/effect/burning_oil(T)
		sleep(50)
		qdel(src)
		return

/obj/item/weapon/grenade/incendiary/fast_activate()
	spawn(round(det_time/10))
		visible_message("<span class = 'warning'>\The [src] goes off!</span>")
		active = TRUE
		prime()