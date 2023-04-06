/obj/item/weapon/gun/projectile/semiautomatic
	maxhealth = 60
	fire_sound = 'sound/weapons/guns/fire/rifle.ogg'
	icon = 'icons/obj/guns/rifles.dmi'
	// pistol accuracy, rifle skill & decent KD chance
	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 63,
			SHORT_RANGE_MOVING = 38,

			MEDIUM_RANGE_STILL = 53,
			MEDIUM_RANGE_MOVING = 32,

			LONG_RANGE_STILL = 43,
			LONG_RANGE_MOVING = 25,

			VERY_LONG_RANGE_STILL = 33,
			VERY_LONG_RANGE_MOVING = 18),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 78,
			SHORT_RANGE_MOVING = 51,

			MEDIUM_RANGE_STILL = 68,
			MEDIUM_RANGE_MOVING = 45,

			LONG_RANGE_STILL = 58,
			LONG_RANGE_MOVING = 38,

			VERY_LONG_RANGE_STILL = 48,
			VERY_LONG_RANGE_MOVING = 32),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 83,
			SHORT_RANGE_MOVING = 55,

			MEDIUM_RANGE_STILL = 73,
			MEDIUM_RANGE_MOVING = 48,

			LONG_RANGE_STILL = 63,
			LONG_RANGE_MOVING = 42,

			VERY_LONG_RANGE_STILL = 53,
			VERY_LONG_RANGE_MOVING = 35),
	)

	accuracy_increase_mod = 2.00
	accuracy_decrease_mod = 6.00
	KD_chance = KD_CHANCE_MEDIUM
	stat = "rifle"
	load_delay = 5
	aim_miss_chance_divider = 2.50

	headshot_kill_chance = 35
	KO_chance = 30

	gtype = "rifle"

	var/jammed_until = -1
	var/jamcheck = 0
	var/last_fire = -1
	var/base_icon = "semiautomatic"
	equiptimer = 12
	gun_safety = TRUE
	reload_sound = 'sound/weapons/guns/interact/semiauto_magin.ogg'
	unload_sound = 'sound/weapons/guns/interact/semiauto_magout.ogg'

/obj/item/weapon/gun/projectile/semiautomatic/update_icon()
	if (sniper_scope)
		if (!ammo_magazine)
			icon_state = "[base_icon]_scope_open"
			return
		else
			icon_state = "[base_icon]_scope"
			return
	else
		if (ammo_magazine)
			icon_state = base_icon
			item_state = base_icon
		else
			icon_state = "[base_icon]_open"
			item_state = base_icon
	update_held_icon()
	return

/obj/item/weapon/gun/projectile/semiautomatic/special_check(mob/user)
	if (gun_safety && safetyon)
		user << "<span class='warning'>You can't fire \the [src] while the safety is on!</span>"
		return FALSE
	if (!user.has_empty_hand(both = FALSE))
		user << "<span class='warning'>You need both hands to fire \the [src]!</span>"
		return FALSE
	if (jammed_until > world.time)
		user << "<span class = 'danger'>\The [src] has jammed! You can't fire it until it has unjammed.</span>"
		return FALSE
	return TRUE

/obj/item/weapon/gun/projectile/semiautomatic/handle_post_fire()
	..()
	var/reverse_health_percentage = (1-(health/maxhealth)+0.25)*100
	if (world.time - last_fire > 50)
		jamcheck = 0
	else
		jamcheck += 0.4

	if (prob(jamcheck*reverse_health_percentage))
		jammed_until = max(world.time + (jamcheck * 4), 40)
		jamcheck = 0

	last_fire = world.time

/obj/item/weapon/gun/projectile/semiautomatic/svt
	name = "SVT-40"
	desc = "Soviet semi-automatic rifle chambered in 7.62x54mmR."
	icon_state = "svt"
	item_state = "svt"
	base_icon = "svt"
	w_class = ITEM_SIZE_LARGE
	load_method = SINGLE_CASING|SPEEDLOADER|MAGAZINE
	max_shells = 10
	caliber = "a762x54"
	ammo_type = /obj/item/ammo_casing/a762x54
	slot_flags = SLOT_SHOULDER
	magazine_type = /obj/item/ammo_magazine/svt
	good_mags = list(/obj/item/ammo_magazine/svt)
	weight = 3.85
	load_delay = 8
	firemodes = list(
		list(name = "single shot",burst=1, move_delay=2, fire_delay=6)
		)

	gun_type = GUN_TYPE_RIFLE
	force = 10
	throwforce = 20
	effectiveness_mod = 1.04
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL

