//ancient stuff
/obj/item/projectile/bullet/rifle/stoneball
	damage = DAMAGE_HIGH + 8
	penetrating = 1
	armor_penetration = 20
// XVIII Century stuff
/obj/item/projectile/bullet/rifle/musketball
	damage = DAMAGE_HIGH + 4
	penetrating = 2
	armor_penetration = 20

/obj/item/projectile/bullet/rifle/musketball_pistol
	damage = DAMAGE_MEDIUM + 8
	penetrating = 1
	armor_penetration = 10

/obj/item/projectile/bullet/rifle/blunderbuss
	damage = DAMAGE_HIGH + 10
	penetrating = 3
	armor_penetration = 40

/obj/item/projectile/arrow
	embed = TRUE
	sharp = TRUE
/obj/item/projectile/arrow/stone
	damage = DAMAGE_MEDIUM-10
	penetrating = 1
	armor_penetration = 10
	icon_state = "stone"

/obj/item/projectile/arrow/arrow
	damage = DAMAGE_MEDIUM-2
	penetrating = 1
	armor_penetration = 10
	icon_state = "arrow"

/obj/item/projectile/arrow/arrow/poisonous
	damage = DAMAGE_MEDIUM-2
	penetrating = 1
	armor_penetration = 10
	icon_state = "arrow"
	damage_type = TOX

/obj/item/projectile/arrow/arrow/fire
	damage = DAMAGE_MEDIUM-3
	penetrating = 1
	armor_penetration = 10
	icon_state = "arrow"
	damage_type = BURN

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

/obj/item/projectile/bullet/rifle/a65x50
	damage = DAMAGE_HIGH-3
	penetrating = 2
	armor_penetration = 10
/obj/item/projectile/bullet/rifle/a65x50/weak/New()
	..()
	damage = (DAMAGE_HIGH-3)/2
	penetrating = 1
	armor_penetration = 10

/obj/item/projectile/bullet/rifle/a65x52
	damage = DAMAGE_HIGH-3
	penetrating = 2
	armor_penetration = 10


/obj/item/projectile/bullet/rifle/a8x53
	damage = DAMAGE_HIGH+2
	penetrating = 3
	armor_penetration = 20

/obj/item/projectile/bullet/rifle/a8x50
	damage = DAMAGE_HIGH+1
	penetrating = 3
	armor_penetration = 19

/obj/item/projectile/bullet/rifle/a8x50/weak/New()
	..()
	damage = (damage)/2
	penetrating = 1
	armor_penetration = 19

/obj/item/projectile/bullet/rifle/a762x54
	damage = DAMAGE_HIGH+1
	penetrating = 2
	armor_penetration = 18

/obj/item/projectile/bullet/rifle/a762x54/weak/New()
	..()
	damage = (damage)/2
	penetrating = 1
	armor_penetration = 18

/obj/item/projectile/bullet/pistol/a762x38
	damage = DAMAGE_MEDIUM
	penetrating = 2
	armor_penetration = 12

/obj/item/projectile/bullet/pistol/a8x27
	damage = DAMAGE_MEDIUM-3
	penetrating = 1
	armor_penetration = 9


/obj/item/projectile/bullet/pistol/a41
	damage = DAMAGE_MEDIUM+1
	penetrating = 1
	armor_penetration = 11

/obj/item/projectile/bullet/pistol/a45
	damage = DAMAGE_MEDIUM+5
	penetrating = 2
	armor_penetration = 15

/obj/item/projectile/bullet/pistol/a455
	damage = DAMAGE_MEDIUM+6
	penetrating = 2
	armor_penetration = 15

/obj/item/projectile/bullet/rifle/a44
	damage = DAMAGE_HIGH-6
	penetrating = 1
	armor_penetration = 13

/obj/item/projectile/bullet/rifle/a4570
	damage = DAMAGE_HIGH+3
	penetrating = 2
	armor_penetration = 20

/obj/item/projectile/bullet/rifle/a792x57
	damage = DAMAGE_HIGH+2
	penetrating = 2
	armor_penetration = 20

/obj/item/projectile/bullet/rifle/a792x57/weak/New()
	..()
	damage = (DAMAGE_HIGH+2)/2
	penetrating = 1
	armor_penetration = 20

/obj/item/projectile/bullet/rifle/a765x53
	damage = DAMAGE_HIGH+1
	penetrating = 2
	armor_penetration = 17

/obj/item/projectile/bullet/rifle/a765x25
	damage = DAMAGE_HIGH
	penetrating = 2
	armor_penetration = 12


/obj/item/projectile/bullet/rifle/a7x57
	damage = DAMAGE_HIGH-2
	penetrating = 2
	armor_penetration = 12

/obj/item/projectile/bullet/rifle/a77x58
	damage = DAMAGE_HIGH+2
	penetrating = 2
	armor_penetration = 17
