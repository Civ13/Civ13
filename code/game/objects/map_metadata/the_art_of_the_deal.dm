/obj/map_metadata/art_of_the_deal
	ID = MAP_THE_ART_OF_THE_DEAL
	title = "The Art of the Deal"
	lobby_icon_state = "civ13"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall)
	respawn_delay = 0
	is_singlefaction = TRUE
	battleroyale = TRUE

	no_winner ="The fighting is still going."

	faction_organization = list(
		CIVILIAN)

	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/british/ship, //it isnt in the map so nobody wins by capture
		)
	age = "2013"
	ordinal_age = 8
	var/fac_nr = 3
	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = "the deal"
	mission_start_message = "<font size=4><b>3</b> corporations <b>Last standing player wins!</b></font>"
	var/winner_name = "Unknown"
	var/list/winner_ckeys = list()
	faction1 = CIVILIAN
	faction2 = CIVILIAN
	gamemode = "Battleroyale"
	required_players = 6

/obj/map_metadata/art_of_the_deal/New()
	..()
	var/newnamea = list("Red Corporation" = list(230,230,230,null,0,"sun","#7F0000","#7F7F7F",0,0))
	var/newnameb = list("Blue Syndicate" = list(230,230,230,null,0,"sun","#00007F","#7F7F7F",0,0))
	var/newnamec = list("Green Enterprises" = list(230,230,230,null,0,"sun","#007F00","#7F7F7F",0,0))
	var/newnamed = list("Yellow Conglomerate" = list(230,230,230,null,0,"sun","#E5E500","#7F7F7F",0,0))
	custom_civs += newnamea
	custom_civs += newnameb
	custom_civs += newnamec
	custom_civs += newnamed
/obj/map_metadata/art_of_the_deal/job_enabled_specialcheck(var/datum/job/J)
	if (J.is_deal)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/art_of_the_deal/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 1800 || admin_ended_all_grace_periods)

/obj/map_metadata/art_of_the_deal/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 1800 || admin_ended_all_grace_periods)

/obj/map_metadata/art_of_the_deal/cross_message(faction)
	if (faction == CIVILIAN)
		return "<font size = 4><b>The round has started!</b> Players may now cross the invisible wall!</font>"

/obj/structure/vending/business_apparel
	name = "equipment rack"
	desc = "All the equipment you need for that special business meeting."
	icon_state = "apparel_german2"
	products = list(
		/obj/item/stack/medical/bruise_pack/gauze = 10,
		/obj/item/clothing/accessory/armor/nomads/civiliankevlar = 4,
		/obj/item/clothing/accessory/storage/webbing/pouches = 10,
		/obj/item/clothing/accessory/holster/armpit = 10,
		/obj/item/clothing/accessory/holster/chest = 10,
		/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars = 10,
		/obj/item/clothing/glasses/sunglasses = 10,
		/obj/item/clothing/glasses/nvg = 2,
		/obj/item/clothing/gloves/fingerless = 10,
		/obj/item/clothing/mask/balaclava = 10,
		/obj/item/clothing/head/ghillie = 1,
		/obj/item/clothing/suit/storage/ghillie = 1,

//		/obj/item/clothing/suit/storage/jacket/charcoal_suit = 10,
//		/obj/item/clothing/suit/storage/jacket/black_suit = 10,
//		/obj/item/clothing/suit/storage/jacket/navy_suit = 10,
//		/obj/item/clothing/suit/storage/jacket/burgundy_suit = 10,
//		/obj/item/clothing/suit/storage/jacket/checkered_suit = 10,
	)

/obj/structure/vending/business_weapons
	name = "weapon and ammo rack"
	desc = "When you need to pack that extra punch."
	icon_state = "weapons_sof"
	products = list(
		/obj/item/weapon/gun/projectile/pistol/colthammerless = 3,
		/obj/item/weapon/gun/projectile/pistol/colthammerless/m1908 = 3,
		/obj/item/weapon/gun/projectile/pistol/m1911 = 2,
		/obj/item/weapon/gun/projectile/revolver/smithwesson = 3,
		/obj/item/weapon/gun/projectile/shotgun/remington870 = 1,
		/obj/item/weapon/gun/projectile/boltaction/m24 = 1,

		/obj/item/weapon/plastique/c4 = 2,
		/obj/item/ammo_magazine/colthammerless = 10,
		/obj/item/ammo_magazine/colthammerless/a380acp = 10,
		/obj/item/ammo_magazine/m1911 = 5,
		/obj/item/ammo_magazine/c32 = 10,
		/obj/item/ammo_magazine/shellbox = 1,
		/obj/item/ammo_magazine/shellbox/slug = 1,
		/obj/item/ammo_magazine/m24 = 3,
	)

/obj/item/weapon/disk
	name = "diskette"
	desc = "Some kind of diskette."
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "disk_red"
	item_state = "disk_red"
	flammable = FALSE
	density = FALSE
	opacity = FALSE
	force = 4.0
	throwforce = 3.0

	attack_verb = list("bashed", "bludgeoned", "whacked")
	sharp = FALSE
	edge = FALSE
	w_class = 1.0

/obj/item/weapon/disk/red
	name = "red diskette"
	icon_state = "disk_red"
	item_state = "disk_red"

/obj/item/weapon/disk/blue
	name = "blue diskette"
	icon_state = "disk_blue"
	item_state = "disk_blue"

/obj/item/weapon/disk/yellow
	name = "yellow diskette"
	icon_state = "disk_yellow"
	item_state = "disk_yellow"

/obj/item/weapon/disk/green
	name = "green diskette"
	icon_state = "disk_green"
	item_state = "disk_green"

/obj/item/weapon/package
	name = "package"
	desc = "Some kind of package."
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "deliverypackage"
	item_state = "deliverypackage"
	flammable = FALSE
	density = FALSE
	opacity = FALSE
	force = 9.0
	throwforce = 10.0

	attack_verb = list("bashed", "bludgeoned", "whacked")
	sharp = FALSE
	edge = FALSE
	w_class = 3.0