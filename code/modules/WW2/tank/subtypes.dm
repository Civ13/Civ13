/obj/tank
	var/admin = FALSE
	var/truck = FALSE
	var/halftrack = FALSE

/obj/tank/german
	icon_state = "ger"
	name = "German Panzer"

/obj/tank/opelblitz //trucks are a subtype of tanks because they are basically the same except for the gun.
	icon_state = "opelblitz_truck"
	name = "Opel Blitz Truck"
	truck = TRUE
	movement_delay = 1.25
	slow_movement_delay = 1.25
	fast_movement_delay = 2.5 // reversed because trucks are faster on asphalt and slower on dirt/grass
	icon = 'icons/WW2/truck_v.dmi' // I don't know why but we start out southfacing
	horizontal_icon = 'icons/WW2/truck_h.dmi'
	vertical_icon = 'icons/WW2/truck_v.dmi'
	locked = TRUE
	truck_full = FALSE
	back_seat_1 = FALSE
	back_seat_2 = FALSE
	back_seat_3 = FALSE
	back_seat_4 = FALSE
	back_seat_5 = FALSE
	back_seat_6 = FALSE

/obj/tank/ambulance //trucks are a subtype of tanks because they are basically the same except for the gun.
	icon_state = "ambulance"
	name = "Red Cross Ambulance"
	truck = TRUE
	movement_delay = 1.25
	slow_movement_delay = 1.25
	fast_movement_delay = 2.5 // reversed because trucks are faster on asphalt and slower on dirt/grass
	icon = 'icons/WW2/truck_v.dmi' // I don't know why but we start out southfacing
	horizontal_icon = 'icons/WW2/truck_h.dmi'
	vertical_icon = 'icons/WW2/truck_v.dmi'
	locked = FALSE
	truck_full = FALSE
	back_seat_1 = FALSE
	back_seat_2 = FALSE
	back_seat_3 = FALSE
	back_seat_4 = FALSE
	back_seat_5 = FALSE
	back_seat_6 = FALSE

/obj/tank/sdkfz251 //basically a type of truck, but with a MG
	icon_state = "sdkfz251"
	name = "Sd Kfz. 251"
	truck = TRUE
	halftrack = TRUE
	movement_delay = 1
	slow_movement_delay = 2.8
	fast_movement_delay = 2.2
	icon = 'icons/WW2/truck_v.dmi' // I don't know why but we start out southfacing
	horizontal_icon = 'icons/WW2/truck_h.dmi'
	vertical_icon = 'icons/WW2/truck_v.dmi'
	locked = TRUE
	truck_full = FALSE
	back_seat_1 = FALSE
	back_seat_2 = FALSE
	back_seat_3 = FALSE
	back_seat_4 = FALSE
	back_seat_5 = FALSE
	back_seat_6 = FALSE

/obj/tank/sdkfz251/polish //basically a type of truck, but with a MG
	icon_state = "szary_wilk"
	name = "'Szary Wilk'"
	truck = TRUE
	halftrack = TRUE
	movement_delay = 1
	slow_movement_delay = 2.8
	fast_movement_delay = 2.2
	icon = 'icons/WW2/truck_v.dmi' // I don't know why but we start out southfacing
	horizontal_icon = 'icons/WW2/truck_h.dmi'
	vertical_icon = 'icons/WW2/truck_v.dmi'
	locked = FALSE
	truck_full = FALSE
	back_seat_1 = FALSE
	back_seat_2 = FALSE
	back_seat_3 = FALSE
	back_seat_4 = FALSE
	back_seat_5 = FALSE
	back_seat_6 = FALSE

/obj/tank/sdkfz251/New()
	..()
	MG = new/obj/item/weapon/gun/projectile/automatic/stationary/kord/mg34(null)
	MG.invisibility = 101

/obj/tank/studebacker //trucks are a subtype of tanks because they are basically the same except for the gun.
	icon_state = "studebaker_truck"
	name = "Studebaker Truck"
	truck = TRUE
	movement_delay = 1.25
	slow_movement_delay = 1.25
	fast_movement_delay = 2.5 // reversed because trucks are faster on asphalt and slower on dirt/grass
	icon = 'icons/WW2/truck_v.dmi' // I don't know why but we start out southfacing
	horizontal_icon = 'icons/WW2/truck_h.dmi'
	vertical_icon = 'icons/WW2/truck_v.dmi'
	locked = FALSE
	truck_full = FALSE
	back_seat_1 = FALSE
	back_seat_2 = FALSE
	back_seat_3 = FALSE
	back_seat_4 = FALSE
	back_seat_5 = FALSE
	back_seat_6 = FALSE

/obj/tank/german/New()
	..()
	radio = new/obj/item/radio/feldfu
	#ifdef MG_TANKS
	MG = new/obj/item/weapon/gun/projectile/automatic/stationary/kord/mg34(null)
	MG.invisibility = 101
	#endif

/obj/tank/german/admin
	movement_delay = 0.1
	slow_movement_delay = 0.1
	fast_movement_delay = 0.1
	fire_delay = 0.3
	admin = TRUE
	locked = FALSE

/obj/tank/soviet
	icon_state = "sov"
	name = "Soviet T-23 Tank"

/obj/tank/soviet/New()
	..()
	radio = new/obj/item/radio/rbs
	#ifdef MG_TANKS
	MG = new/obj/item/weapon/gun/projectile/automatic/stationary/kord/maxim(null)
	MG.invisibility = 101
	#endif

/obj/tank/soviet/admin
	movement_delay = 0.1
	slow_movement_delay = 0.1
	fast_movement_delay = 0.1
	fire_delay = 0.3
	admin = TRUE
	locked = FALSE