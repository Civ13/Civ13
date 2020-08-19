/obj/item/blueprint
	name = "blueprint"
	desc = "A technical blueprint."
	icon_state = "blueprints"
	icon = 'icons/obj/items.dmi'
	flammable = TRUE

/obj/item/blueprint/gun
	var/stock_type = "none"
	var/receiver_type = "none"
	var/feeding_type = "none"
	var/barrel_type = "none"
	var/custom_name = "gun"
	var/override_sprite = null
	var/override_icon = 'icons/obj/guns/gun.dmi'
	var/caliber = ""
	var/ammo_type = null

	var/cost_wood = 0
	var/cost_steel = 0
