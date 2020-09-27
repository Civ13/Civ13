//ancient stuff
/obj/item/projectile/bullet/rifle/stoneball
	damage = DAMAGE_VERY_HIGH + 26
	penetrating = 4
	armor_penetration = 33

// XVIII Century stuff
/obj/item/projectile/bullet/rifle/musketball
	damage = DAMAGE_VERY_HIGH + 47
	penetrating = 5
	armor_penetration = 33

/obj/item/projectile/bullet/rifle/musketball_pistol
	damage = DAMAGE_HIGH + 12
	penetrating = 2
	armor_penetration = 20

/obj/item/projectile/bullet/rifle/blunderbuss
	damage = DAMAGE_VERY_HIGH + 35
	penetrating = 2
	armor_penetration = 50

/obj/item/projectile/arrow
	embed = TRUE
	sharp = TRUE
	var/volume = 5

/obj/item/projectile/arrow/flint
	damage = DAMAGE_MEDIUM-10
	penetrating = 1
	armor_penetration = 10
	icon_state = "flint"
	embed = FALSE
	sharp = FALSE

/obj/item/projectile/arrow/stone
	damage = DAMAGE_MEDIUM-10
	penetrating = 1
	armor_penetration = 10
	icon_state = "stone"
	embed = FALSE
	sharp = FALSE

/obj/item/projectile/arrow/arrow
	damage = DAMAGE_LOW-28
	penetrating = 0
	armor_penetration = 0
	icon_state = "arrow"
	embed = FALSE
	sharp = FALSE

/obj/item/projectile/arrow/arrow/fire
	damage = DAMAGE_LOW
	penetrating = 0
	armor_penetration = 10
	icon_state = "arrow"
	damage_type = BURN
	embed = FALSE
	sharp = FALSE

/obj/item/projectile/arrow/arrow/fire/gods
	damage = DAMAGE_OH_GOD
	penetrating = 100
	armor_penetration = 1000
	icon_state = "arrow_god"
	damage_type = BURN
	gibs = TRUE
	crushes = TRUE

/obj/item/projectile/arrow/arrow/flint
	damage = DAMAGE_MEDIUM
	penetrating = 0
	armor_penetration = 3
	icon_state = "arrow_flint"

/obj/item/projectile/arrow/arrow/stone
	damage = DAMAGE_MEDIUM
	penetrating = 0
	armor_penetration = 2
	icon_state = "arrow_stone"

/obj/item/projectile/arrow/arrow/sandstone
	damage = DAMAGE_MEDIUM
	penetrating = 0
	armor_penetration = 2
	icon_state = "arrow_sandstone"

/obj/item/projectile/arrow/arrow/copper
	damage = DAMAGE_MEDIUM+1
	penetrating = 0
	armor_penetration = 2
	icon_state = "arrow_copper"

/obj/item/projectile/arrow/arrow/iron
	damage = DAMAGE_MEDIUM+2
	penetrating = 1
	armor_penetration = 4
	icon_state = "arrow_iron"

/obj/item/projectile/arrow/arrow/bronze
	damage = DAMAGE_MEDIUM+3
	penetrating = 1
	armor_penetration = 6
	icon_state = "arrow_bronze"

/obj/item/projectile/arrow/arrow/steel
	damage = DAMAGE_MEDIUM+4
	penetrating = 1
	armor_penetration = 8
	icon_state = "arrow_steel"

/obj/item/projectile/arrow/arrow/modern
	damage = DAMAGE_MEDIUM+5
	penetrating = 1
	armor_penetration = 8
	icon_state = "arrow_modern"

/obj/item/projectile/arrow/arrow/vial
	damage = DAMAGE_MEDIUM
	penetrating = 1
	armor_penetration = 10
	icon_state = "arrow_vial"
	volume = 15

/obj/item/projectile/arrow/arrow/vial/poisonous
	New()
		..()
		reagents.add_reagent("batrachotoxin",15)

/obj/item/projectile/arrow/bolt/vial/poisonous
	New()
		..()
		reagents.add_reagent("batrachotoxin",15)
