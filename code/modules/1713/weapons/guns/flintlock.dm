//All the flintlock weapons

/obj/item/weapon/gun/projectile/flintlock
	name = "flintlock musket"
	desc = "A simple flintlock musket of the early XVIII century."
	icon = 'icons/obj/guns/ancient.dmi'
	icon_state = "musket"
	item_state = "musket"
	w_class = ITEM_SIZE_LARGE
	throw_range = 4
	throw_speed = 2
	force = 10
	throwforce = 10
	max_shells = 1 //duh
	slot_flags = SLOT_SHOULDER
	caliber = "musketball"
	shake_strength = 3 //extra kickback
	handle_casings = REMOVE_CASINGS
	load_method = SINGLE_CASING
	ammo_type = /obj/item/ammo_casing/musketball
	load_shell_sound = 'sound/weapons/guns/interact/clip_reload.ogg'
	fire_sound = 'sound/weapons/guns/fire/musket.ogg'
	//+2 accuracy over the LWAP because only one shot
//	scoped_accuracy = 2
	gun_type = GUN_TYPE_RIFLE
	attachment_slots = ATTACH_IRONSIGHTS|ATTACH_BARREL
	accuracy_increase_mod = 2.00
	accuracy_decrease_mod = 6.00
	KD_chance = KD_CHANCE_HIGH
	stat = "rifle"
	gtype = "rifle"
	move_delay = 5
	fire_delay = 5
	equiptimer = 20
	maxhealth = 20
	accuracy = 5

	load_delay = 110 //11 seconds for rifles, 8 seconds for pistols & blunderbuss
	aim_miss_chance_divider = 3.00

	var/cocked = FALSE
	var/check_cocked = FALSE //Keeps the bolt from being interfered with
	var/jammed_until = -1
	var/jamcheck = 0
	var/last_fire = -1

/obj/item/weapon/gun/projectile/flintlock/attack_self(mob/user)
//	var/mob/living/human/H = user
	if (!check_cocked)//Keeps people from spamming the bolt
		check_cocked++
		if (!do_after(user, 2, src, FALSE, TRUE, INCAPACITATION_DEFAULT, TRUE))//Delays the bolt
			check_cocked--
			return
	else return
	if (!cocked)
		playsound(loc, 'sound/weapons/guns/interact/bolt_open.ogg', 50, TRUE)
		user << "<span class='notice'>You cock the [src]!</span>"
		cocked = TRUE
	else
		playsound(loc, 'sound/weapons/guns/interact/bolt_close.ogg', 50, TRUE)
		user << "<span class='notice'>You uncock the [src].</span>"
		cocked = FALSE
	add_fingerprint(user)
	update_icon()
	check_cocked--

/obj/item/weapon/gun/projectile/flintlock/special_check(mob/user)
//	var/mob/living/human/H = user
	if (!cocked)
		user << "<span class='warning'>You can't fire \the [src] while the weapon is uncocked!</span>"
		return FALSE
	if (!(user.has_empty_hand(both = FALSE)) && !istype(src, /obj/item/weapon/gun/projectile/flintlock/pistol) && !istype(src, /obj/item/weapon/gun/projectile/flintlock/blunderbuss/pistol) && !istype(src, /obj/item/weapon/gun/projectile/flintlock/pistoletmodelean1733) && !istype(src, /obj/item/weapon/gun/projectile/flintlock/duellingpistol) && !istype(src, /obj/item/weapon/gun/projectile/flintlock/pistoletmodeleanxiii))
		user << "<span class='warning'>You need both hands to fire \the [src]!</span>"
		return FALSE
	return ..()

/obj/item/weapon/gun/projectile/flintlock/load_ammo(var/obj/item/A, mob/user)
//	var/mob/living/human/H = user
	if (cocked)
		return
	..()

/obj/item/weapon/gun/projectile/flintlock/unload_ammo(mob/user, var/allow_dump=1)
	return
	// you cant, sorry
	..()

/obj/item/weapon/gun/projectile/flintlock/handle_post_fire()
	..()
	if (max_shells == 1)
		loaded = list()
		chambered = null
	cocked = FALSE
	spawn (1)
		new/obj/effect/effect/smoke/chem(get_step(src, dir))
	spawn (5)
		new/obj/effect/effect/smoke/chem(get_step(src, dir))
	spawn (12)
		new/obj/effect/effect/smoke/chem(get_step(src, dir))

/obj/item/weapon/gun/projectile/flintlock/musket
	name = "flintlock musket"
	desc = "A simple flintlock musket of the early XVIII century."
	force = 12
	caliber = "musketball"
	weight = 6.0
	ammo_type = /obj/item/ammo_casing/musketball
	value = 100
	accuracy = 4

/obj/item/weapon/gun/projectile/flintlock/m1752
	name = "M1752 mosquete"
	desc = "A simple spanish musket of the early XVIII century."
	force = 11.5
	caliber = "musketball"
	weight = 6.0
	ammo_type = /obj/item/ammo_casing/musketball
	value = 100
	item_state = "musket"
	icon_state = "mosquete1752"
	accuracy = 4