/obj/item/projectile/bullet/rifle/a77x58/weak/New()
	..()
	damage = (DAMAGE_HIGH+2)/2
	penetrating = 1
	armor_penetration = 13

/obj/item/projectile/bullet/rifle/a577
	damage = DAMAGE_HIGH+6
	penetrating = 3
	armor_penetration = 40

/obj/item/projectile/bullet/rifle/a303
	damage = DAMAGE_HIGH+2
	penetrating = 3
	armor_penetration = 13

/obj/item/projectile/bullet/rifle/a303/weak/New()
	..()
	damage = (DAMAGE_HIGH+2)/2
	penetrating = 1
	armor_penetration = 13

/obj/item/projectile/bullet/rifle/a3006
	damage = DAMAGE_HIGH+2
	penetrating = 3
	armor_penetration = 13

/obj/item/projectile/bullet/rifle/a3006/weak/New()
	..()
	damage = (DAMAGE_HIGH+2)/2
	penetrating = 1
	armor_penetration = 13

/obj/item/projectile/bullet/pistol/c9mm_jap_revolver
	damage = DAMAGE_MEDIUM + 1
	penetrating = 1
	armor_penetration = 9

/obj/item/projectile/bullet/mg/a127x108
	damage = DAMAGE_HIGH + 2
	penetrating = 2
	armor_penetration = 45


/obj/item/projectile/bullet/pistol/c8mmnambu
	damage = DAMAGE_MEDIUM + 2
	penetrating = 1
	armor_penetration = 8

/obj/item/projectile/bullet/pistol/a9x19
	damage = DAMAGE_MEDIUM + 2
	penetrating = 1
	armor_penetration = 10

/obj/item/projectile/bullet/pistol/a792x33
	damage = DAMAGE_MEDIUM + 8
	penetrating = 1
	armor_penetration = 12

/obj/item/projectile/bullet/rifle/a762x39
	damage = DAMAGE_MEDIUM_HIGH+3
	penetrating = 2
	armor_penetration = 17

obj/item/projectile/bullet/rifle/a545x39
	damage = DAMAGE_MEDIUM
	penetrating = 1
	armor_penetration = 10
/obj/item/projectile/bullet/rifle/a762x51
	damage = DAMAGE_MEDIUM_HIGH+5
	penetrating = 2
	armor_penetration = 20
/obj/item/projectile/bullet/rifle/a762x51/weak/New()
	damage = (DAMAGE_MEDIUM_HIGH+5)/2
	penetrating = 1
	armor_penetration = 20

obj/item/projectile/bullet/rifle/a556x45
	damage = DAMAGE_MEDIUM+4
	penetrating = 1
	armor_penetration = 12

/obj/item/projectile/bullet/pistol/a765x25
	damage = DAMAGE_MEDIUM + 2
	penetrating = 2
	armor_penetration = 12

/obj/item/projectile/bullet/pistol/a762x25
	damage = DAMAGE_MEDIUM + 2
	penetrating = 2
	armor_penetration = 12

/obj/item/projectile/bullet/pistol/a44p
	damage = DAMAGE_MEDIUM + 2
	penetrating = 1
	armor_penetration = 15

/obj/item/projectile/bullet/shotgun/buckshot
	name = "buckshot"
	damage = DAMAGE_HIGH + 5
	armor_penetration = 10

/obj/item/projectile/bullet/shotgun/slug
	name = "shotgun slug"
	damage = DAMAGE_MEDIUM_HIGH
	armor_penetration = 60
	penetrating = 2

/obj/item/projectile/bullet/shotgun/beanbag
	name = "beanbag"
	check_armor = "melee"
	armor_penetration = 0
	damage = DAMAGE_LOW/2
	agony = DAMAGE_MEDIUM_HIGH
	embed = FALSE
	sharp = FALSE


//generic calibers for custom weapons
/obj/item/projectile/bullet/rifle/largerifle
	damage = DAMAGE_HIGH+2
	penetrating = 2
	armor_penetration = 20

/obj/item/projectile/bullet/rifle/smallrifle
	damage = DAMAGE_HIGH-3
	penetrating = 2
	armor_penetration = 10

/obj/item/projectile/bullet/pistol/pistol45
	damage = DAMAGE_MEDIUM+5
	penetrating = 2
	armor_penetration = 15

/obj/item/projectile/bullet/pistol/pistol9
	damage = DAMAGE_MEDIUM + 2
	penetrating = 1
	armor_penetration = 10

/obj/item/projectile/bullet/rifle/intermediumrifle
	damage = DAMAGE_MEDIUM_HIGH+3
	penetrating = 2
	armor_penetration = 17

obj/item/projectile/bullet/rifle/smallintermediumrifle
	damage = DAMAGE_MEDIUM
	penetrating = 1
	armor_penetration = 10