/obj/item/weapon/gun/projectile/semiautomatic/avtomat
	name = "Fedorov Avtomat"
	desc = "Russian automatic rifle, used during WWI."
	icon_state = "avtomat"
	item_state = "svt"
	base_icon = "avtomat"
	w_class = ITEM_SIZE_LARGE
	load_method = SINGLE_CASING|SPEEDLOADER|MAGAZINE
	max_shells = 25
	caliber = "a65x50"
	ammo_type = /obj/item/ammo_casing/a65x50
	slot_flags = SLOT_SHOULDER
	magazine_type = /obj/item/ammo_magazine/avtomat
	good_mags = list(/obj/item/ammo_magazine/avtomat)
	weight = 3.85
	load_delay = 8
	firemodes = list(
		list(name = "single shot",	burst=1, burst_delay=0.8, recoil=0, move_delay=2, dispersion = list(0.1, 0.2, 0.1, 0.2, 0.3)),
		list(name = "full auto",	burst=1, burst_delay=1.1, recoil=0, move_delay=3, dispersion = list(1, 1.2, 1.3, 1.2, 1.3)),
		)

	gun_type = GUN_TYPE_RIFLE
	force = 10
	throwforce = 20
	effectiveness_mod = 1.08
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL

/obj/item/weapon/gun/projectile/semiautomatic/remington11
	name = "Remington 11"
	desc = "American semi-automatic shotgun."
	icon_state = "remington11"
	item_state = "remington11"
	base_icon = "remington11"
	w_class = ITEM_SIZE_LARGE
	load_method = SINGLE_CASING
	max_shells = 5
	caliber = "12gauge"
	ammo_type = /obj/item/ammo_casing/shotgun
	slot_flags = SLOT_SHOULDER
	weight = 3.85
	load_delay = 4

	gun_type = GUN_TYPE_RIFLE
	force = 10
	throwforce = 20
	effectiveness_mod = 1.80

/obj/item/weapon/gun/projectile/semiautomatic/sks
	name = "SKS"
	desc = "Soviet semi-automatic rifle chambered in 7.62x39mm."
	icon_state = "sks"
	item_state = "mosin"
	base_icon = "sks"
	fire_sound = 'sound/weapons/guns/fire/SKS.ogg'
	w_class = ITEM_SIZE_LARGE
	load_method = SINGLE_CASING|SPEEDLOADER
	max_shells = 10
	caliber = "a762x39"
	ammo_type = /obj/item/ammo_casing/a762x39
	damage_modifier = 1.2
	slot_flags = SLOT_SHOULDER
	magazine_type = /obj/item/ammo_magazine/sks
	good_mags = list(/obj/item/ammo_magazine/sks)
	weight = 3.85
	firemodes = list(
		list(name = "single shot",burst=1, move_delay=2, fire_delay=4)
		)

	gun_type = GUN_TYPE_RIFLE
	force = 10
	throwforce = 20
	effectiveness_mod = 1.05
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL

/obj/item/weapon/gun/projectile/semiautomatic/sks/chinese
	name = "Type 56 carbine"
	desc = "Chinese variant of the Soviet semi-automatic rifle chambered in 7.62x39mm."
	weight = 3.86

/obj/item/weapon/gun/projectile/semiautomatic/sks/sksm
	name = "SKS-M"
	desc = "Soviet semi-automatic rifle chambered in 7.62x39mm. This is the updated version based on the Type 63 that is compatible with AK-47 magazines."
	icon_state = "sksm"
	item_state = "sks"
	base_icon = "sksm"
	weight = 3.8
	effectiveness_mod = 1.06
	max_shells = 0
	magazine_type = /obj/item/ammo_magazine/sksm
	good_mags = list(/obj/item/ammo_magazine/sks, /obj/item/ammo_magazine/sksm, /obj/item/ammo_magazine/ak47)
	load_method = SINGLE_CASING|SPEEDLOADER|MAGAZINE
