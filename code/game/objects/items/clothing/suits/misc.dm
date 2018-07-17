//Chef
/obj/item/clothing/suit/chef
	name = "chef's apron"
	desc = "An apron used by a high class chef."
	icon_state = "chef"
	item_state = "chef"
	gas_transfer_coefficient = 0.90
	permeability_coefficient = 0.50
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|ARMS
	allowed = list(/obj/item/weapon/material/knife, /obj/item/radio/rbs,/obj/item/radio/feldfu,/obj/item/radio/partisan)

//Chef
/obj/item/clothing/suit/chef/classic
	name = "A classic chef's apron."
	desc = "A basic, dull, white chef's apron."
	icon_state = "apronchef"
	item_state = "apronchef"
	blood_overlay_type = "armor"
	body_parts_covered = FALSE

/*

//Detective
/obj/item/clothing/suit/storage/insp_trench
	name = "Inspector's armored trenchcoat"
	desc = "Brown and armored trenchcoat, designed and created by Ironhammer Security. The coat is externally impact resistant - perfect for your next act of autodefenestration!"
	icon_state = "insp_coat"
	item_state = "insp_coat"
	blood_overlay_type = "coat"
	body_parts_covered = UPPER_TORSO|ARMS
	allowed = list(/obj/item/weapon/tank/emergency_oxygen, /obj/item/flashlight,/obj/item/weapon/gun/energy,/obj/item/weapon/gun/projectile,/obj/item/ammo_magazine,/obj/item/ammo_casing,/*/obj/item/weapon/melee/baton,*//obj/item/weapon/handcuffs,/obj/item/weapon/storage/fancy/cigarettes,/obj/item/weapon/flame/lighter)
	armor = list(melee = 50, bullet = 10, laser = 25, energy = 10, bomb = FALSE, bio = FALSE, rad = FALSE)
*/
/obj/item/clothing/suit/storage/det_trench
	name = "brown trenchcoat"
	desc = "A rugged canvas trenchcoat, designed and created by TX Fabrication Corp. The coat is externally impact resistant - perfect for your next act of autodefenestration!"
	icon_state = "detective"
	item_state = "det_suit"
	blood_overlay_type = "coat"
	body_parts_covered = UPPER_TORSO|ARMS
	allowed = list(/obj/item/weapon/tank/emergency_oxygen, /obj/item/flashlight,/*/obj/item/weapon/gun/energy,*//obj/item/weapon/gun/projectile,/obj/item/ammo_magazine,/obj/item/ammo_casing,/*/obj/item/weapon/melee/baton,*//obj/item/weapon/handcuffs,/obj/item/weapon/storage/fancy/cigarettes,/obj/item/weapon/flame/lighter)
	armor = list(melee = 50, bullet = 10, laser = 25, energy = 10, bomb = FALSE, bio = FALSE, rad = FALSE)

/obj/item/clothing/suit/storage/det_trench/grey
	name = "grey trenchcoat"
	icon_state = "detective2"

//Engineering
/obj/item/clothing/suit/storage/hazardvest
	name = "hazard vest"
	desc = "A high-visibility vest used in work zones."
	icon_state = "hazard"
	item_state = "hazard"
	blood_overlay_type = "armor"
	allowed = list (/obj/item/flashlight, /*/obj/item/multitool,*/ /obj/item/radio, \
	/obj/item/weapon/crowbar, /obj/item/weapon/screwdriver, /obj/item/weapon/weldingtool, /obj/item/weapon/wirecutters, /obj/item/weapon/wrench, /obj/item/weapon/tank/emergency_oxygen, \
	/obj/item/clothing/mask/gas)
	body_parts_covered = UPPER_TORSO

/obj/item/clothing/suit/storage/civjacket
	name = "blue jacket"
	desc = "Jacket with specks of dust."
	icon_state = "civjacket"
	item_state = "civjacket"
	blood_overlay_type = "armor"
	body_parts_covered = UPPER_TORSO|ARMS
	allowed = list(/obj/item/weapon/material/knife, /obj/item/radio/rbs,/obj/item/radio/feldfu,/obj/item/radio/partisan)