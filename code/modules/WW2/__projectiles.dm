/* shotgun projectiles */

/obj/item/projectile/bullet/shotgun
	name = "shotgun slug"
	damage = DAMAGE_HIGH + 5
	armor_penetration = 60

/obj/item/projectile/bullet/shotgun/beanbag
	name = "beanbag"
	check_armour = "melee"
	damage = DAMAGE_LOW/2
	agony = DAMAGE_MEDIUM_HIGH
	embed = FALSE
	sharp = FALSE

/obj/item/projectile/bullet/shotgun/murder
	armor_penetration = 500
	damage = DAMAGE_OH_GOD
	accuracy = 5000
	penetrating = 0
	execution = TRUE

/obj/item/projectile/bullet/rifle
	armor_penetration = 50

/obj/item/projectile/bullet/rifle/murder
	armor_penetration = 500
	damage = DAMAGE_OH_GOD
	accuracy = 5000
	penetrating = 0
	execution = TRUE

// STG44
/obj/item/projectile/bullet/rifle/a792x33
	damage = DAMAGE_MEDIUM - 4
	penetrating = 1

// MOSIN
/obj/item/projectile/bullet/rifle/a762x54
	damage = DAMAGE_HIGH - 2
	penetrating = 2
	armor_penetration = 100

// KAR
/obj/item/projectile/bullet/rifle/a792x57
	damage = DAMAGE_HIGH + 4
	penetrating = 2
	armor_penetration = 100


// ARISAKA
/obj/item/projectile/bullet/rifle/a77x58
	damage = DAMAGE_HIGH + 3
	penetrating = 2
	armor_penetration = 100

//TYPE 92 HMG
/obj/item/projectile/bullet/rifle/a77x58_weaker
	damage = DAMAGE_MEDIUM - 4
	penetrating = 1

// M1GARAND
/obj/item/projectile/bullet/rifle/c762x63
	damage = DAMAGE_HIGH + 3
	penetrating = 2
	armor_penetration = 100

// BAR
/obj/item/projectile/bullet/rifle/c762x63_smg
	damage = DAMAGE_MEDIUM_HIGH
	penetrating = 2
	armor_penetration = 100

// TYPE 99 LMG
/obj/item/projectile/bullet/rifle/c77x58_smg
	damage = DAMAGE_MEDIUM_HIGH-1
	penetrating = 2
	armor_penetration = 100

// MG34
/obj/item/projectile/bullet/rifle/a792x57_weaker
	damage = DAMAGE_MEDIUM - 4
	penetrating = 1

/obj/item/projectile/bullet/rifle/a762x25
	damage = DAMAGE_LOW
	penetrating = 0

// MP40 SMG //
/obj/item/projectile/bullet/rifle/a9_parabellum
	damage = DAMAGE_LOW + 2
	penetrating = 0

// 45 smg //
/obj/item/projectile/bullet/rifle/c45_smg
	damage = DAMAGE_LOW + 4
	penetrating = 0

// LUGER PISTOL //
/obj/item/projectile/bullet/rifle/a9_parabellum_luger
	damage = DAMAGE_MEDIUM+5
	penetrating = 0

/obj/item/projectile/bullet/rifle/a762
	damage = DAMAGE_MEDIUM
	penetrating = 1

// PTRD AT GUN //
/obj/item/projectile/bullet/rifle/a145
	damage = DAMAGE_VERY_HIGH
	stun = 3
	weaken = 3
	penetrating = 5
	armor_penetration = 150
//4mm??
/obj/item/projectile/bullet/rifle/c4mm
	damage = DAMAGE_MEDIUM+8
	penetrating = 0
// PPSH SMG //
/obj/item/projectile/bullet/rifle/a556
	damage = DAMAGE_LOW - 2
	penetrating = 1

/obj/item/projectile/bullet/rifle/a9x39
	damage = DAMAGE_LOW
	penetrating = 3
//	step_delay = 2

// DP MACHINE GUN //
/obj/item/projectile/bullet/rifle/a762x39
	damage = DAMAGE_MEDIUM + 4
	penetrating = 2

/obj/item/projectile/bullet/rifle/a762x51
	damage = DAMAGE_LOW
	penetrating = 3

// M1991 .45 VINTAGE PISTOL //
/obj/item/projectile/bullet/rifle/c45cal
	damage = DAMAGE_MEDIUM+8
	penetrating = 0

/obj/item/projectile/bullet/rifle/a127x108
	damage = DAMAGE_LOW
	penetrating = 3