/obj/item/weapon/gun/projectile/semiautomatic/svd
	name = "SVD"
	desc = "Soviet designated marksman's rifle, feeding from detachable 10-round magazines. Chambered in 7.62x54mmR."
	icon_state = "svd"
	item_state = "svd"
	base_icon = "svd"
	w_class = ITEM_SIZE_LARGE
	load_method = SINGLE_CASING|SPEEDLOADER|MAGAZINE
	max_shells = 10
	caliber = "a762x54"
	ammo_type = /obj/item/ammo_casing/a762x54
	damage_modifier = 1.2
	fire_sound = 'sound/weapons/guns/fire/SVD.ogg'
	slot_flags = SLOT_SHOULDER
	magazine_type = /obj/item/ammo_magazine/svd
	good_mags = list(/obj/item/ammo_magazine/svd)
	weight = 3.85
	firemodes = list(
		list(name = "single shot",burst=1, move_delay=2, fire_delay=8)
		)

	gun_type = GUN_TYPE_RIFLE
	force = 10
	throwforce = 20
	effectiveness_mod = 1.03
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL

/obj/item/weapon/gun/projectile/semiautomatic/svd/New()
	..()
	var/obj/item/weapon/attachment/scope/adjustable/sniper_scope/SP = new/obj/item/weapon/attachment/scope/adjustable/sniper_scope(src)
	SP.attached(null,src,TRUE)

/obj/item/weapon/gun/projectile/semiautomatic/svd/acog/New()
	..()
	for(var/obj/item/weapon/attachment/scope/adjustable/sniper_scope/SC in attachments)
		attachments -= SC
		actions -= SC.actions
		verbs -= SC.verbs
		attachment_slots += SC.attachment_type
		accuracy = initial(accuracy)
		recoil = initial(recoil)
		qdel(SC)
	var/obj/item/weapon/attachment/scope/adjustable/advanced/acog/SP = new/obj/item/weapon/attachment/scope/adjustable/advanced/acog(src)
	SP.attached(null,src,TRUE)

/obj/item/weapon/gun/projectile/semiautomatic/g41
	name = "Gewehr 41"
	desc = "German semi-automatic rifle using 7.92x57mm Mauser ammunition in a 10 round non-detachable magazine."
	icon_state = "g41"
	item_state = "g41"
	base_icon = "g41"
	w_class = ITEM_SIZE_LARGE
	load_method = SINGLE_CASING|SPEEDLOADER
	max_shells = 10
	caliber = "a792x57"
	fire_sound = 'sound/weapons/guns/fire/Garand.ogg'
	slot_flags = SLOT_SHOULDER
	ammo_type = /obj/item/ammo_casing/a792x57
	magazine_type = /obj/item/ammo_magazine/gewehr98
	good_mags = list(/obj/item/ammo_magazine/gewehr98)
	weight = 4.9
	firemodes = list(
		list(name = "single shot",burst=1, move_delay=2, fire_delay=6)
		)
	force = 10
	throwforce = 20
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_BARREL
	effectiveness_mod = 1.05

/obj/item/weapon/gun/projectile/semiautomatic/g43
	name = "Gewehr 43"
	desc = "German semi-automatic rifle using 7.92x57mm Mauser ammunition in a 10 round detachable magazine."
	icon_state = "g43"
	item_state = "g43"
	base_icon = "g43"
	w_class = ITEM_SIZE_LARGE
	load_method = SINGLE_CASING|SPEEDLOADER|MAGAZINE
	max_shells = 10
	load_delay = 8
	caliber = "a792x57"
	fire_sound = 'sound/weapons/guns/fire/Garand.ogg'
	slot_flags = SLOT_SHOULDER
	ammo_type = /obj/item/ammo_casing/a792x57
	magazine_type = /obj/item/ammo_magazine/g43
	good_mags = list(/obj/item/ammo_magazine/g43, /obj/item/ammo_magazine/gewehr98)
	weight = 4.9
	firemodes = list(
		list(name = "single shot",burst=1, move_delay=2, fire_delay=6)
		)
	force = 10
	throwforce = 20
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL
	effectiveness_mod = 1.06

/obj/item/weapon/gun/projectile/semiautomatic/vg5
	name = "Volkssturmkarabiner 98"
	desc = "A very simple german semi automatic chambered in 7.92x33mm Kurz."
	icon_state = "vg5"
	item_state = "vg5"
	base_icon = "vg5"
	w_class = ITEM_SIZE_LARGE
	load_method = SINGLE_CASING|SPEEDLOADER|MAGAZINE
	max_shells = 30
	load_delay = 10
	caliber = "a792x33"
	fire_sound = 'sound/weapons/guns/fire/stg.ogg'
	reload_sound = 'sound/weapons/guns/interact/stg_reload.ogg'
	slot_flags = SLOT_SHOULDER
	ammo_type = /obj/item/ammo_casing/a792x33
	magazine_type = /obj/item/ammo_magazine/stg
	good_mags = list(/obj/item/ammo_magazine/stg, /obj/item/ammo_magazine/vgclip)
	weight = 4.6
	firemodes = list(
		list(name = "single shot",burst=1, move_delay=2, fire_delay=5)
		)
	force = 15
	throwforce = 20
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL
	effectiveness_mod = 0.94
	equiptimer = 16

