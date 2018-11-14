
// XVIII Century stuff
/obj/item/projectile/bullet/rifle/musketball
	damage = DAMAGE_HIGH + 4
	penetrating = 2
	armor_penetration = 70

/obj/item/projectile/bullet/rifle/musketball_pistol
	damage = DAMAGE_MEDIUM + 8
	penetrating = 1
	armor_penetration = 40

/obj/item/projectile/bullet/rifle/blunderbuss
	damage = DAMAGE_HIGH + 10
	penetrating = 3
	armor_penetration = 100

/obj/item/projectile/arrow/arrow
	damage = DAMAGE_MEDIUM
	penetrating = 1
	armor_penetration = 35
	icon_state = "arrow"

/obj/item/projectile/arrow/arrow/poisonous
	damage = DAMAGE_MEDIUM
	penetrating = 1
	armor_penetration = 35
	icon_state = "arrow"
	poisonous = 1

/obj/item/projectile/grenade/smoke
	name = "smoke grenade"

	kill_count = 10

	var/datum/effect/effect/system/smoke_spread/bad/smoke

	New()
		..()
		smoke = PoolOrNew(/datum/effect/effect/system/smoke_spread/bad)
		smoke.attach(src)

	on_hit(atom/hit_atom)
		name += " (Used)"
		playsound(loc, 'sound/effects/smoke.ogg', 50, TRUE, -3)
		smoke.set_up(5, FALSE, usr.loc)
		spawn(0)
			smoke.start()
			sleep(10)
			smoke.start()
			sleep(10)
			smoke.start()
			sleep(10)
			smoke.start()

	on_impact(atom/hit_atom)
		on_hit(hit_atom)