/obj/item/projectile/arrow/arrow/fire/on_impact(mob/living/human/M as mob)
	if (prob(10))
		M.fire_stacks += 1
	if (M)
		M.IgniteMob()
	spawn (0.01)
		qdel(src)
	..()

//BOLTS
/obj/item/projectile/arrow/bolt
	damage = DAMAGE_LOW-20+5
	penetrating = 1
	armor_penetration = 6+10
	icon_state = "bolt_iron"

/obj/item/projectile/arrow/bolt/flint
	damage = DAMAGE_MEDIUM+5
	penetrating = 0
	armor_penetration = 2+10
	icon_state = "bolt_flint"

/obj/item/projectile/arrow/bolt/stone
	damage = DAMAGE_MEDIUM+5
	penetrating = 0
	armor_penetration = 2+10
	icon_state = "bolt_stone"

/obj/item/projectile/arrow/bolt/sandstone
	damage = DAMAGE_MEDIUM+5
	penetrating = 0
	armor_penetration = 2+10
	icon_state = "bolt_sandstone"

/obj/item/projectile/arrow/bolt/copper
	damage = DAMAGE_MEDIUM+1+5
	penetrating = 0
	armor_penetration = 2+10
	icon_state = "bolt_copper"

/obj/item/projectile/arrow/bolt/iron
	damage = DAMAGE_MEDIUM+5+5
	penetrating = 1
	armor_penetration = 6+10
	icon_state = "bolt_iron"

/obj/item/projectile/arrow/bolt/bronze
	damage = DAMAGE_MEDIUM+8+5
	penetrating = 1
	armor_penetration = 8+10
	icon_state = "bolt_bronze"

/obj/item/projectile/arrow/bolt/steel
	damage = DAMAGE_MEDIUM+11+5
	penetrating = 1
	armor_penetration = 10+10
	icon_state = "bolt_steel"

/obj/item/projectile/arrow/bolt/modern
	damage = DAMAGE_MEDIUM+11+5
	penetrating = 1
	armor_penetration = 10+10
	icon_state = "bolt_modern"

/obj/item/projectile/arrow/bolt/fire
	damage = DAMAGE_LOW+5
	penetrating = 0
	armor_penetration = 10+10
	icon_state = "bolt"
	damage_type = BURN
	embed = FALSE
	sharp = FALSE

/obj/item/projectile/arrow/bolt/fire/gods
	damage = DAMAGE_OH_GOD
	penetrating = 100
	armor_penetration = 1000
	icon_state = "bolt_god"
	damage_type = BURN
	gibs = TRUE
	crushes = TRUE

/obj/item/projectile/arrow/bolt/fire/on_impact(mob/living/human/M as mob)
	if (prob(10))
		M.fire_stacks += 1
	if (M)
		M.IgniteMob()
	spawn (0.01)
		qdel(src)
	..()

/obj/item/projectile/arrow/bolt/vial
	damage = DAMAGE_MEDIUM
	penetrating = 1
	armor_penetration = 10
	icon_state = "bolt_vial"
	volume = 15

/obj/item/projectile/arrow/on_impact(var/atom/A as mob)
	if (istype(src, /obj/item/projectile/arrow/bolt/vial) || istype(src, /obj/item/projectile/arrow/arrow/vial))
		if (ishuman(A))
			var/mob/living/human/H = A
			reagents.trans_to_mob(H, volume, CHEM_BLOOD)
		else
			reagents.trans_to(A, volume)
	..()

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
	damage = DAMAGE_VERY_HIGH + 11
	penetrating = 5
	armor_penetration = 37
/obj/item/projectile/bullet/rifle/a65x50/weak/New()
	..()
	damage = (DAMAGE_VERY_HIGH)/2
	penetrating = 3
	armor_penetration = 10

/obj/item/projectile/bullet/rifle/a65x52
	damage = DAMAGE_VERY_HIGH
	penetrating = 5
	armor_penetration = 35

/obj/item/projectile/bullet/rifle/a8x53
	damage = DAMAGE_VERY_HIGH + 13
	penetrating = 6
	armor_penetration = 37

/obj/item/projectile/bullet/rifle/a8x50
	damage = DAMAGE_VERY_HIGH + 20
	penetrating = 6
	armor_penetration = 40