/obj/item/weapon/gun/projectile/flintlock/jezail
	name = "Jezail musket"
	desc = "A very simple Arabic musket of the early XVIII century."
	force = 10
	caliber = "musketball"
	weight = 5.0
	ammo_type = /obj/item/ammo_casing/musketball
	value = 100
	item_state = "musket"
	icon_state = "jezail"
	accuracy = 4

/obj/item/weapon/gun/projectile/flintlock/kabyle
	name = "Kabyle musket"
	desc = "A very simple North-African musket of the early XVIII century."
	force = 10.2
	caliber = "musketball"
	weight = 4.7
	ammo_type = /obj/item/ammo_casing/musketball
	value = 100
	item_state = "musket"
	icon_state = "moukalla"
	accuracy = 4

/obj/item/weapon/gun/projectile/flintlock/brownbess
	name = "Brownbess musket"
	desc = "A simple english musket of the early XVIII century."
	force = 11
	caliber = "musketball"
	weight = 5.9
	ammo_type = /obj/item/ammo_casing/musketball
	value = 100
	item_state = "musket"
	icon_state = "brownbess"
	accuracy = 4

/obj/item/weapon/gun/projectile/flintlock/charleville
	name = "Charleville mousquet"
	desc = "A simple french musket of the early XVIII century."
	force = 11.3
	caliber = "musketball"
	weight = 5.6
	ammo_type = /obj/item/ammo_casing/musketball
	value = 100
	item_state = "musket"
	icon_state = "charleville_mousquet"
	accuracy = 4

/obj/item/weapon/gun/projectile/flintlock/plexico
	name = "flintlock musket"
	desc = "A finer flintlock musket, this one seems to be made out of ebony and steel."
	force = 12
	caliber = "musketball"
	weight = 6.0
	ammo_type = /obj/item/ammo_casing/musketball
	value = 110
	item_state = "plexciomusket"
	icon_state = "plexciomusket"
	accuracy = 1

/obj/item/weapon/gun/projectile/flintlock/springfield
	name = "Springfield M1861 Musket"
	desc = "A simple flintlock musket of the 1860's used commonly in the civil war."
	force = 12
	caliber = "musketball"
	weight = 6.0
	ammo_type = /obj/item/ammo_casing/musketball
	value = 100
	item_state = "springfield"
	icon_state = "springfield"
	load_delay = 70
	accuracy = 4

/obj/item/weapon/gun/projectile/flintlock/springfield1795
	name = "Springfield 1795 Musket"
	desc = "The Model 1795 was the first musket to be produced in the United States."
	force = 12
	caliber = "musketball"
	weight = 5.0
	ammo_type = /obj/item/ammo_casing/musketball
	value = 100
	item_state = "springfield"
	icon_state = "springfield1795"
	load_delay = 80
	accuracy = 1

/obj/item/weapon/gun/projectile/flintlock/musketoon
	name = "flintlock musketoon"
	desc = "A smaller version of the flintlock musket, this gun is favored by seamen due to being compact, albeit less accurate."
	icon_state = "compactmusket"
	item_state = "musketoon"
	force = 8
	caliber = "musketball"
	weight = 4.0
	ammo_type = /obj/item/ammo_casing/musketball
	value = 80
	equiptimer = 12
	accuracy = 5

/obj/item/weapon/gun/projectile/flintlock/crude
	name = "crude musket"
	desc = "A crude, homemade version of a musket. Not very reliable and accurate."
	icon_state = "crude"
	item_state = "musketoon"
	force = 8
	caliber = "musketball"
	weight = 4.0
	ammo_type = /obj/item/ammo_casing/musketball
	value = 45
	accuracy = 5

/obj/item/weapon/gun/projectile/flintlock/pistol
	// less accurate than rifles against still targets, but better against moving targets
	// less accurate than semiautos but with the same ratios
	name = "flintlock pistol"
	desc = "A typical flintlock pistol. Good for short ranges, useless otherwise."
	icon_state = "flintpistol"
	item_state = "pistol"
	shake_strength = 2
	force = 6
	w_class = ITEM_SIZE_SMALL
	fire_sound = 'sound/weapons/guns/fire/hpistol.ogg'
	caliber = "musketball_pistol"
	weight = 2.5
	attachment_slots = ATTACH_IRONSIGHTS
	ammo_type = /obj/item/ammo_casing/musketball_pistol
	move_delay = 3
	fire_delay = 3
	load_delay = 80
	value = 70
	stat = "pistol"
	gtype = "pistol"
	equiptimer = 7
	gun_type = GUN_TYPE_PISTOL
	accuracy_increase_mod = 1.50
	accuracy_decrease_mod = 2.00
	KD_chance = KD_CHANCE_LOW
	stat = "pistol"
	aim_miss_chance_divider = 2.00
	accuracy = 4