/obj/item/projectile/bullet/rifle/a556x45
	damage = DAMAGE_VERY_HIGH
	penetrating = 3

// TT-30 TOKAREV PISTOL //
/obj/item/projectile/bullet/rifle/c762mm_tokarev
	damage = DAMAGE_MEDIUM
	penetrating = 0

// C96 MAUSER PISTOL //
/obj/item/projectile/bullet/rifle/c763x25mm_mauser
	damage = DAMAGE_MEDIUM
	penetrating = 0

// STEN MK3 SMG //
/obj/item/projectile/bullet/rifle/c9x19mm_stenmk3
	damage = DAMAGE_LOW-5
	penetrating = 0

// NAGANT REVOLVER //
/obj/item/projectile/bullet/rifle/c762x38mmR
	damage = DAMAGE_MEDIUM+6
	penetrating = 0

// PPS SMG //
/obj/item/projectile/bullet/rifle/c762x25mm_pps
	damage = DAMAGE_LOW-5
	penetrating = 0

// GEWEHR 41 //
///obj/item/projectile/bullet/rifle/a792x57_g41
	//damage = DAMAGE_HIGH - 5
	//penetrating = 2
	//armor_penetration = 50

// FG 42 //
/obj/item/projectile/bullet/rifle/c792x57_fg42
	damage = DAMAGE_MEDIUM_HIGH + 2
	penetrating = 2
	armor_penetration = 60

// CARCANO M1891 //
/obj/item/projectile/bullet/rifle/c65x52mm
	damage = DAMAGE_HIGH
	penetrating = 2
	armor_penetration = 100

// WALTHER P38 //
/obj/item/projectile/bullet/rifle/p9x19mm
	damage = DAMAGE_MEDIUM+5
	penetrating = 0

// Nambu, pistol //
/obj/item/projectile/bullet/rifle/c8mmnambu
	damage = DAMAGE_MEDIUM+2
	penetrating = 0

// Nambu, smg //
/obj/item/projectile/bullet/rifle/c8mmnambu_smg
	damage = DAMAGE_LOW
	penetrating = 0

// MODELLO 38 //
/obj/item/projectile/bullet/rifle/s9x19mm
	damage = DAMAGE_LOW
	penetrating = 0

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
	damage = DAMAGE_HIGH + 6
	penetrating = 3
	armor_penetration = 100

#undef DAMAGE_LOW
#undef DAMAGE_MEDIUM
#undef DAMAGE_HIGH
#undef DAMAGE_VERY_HIGH
#undef DAMAGE_OH_GOD

/obj/item/projectile/bullet/chameleon
	damage = TRUE // stop trying to murderbone with a fake gun dumbass!!!
	embed = FALSE // nope

// missiles

/obj/item/projectile/bullet/rifle/missile/yuge
	name = "huge HE missle"
	explosion_ranges = list(1,2,3,4)

/obj/item/projectile/bullet/rifle/missile/yuge/lessyuge
	explosion_ranges = list(1,1,3,4)

/obj/item/projectile/bullet/rifle/missile/tank
	name = "tank missle"
	explosion_ranges = list(1,3,4,5)

/obj/item/projectile/bullet/rifle/missile/he
	name = "HE missle"
	explosion_ranges = list(1,2,3,4)

/obj/item/projectile/grenade/he
	name = "he grenade"

	kill_count = 10

	on_hit(atom/hit_atom)
		explosion(hit_atom, FALSE, FALSE, 2, 6)
		qdel(src)

	on_impact(atom/hit_atom)
		on_hit(hit_atom)

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


/////////////////////FLAREGUNS//////////////////////////////////////////
////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////

// Pillar men

/obj/burning_blood
	name = "burning giblets"
	icon = 'icons/obj/projectiles.dmi'
	icon_state = "gibshot"
	layer = MOB_LAYER + 0.1
	density = 1

/obj/burning_blood/New()
	..()
	playsound(get_turf(src), 'sound/effects/gore/severed.ogg', 100)

/obj/burning_blood/throw_impact(var/atom/movable/obstacle)
	if (isliving(obstacle))
		var/mob/living/L = obstacle
		L.adjustFireLoss(rand(30,40))
		L.Weaken(rand(2,3))
		visible_message("<span class = 'warning'>[L] is scalded by burning blood!</span>")
		if (ishuman(L))
			L.emote("scream")
		playsound(get_turf(L), 'sound/effects/gore/fallsmash.ogg', 100)
		. = TRUE
	. = FALSE
	qdel(src)
	return .