/obj/item/projectile/bullet/rifle/a8x50/weak/New()
	..()
	damage = (damage)/2
	penetrating = 1
	armor_penetration = 19

/obj/item/projectile/bullet/rifle/a762x54
	damage = DAMAGE_VERY_HIGH + 40
	penetrating = 6
	armor_penetration = 47

/obj/item/projectile/bullet/rifle/a762x54/weak/New()
	..()
	damage = (damage)/2
	penetrating = 1
	armor_penetration = 18

/obj/item/projectile/bullet/pistol/a762x38
	damage = DAMAGE_LOW + 6
	penetrating = 2
	armor_penetration = 6

/obj/item/projectile/bullet/pistol/a8x27
	damage = DAMAGE_LOW - 6
	penetrating = 1
	armor_penetration = 3

/obj/item/projectile/bullet/pistol/a32
	damage = DAMAGE_LOW - 3
	penetrating = 1
	armor_penetration = 3

/obj/item/projectile/bullet/pistol/a32acp
	damage = DAMAGE_LOW - 8
	penetrating = 2
	armor_penetration = 1

/obj/item/projectile/bullet/pistol/webly445
	damage = DAMAGE_MEDIUM_HIGH + 7
	penetrating = 1
	armor_penetration = 4

/obj/item/projectile/bullet/pistol/a38
	damage = DAMAGE_MEDIUM+4
	penetrating = 1
	armor_penetration = 5

/obj/item/projectile/bullet/pistol/a380acp
    damage = DAMAGE_LOW - 9
    penetrating = 2
    armor_penetration = 4

/obj/item/projectile/bullet/pistol/a41
	damage = DAMAGE_LOW - 11
	penetrating = 1
	armor_penetration = 3

/obj/item/projectile/bullet/pistol/a43
	damage = DAMAGE_VERY_HIGH - 4
	penetrating = 1
	armor_penetration = 5

/obj/item/projectile/bullet/pistol/a45
	damage = DAMAGE_VERY_HIGH - 3
	penetrating = 1
	armor_penetration = 6

/obj/item/projectile/bullet/pistol/a455
	damage = DAMAGE_MEDIUM_HIGH + 7
	penetrating = 1
	armor_penetration = 4

/obj/item/projectile/bullet/rifle/a44
	damage = DAMAGE_HIGH + 4
	penetrating = 2
	armor_penetration = 10

/obj/item/projectile/bullet/rifle/a44magnum
	damage = DAMAGE_HIGH+50
	penetrating = 2
	armor_penetration = 15

/obj/item/projectile/bullet/rifle/a4570
	damage = DAMAGE_VERY_HIGH + 58
	penetrating = 3
	armor_penetration = 16

/obj/item/projectile/bullet/rifle/a792x57
	damage = DAMAGE_VERY_HIGH + 46
	penetrating = 5
	armor_penetration = 50

/obj/item/projectile/bullet/rifle/a792x57/weak/New()
	..()
	damage = (DAMAGE_VERY_HIGH)/2
	penetrating = 3
	armor_penetration = 20

/obj/item/projectile/bullet/rifle/a765x53
	damage = DAMAGE_VERY_HIGH + 20
	penetrating = 5
	armor_penetration = 42

/obj/item/projectile/bullet/rifle/a765x25
	damage = DAMAGE_LOW + 2
	penetrating = 2
	armor_penetration = 7

/obj/item/projectile/bullet/rifle/a7x57
	damage = DAMAGE_VERY_HIGH + 17
	penetrating = 5
	armor_penetration = 36

/obj/item/projectile/bullet/rifle/a77x58
	damage = DAMAGE_VERY_HIGH + 20
	penetrating = 5
	armor_penetration = 44

/obj/item/projectile/bullet/rifle/a77x58_wood
	damage = 2
	penetrating = 0
	armor_penetration = 0

/obj/item/projectile/bullet/rifle/a77x58/weak/New()
	..()
	damage = (DAMAGE_VERY_HIGH)/2
	penetrating = 4
	armor_penetration = 22