/obj/item/weapon/gun/projectile/semiautomatic/m1garand
	name = "M1 Garand"
	desc = "An American semi-automatic rifle using .30-06 ammunition in a 8 round internal magazine."
	icon_state = "m1garand"
	item_state = "m1garand"
	base_icon = "m1garand"
	w_class = ITEM_SIZE_LARGE
	load_method = SINGLE_CASING|SPEEDLOADER
	max_shells = 8
	caliber = "a3006"
	fire_sound = 'sound/weapons/guns/fire/Garand.ogg'
	slot_flags = SLOT_SHOULDER
	ammo_type = /obj/item/ammo_casing/a3006
	magazine_type = /obj/item/ammo_magazine/garand
	good_mags = list(/obj/item/ammo_magazine/springfield,/obj/item/ammo_magazine/garand)
	reload_sound = 'sound/weapons/guns/interact/GarandLoad.ogg'
	unload_sound = 'sound/weapons/guns/interact/GarandUnload.ogg'
	weight = 4.3
	firemodes = list(
		list(name = "single shot",burst=1, move_delay=2, fire_delay=4)
		)
	force = 10
	throwforce = 20
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_BARREL
	effectiveness_mod = 0.95

/obj/item/weapon/gun/projectile/semiautomatic/m1garand/match //Match grade weapons are built to a higher standard than service grade weapons.
	name = "M1 Garand Match"
	desc = "An American semi-automatic rifle using .30-06 ammunition in a 8 round internal magazine, this one was made with better quality control."
	w_class = ITEM_SIZE_LARGE
	weight = 4.8
	force = 15
	throwforce = 25
	effectiveness_mod = 1.05

/obj/item/weapon/gun/projectile/semiautomatic/ar15
	name = "Bushmaster XM-15"
	desc = "A civilian semi-automatic rifle chambered in 5.56x45mm."
	icon = 'icons/obj/guns/assault_rifles.dmi'
	icon_state = "m4"
	item_state = "m4"
	base_icon = "m4"
	w_class = ITEM_SIZE_LARGE
	load_method = MAGAZINE
	load_delay = 5
	caliber = "a556x45"
	fire_sound = 'sound/weapons/guns/fire/M4A1.ogg'
	slot_flags = SLOT_SHOULDER
	ammo_type = /obj/item/ammo_casing/a556x45
	magazine_type = /obj/item/ammo_magazine/ar15
	good_mags = list(/obj/item/ammo_magazine/ar15)
	weight = 4.9
	firemodes = list(
		list(name = "single shot",burst=1, move_delay=2, fire_delay=6)
		)
	force = 10
	throwforce = 20
	attachment_slots = ATTACH_SCOPE|ATTACH_BARREL
	effectiveness_mod = 1.07

/obj/item/weapon/gun/projectile/semiautomatic/m1carbine
	name = "M1 Carbine"
	desc = "An American Light semi-automatic rifle using 7.62×33mm (Rimless.30 Carbine) ammunition in a external magazine."
	icon_state = "mcar"
	item_state = "mcar"
	base_icon = "mcar"
	w_class = ITEM_SIZE_LARGE
	load_method = MAGAZINE
	caliber = "a762x33"
	fire_sound = 'sound/weapons/guns/fire/Garand.ogg'
	slot_flags = SLOT_SHOULDER
	ammo_type = /obj/item/ammo_casing/a762x33
	magazine_type = /obj/item/ammo_magazine/m1carbine
	good_mags = list(/obj/item/ammo_magazine/m1carbine,/obj/item/ammo_magazine/m1carbine/big)
	reload_sound = 'sound/weapons/guns/interact/GarandLoad.ogg'
	weight = 3.9
	firemodes = list(
		list(name = "single shot",burst=1, move_delay=2, fire_delay=4)
		)
	force = 10
	throwforce = 20
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_BARREL
	effectiveness_mod = 0.98