/obj/item/weapon/gun/projectile/flintlock/blunderbuss
	stat = "heavy"
	name = "Blunderbuss"
	desc = "A enlarged version of the musketoon, it can fire bigger bullets. Useless at long range."
	icon_state = "blunderbuss"
	item_state = "blunderbuss"
	shake_strength = 4
	force = 14
	load_delay = 100
	caliber = "blunderbuss"
	stat = "rifle"
	weight = 4.5
	value = 80
	attachment_slots = ATTACH_IRONSIGHTS
	ammo_type = /obj/item/ammo_casing/blunderbuss
	gun_type = GUN_TYPE_SHOTGUN
	fire_sound = 'sound/weapons/guns/fire/shotgun.ogg'
	equiptimer = 15
	// 15% more accurate than SMGs
	accuracy = 5

	accuracy_increase_mod = 1.05
	accuracy_decrease_mod = 1.10
	KD_chance = KD_CHANCE_HIGH

/obj/item/weapon/gun/projectile/flintlock/pistoletmodelean1733
	name = "Pistolet modèle An 1733"
	desc = "A typical French pistol. Used by Calvary units."
	icon_state = "pistolet_modele1733"
	item_state = "pistol"
	shake_strength = 2.1
	force = 6.1
	w_class = ITEM_SIZE_SMALL
	fire_sound = 'sound/weapons/guns/fire/hpistol.ogg'
	caliber = "musketball_pistol"
	weight = 2.5
	attachment_slots = ATTACH_IRONSIGHTS
	ammo_type = /obj/item/ammo_casing/musketball_pistol
	move_delay = 3
	fire_delay = 3
	load_delay = 80
	value = 70
	stat = "pistol"
	gtype = "pistol"
	gun_type = GUN_TYPE_PISTOL
	equiptimer = 7
	accuracy_increase_mod = 1.40
	accuracy_decrease_mod = 2.00
	KD_chance = KD_CHANCE_LOW
	stat = "pistol"
	aim_miss_chance_divider = 1.70
	accuracy = 10
	accuracy = 4

/obj/item/weapon/gun/projectile/flintlock/duellingpistol
	name = "Duelling Flintlock "
	desc = "A typical Duelling Pistol. Used by gentlemen who take part in duels."
	icon_state = "flintlock_duelingpistol"
	item_state = "pistol"
	shake_strength = 2.5
	force = 8
	w_class = ITEM_SIZE_SMALL
	fire_sound = 'sound/weapons/guns/fire/hpistol.ogg'
	caliber = "musketball_pistol"
	weight = 2.9
	attachment_slots = ATTACH_IRONSIGHTS
	ammo_type = /obj/item/ammo_casing/musketball_pistol
	move_delay = 3.4
	fire_delay = 3.1
	load_delay = 75
	value = 70
	stat = "pistol"
	gtype = "pistol"
	gun_type = GUN_TYPE_PISTOL
	equiptimer = 7
	accuracy = 3

/obj/item/weapon/gun/projectile/flintlock/pistoletmodeleanxiii
	name = "Pistolet modèle An XIII"
	desc = "A typical French pistol. Used by Calvary units."
	icon_state = "pistolet_modele13"
	item_state = "pistol"
	shake_strength = 2.1
	force = 6.1
	w_class = ITEM_SIZE_SMALL
	fire_sound = 'sound/weapons/guns/fire/hpistol.ogg'
	caliber = "musketball_pistol"
	weight = 2.5
	attachment_slots = ATTACH_IRONSIGHTS
	ammo_type = /obj/item/ammo_casing/musketball_pistol
	move_delay = 3
	fire_delay = 3
	load_delay = 80
	value = 70
	stat = "pistol"
	gtype = "pistol"
	gun_type = GUN_TYPE_PISTOL
	equiptimer = 7
	accuracy_increase_mod = 1.40
	accuracy_decrease_mod = 2.00
	KD_chance = KD_CHANCE_LOW
	stat = "pistol"
	aim_miss_chance_divider = 1.70
	accuracy = 4

/obj/item/weapon/gun/projectile/flintlock/blunderbuss/pistol
	stat = "heavy"
	name = "Blunderbuss Pistol"
	desc = "A enlarged version of the musketoon, it can fire bigger bullets. This one has been designed so it can be used with one hand. Useless at medium range."
	icon_state = "flintlock_blunderbusspistol"
	item_state = "pistol"
	shake_strength = 5
	force = 14
	load_delay = 110
	caliber = "blunderbuss"
	stat = "pistol"
	gtype = "pistol"
	gun_type = GUN_TYPE_PISTOL
	weight = 2.5
	w_class = ITEM_SIZE_SMALL
	value = 80
	attachment_slots = ATTACH_IRONSIGHTS
	ammo_type = /obj/item/ammo_casing/blunderbuss
	accuracy = 6