/obj/item/projectile/bullet/rifle/a577
	damage = DAMAGE_VERY_HIGH + 88
	penetrating = 3
	armor_penetration = 31

/obj/item/projectile/bullet/rifle/a303
	damage = DAMAGE_VERY_HIGH + 19
	penetrating = 4
	armor_penetration = 44

/obj/item/projectile/bullet/rifle/a303/weak/New()
	..()
	damage = (DAMAGE_VERY_HIGH)/2
	penetrating = 3
	armor_penetration = 22

/obj/item/projectile/bullet/rifle/a3006
	damage = DAMAGE_VERY_HIGH + 35
	penetrating = 4
	armor_penetration = 47

/obj/item/projectile/bullet/rifle/a3006/weak/New()
	..()
	damage = (DAMAGE_VERY_HIGH)/2
	penetrating = 3
	armor_penetration = 24

/obj/item/projectile/bullet/pistol/c9mm_jap_revolver
	damage = DAMAGE_LOW - 12
	penetrating = 1
	armor_penetration = 3

/obj/item/projectile/bullet/mg/a127x108
	damage = DAMAGE_OH_GOD + 110
	penetrating = 7
	armor_penetration = 75


/obj/item/projectile/bullet/pistol/c8mmnambu
	damage = DAMAGE_LOW - 9
	penetrating = 1
	armor_penetration = 5

/obj/item/projectile/bullet/pistol/a9x19
	damage = DAMAGE_LOW
	penetrating = 2
	armor_penetration = 8

/obj/item/projectile/bullet/pistol/a792x33
	damage = DAMAGE_HIGH + 5
	penetrating = 3
	armor_penetration = 28

/obj/item/projectile/bullet/rifle/a762x39
	damage = DAMAGE_HIGH + 12
	penetrating = 3
	armor_penetration = 30

obj/item/projectile/bullet/rifle/a545x39
	damage = DAMAGE_MEDIUM_HIGH + 15
	penetrating = 3
	armor_penetration = 16

/obj/item/projectile/bullet/rifle/a762x51
	damage = DAMAGE_VERY_HIGH + 23
	penetrating = 5
	armor_penetration = 42
/obj/item/projectile/bullet/rifle/a762x51/weak/New()
	damage = (DAMAGE_VERY_HIGH)/2
	penetrating = 3
	armor_penetration = 21

obj/item/projectile/bullet/rifle/a556x45
	damage = DAMAGE_HIGH + 3
	penetrating = 3
	armor_penetration = 18

/obj/item/projectile/bullet/pistol/a765x25
	damage = DAMAGE_LOW + 2
	penetrating = 2
	armor_penetration = 7

/obj/item/projectile/bullet/pistol/a762x25
	damage = DAMAGE_MEDIUM_HIGH + 4
	penetrating = 2
	armor_penetration = 12

/obj/item/projectile/bullet/pistol/a57x28
	damage = DAMAGE_LOW - 12
	penetrating = 2
	armor_penetration = 43

/obj/item/projectile/bullet/rifle/a50cal
	damage = DAMAGE_OH_GOD + 95
	penetrating = 8
	armor_penetration = 75

/obj/item/projectile/bullet/pistol/a44p
	damage = DAMAGE_LOW - 20
	penetrating = 1
	armor_penetration = 1

/obj/item/projectile/bullet/shotgun/buckshot
	name = "buckshot"
	damage = DAMAGE_VERY_HIGH + 35
	armor_penetration = 33

/obj/item/projectile/bullet/shotgun/slug
	name = "shotgun slug"
	damage = DAMAGE_MEDIUM_HIGH
	damage = DAMAGE_VERY_HIGH + 67
	armor_penetration = 10

/obj/item/projectile/bullet/shotgun/beanbag
	name = "beanbag"
	check_armor = "melee"
	armor_penetration = 0
	damage = 5
	agony = 60
	embed = FALSE
	sharp = FALSE

/obj/item/projectile/bullet/shotgun/rubber
	name = "rubber shell"
	check_armor = "melee"
	armor_penetration = 0
	damage = 10
	agony = 100
	embed = FALSE
	sharp = FALSE