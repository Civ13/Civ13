//ancient stuff
/obj/item/projectile/bullet/rifle/stoneball
	damage = DAMAGE_HIGH + 8
	penetrating = 1
	armor_penetration = 30
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

/obj/item/projectile/bullet/rifle/a65x50mm
	damage = DAMAGE_HIGH-3
	penetrating = 2
	armor_penetration = 40

/obj/item/projectile/bullet/rifle/a8x53mm
	damage = DAMAGE_HIGH+2
	penetrating = 3
	armor_penetration = 48

/obj/item/projectile/bullet/rifle/a762x54
	damage = DAMAGE_HIGH+1
	penetrating = 2
	armor_penetration = 45

/obj/item/projectile/bullet/pistol/a762x38
	damage = DAMAGE_MEDIUM
	penetrating = 2
	armor_penetration = 38

/obj/item/projectile/bullet/pistol/a45
	damage = DAMAGE_MEDIUM+5
	penetrating = 2
	armor_penetration = 35

/obj/item/projectile/bullet/rifle/a44
	damage = DAMAGE_HIGH-6
	penetrating = 1
	armor_penetration = 35

/obj/item/projectile/bullet/rifle/a4570
	damage = DAMAGE_HIGH+3
	penetrating = 2
	armor_penetration = 55

/obj/item/projectile/bullet/pistol/c9mm_jap_revolver
	damage = DAMAGE_MEDIUM + 1
	penetrating = 1
	armor_penetration = 30

/obj/item/projectile/bullet/mg/a127x108
	damage = DAMAGE_HIGH + 2
	penetrating = 2
	armor_penetration = 42

/obj/item/projectile/bullet/mg/a77x58_weaker
	damage = DAMAGE_HIGH + 2
	penetrating = 2
	armor_penetration = 40

/obj/item/projectile/bullet/pistol/c8mmnambu
	damage = DAMAGE_MEDIUM + 2
	penetrating = 1
	armor_penetration = 25

/obj/item/projectile/bullet/pistol/a44p
	damage = DAMAGE_MEDIUM + 2
	penetrating = 1
	armor_penetration = 38

/obj/item/projectile/bullet/shotgun/buckshot
	name = "buckshot"
	damage = DAMAGE_HIGH + 5
	armor_penetration = 20

/obj/item/projectile/bullet/shotgun/slug
	name = "shotgun slug"
	damage = DAMAGE_MEDIUM_HIGH
	armor_penetration = 60
	penetrating = 1

/obj/item/projectile/bullet/shotgun/beanbag
	name = "beanbag"
	check_armour = "melee"
	damage = DAMAGE_LOW/2
	agony = DAMAGE_MEDIUM_HIGH
	embed = FALSE
	sharp = FALSE