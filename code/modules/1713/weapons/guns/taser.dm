/obj/item/weapon/gun/projectile/pistol/taser
	name = "taser pistol"
	desc = "A type of electroshock weapon that uses electrical current to disrupt muscle control and temporarily incapacitate a person."
	icon = 'icons/obj/guns/wip.dmi'
	icon_state = "taser_new"
	item_state = "taser_new"
	var/base_icon = "taser"
	fire_sound = 'sound/weapons/taser.ogg' //To be changed to taser.ogg when imported
	w_class = ITEM_SIZE_NORMAL
	load_method = MAGAZINE
	max_shells = 5
	caliber = "taser"
	ammo_type = /obj/item/ammo_casing/taser
	damage_modifier = 1.2
	slot_flags = SLOT_SHOULDER | SLOT_BELT
	magazine_type = /obj/item/ammo_magazine/taser
	good_mags = list(/obj/item/ammo_magazine/taser)
	weight = 3.85
	firemodes = list(
		list(name = "single shot",burst=1, move_delay=0, fire_delay=20)
		)
	gun_type = GUN_TYPE_PISTOL
	force = 10
	throwforce = 20
	effectiveness_mod = 1
	attachment_slots = null
	handle_casings = REMOVE_CASINGS

/obj/item/weapon/gun/projectile/pistol/taser/update_icon()
	if (!ammo_magazine)
		icon_state = "[base_icon]_empty"
	else
		if (ammo_magazine.contents.len > 0)
			icon_state = "[base_icon][ammo_magazine.contents.len]"
		else
			icon_state = "[base_icon]0"
	update_held_icon()
	return

/obj/item/projectile/taser
	name = "taser dart"
	icon_state = "dart"
	taser_effect = TRUE
	damage = 2
	damage_type = STUN
	nodamage = FALSE
	agony = 40
	stun = 40
	check_armor = "energy"
	embed = FALSE
	sharp = FALSE
	penetrating = 0
	kill_count = 5

	muzzle_type = null

/obj/item/ammo_casing/taser
	name = "taser dart"
	desc = "A small projectile that delivers an electrical shock to the target. "
	caliber = "taser"
	icon_state = "bdart"
	spent_icon = "bdart"
	projectile_type = /obj/item/projectile/taser
	leaves_residue = FALSE

/obj/item/ammo_magazine/taser
	name = "taser cartridge"
	icon_state = "taser"
	caliber = "taser"
	ammo_type = /obj/item/ammo_casing/taser
	max_ammo = 5
	weight = 0.01
	mag_type = MAGAZINE
	multiple_sprites = FALSE
	clip = FALSE