/obj/item/weapon/gun/projectile/semiautomatic/vintorez
	name = "VSS Vintorez"
	desc = "Marksman rifle featuring an integral supressor originating from the Soviet Union. Feeding from detachable 10-round magazines. Chambered in 9x39mm."
	icon_state = "vintorez"
	item_state = "vintorez"
	base_icon = "vintorez"
	load_method = MAGAZINE
	caliber = "a9x39"
	ammo_type = /obj/item/ammo_casing/a9x39
	damage_modifier = 1.2
	w_class = ITEM_SIZE_LARGE
	fire_sound = 'sound/weapons/guns/fire/silenced_pistol.ogg'
	slot_flags = SLOT_SHOULDER
	magazine_type = /obj/item/ammo_magazine/vintorez
	good_mags = list(/obj/item/ammo_magazine/vintorez)
	weight = 1.90
	firemodes = list(
		list(name = "single shot",burst=1, move_delay=2, fire_delay=6)
		)
	gun_type = GUN_TYPE_RIFLE
	effectiveness_mod = 1.09
	equiptimer = 8
	attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL

/obj/item/weapon/gun/projectile/semiautomatic/vintorez/New()
	..()
	var/obj/item/weapon/attachment/scope/adjustable/sniper_scope/SP = new/obj/item/weapon/attachment/scope/adjustable/sniper_scope(src)
	SP.attached(null,src,TRUE)

/obj/item/weapon/gun/projectile/semiautomatic/barrett
	name = "Barrett M82"
	desc = "The Barrett M82 is a recoil-operated, semi-automatic anti-materiel rifle developed by the American company Barrett Firearms Manufacturing. Chambered in .50 BMG."
	icon_state = "m82"
	item_state = "m82"
	base_icon = "m82"
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_SCOPE
	w_class = ITEM_SIZE_HUGE
	KD_chance = KD_CHANCE_HIGH
	slot_flags = null
	caliber = "a50cal"
	load_method = MAGAZINE
	ammo_type = list (/obj/item/ammo_casing/a50cal, /obj/item/ammo_casing/a50cal_ap, /obj/item/ammo_casing/a50cal_he)
	fire_sound = 'sound/weapons/guns/fire/BarrettM99.ogg'
	reload_sound = 'sound/weapons/guns/interact/barrett_magin.ogg'
	unload_sound = 'sound/weapons/guns/interact/barrett_magout.ogg'
	magazine_type = /obj/item/ammo_magazine/barrett
	good_mags = list(/obj/item/ammo_magazine/barrett)
	weight = 14.8
	recoil = 3
	firemodes = list(
		list(name = "single shot",burst=1, move_delay=2, fire_delay=25)
		)
	gun_type = GUN_TYPE_RIFLE
	effectiveness_mod = 2.0
	equiptimer = 15
	accuracy_increase_mod = 2.0
	recoil = 2

/obj/item/weapon/gun/projectile/semiautomatic/barrett/sniper/New()
	..()
	var/obj/item/weapon/attachment/scope/adjustable/sniper_scope/SP = new/obj/item/weapon/attachment/scope/adjustable/sniper_scope(src)
	SP.attached(null,src,TRUE)

/obj/item/weapon/gun/projectile/semiautomatic/bamr
	name = "BAMR"
	desc = "An old blugoslavian semi-auto, anti-tank rifle chambered in 15x115. Due to smart engineering the recoil isn't as bad as it could be."
	icon_state = "bam"
	item_state = "bam"
	base_icon = "bam"
	attachment_slots = ATTACH_IRONSIGHTS
	w_class = ITEM_SIZE_HUGE
	force = 10
	throwforce = 5
	KD_chance = KD_CHANCE_HIGH
	slot_flags = null
	caliber = "a15115"
	weight = 9
	recoil = 2
	load_method = MAGAZINE
	ammo_type = list (/obj/item/ammo_casing/a15115, /obj/item/ammo_casing/a15115_ap, /obj/item/ammo_casing/a15115_aphe)
	magazine_type = /obj/item/ammo_magazine/bamr
	good_mags = list(/obj/item/ammo_magazine/bamr, /obj/item/ammo_magazine/bamr_aphe, /obj/item/ammo_magazine/bamr_ap)
	firemodes = list(
		list(name = "single shot",burst=1, move_delay=2, fire_delay=15)
		)
	reload_sound = 'sound/weapons/guns/interact/barrett_magin.ogg'
	unload_sound = 'sound/weapons/guns/interact/barrett_magout.ogg'
	fire_sound = 'sound/weapons/guns/fire/ptrd.ogg'
	accuracy_increase_mod = 2.00
	effectiveness_mod = 1.3
	move_delay = 3
	fire_delay = 5
	equiptimer = 12
	gun_safety = FALSE
	load_delay = 20
