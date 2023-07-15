/obj/item/blueprint
	name = "blueprint"
	desc = "A technical blueprint."
	icon_state = "blueprints"
	icon = 'icons/obj/items.dmi'
	flammable = TRUE

/obj/item/blueprint/gun
	var/custom_name = "gun"

	var/stock_type = "none"
	var/receiver_type = "none"
	var/feeding_type = "none"
	var/barrel_type = "none"
	
	var/base_icon = "none"
	var/override_sprite = null
	var/override_icon = 'icons/obj/guns/gun.dmi'
	var/caliber = ""
	var/ammo_type = list()

	var/cost_wood = 0
	var/cost_steel = 0

/obj/item/blueprint/gun/arisaka
	name = "Arisaka Type 99 Blueprint"
	custom_name = "Arisaka Type 99"
	desc = "A blueprint for a Japanese bolt-action rifle chambered in 7.7x58mm Arisaka ammunition."

	stock_type = "Rifle Wooden Stock"
	receiver_type = "Bolt-Action"
	feeding_type = "Internal Magazine"
	barrel_type = "Long Rifle Barrel"
	
	base_icon = "arisaka99"
	override_sprite = "arisaka99"
	override_icon = 'icons/obj/guns/gun.dmi'
	caliber = "a77x58"
	ammo_type = list(/obj/item/ammo_casing/a77x58)

	cost_wood = 10
	cost_steel = 15

/obj/item/blueprint/gun/m4
	name = "M4 Carbine Blueprint"
	custom_name = "M4 Carbine"
	desc = "A blueprint for a carbine version of the AR-15/M16 chambered in 5.56x45mm."

	stock_type = "Steel Stock"
	receiver_type = "Dual Selective Fire"
	feeding_type = "External Magazine"
	barrel_type = "Carbine Barrel"
	
	base_icon = "m4"
	override_sprite = "m4"
	override_icon = 'icons/obj/guns/assault_rifles.dmi'
	caliber = "a556x45"
	ammo_type = list(/obj/item/ammo_casing/a556x45)

	cost_wood = 5
	cost_steel = 25

/obj/item/blueprint/gun/ak103
	name = "AK-103 Blueprint"
	custom_name = "AK-103"
	desc = "A blueprint for a modern Russian AK variant chambered in 7.62x39mm."

	stock_type = "Steel Stock"
	receiver_type = "Dual Selective Fire"
	feeding_type = "External Magazine"
	barrel_type = "Carbine Barrel"
	
	base_icon = "ak101"
	override_sprite = "ak101"
	override_icon = 'icons/obj/guns/assault_rifles.dmi'
	caliber = "a762x39"
	ammo_type = list(/obj/item/ammo_casing/a762x39)

	cost_wood = 10
	cost_steel = 20