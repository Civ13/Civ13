// Carrying and burning animal fat for light.
// The grease horn is a stoppered horn for rendered fat: it hangs from a belt,
// takes raw fat pressed into it or oil poured into it, and refills any burning
// light. The stone fat lamp is the first lamp: a hollowed stone with a wick,
// dim but far thriftier with fat than a torch.
// Burn rates and partial use of a piece of fat are in light_fuel.dm.

/////////////////
// GREASE HORN //
/////////////////

/obj/item/weapon/reagent_containers/glass/grease_horn
	name = "grease horn"
	desc = "A hollowed horn with a wooden stopper, for carrying rendered fat or lamp oil. Press animal fat into it or pour oil in, then use it on a torch or lamp to refill the light."
	icon = 'icons/obj/fat_lights.dmi'
	icon_state = "grease_horn"
	item_state = "bottle"
	w_class = ITEM_SIZE_SMALL
	slot_flags = SLOT_BELT | SLOT_POCKET
	amount_per_transfer_from_this = 5
	possible_transfer_amounts = list(5,10,30)
	volume = 30
	value = 4
	dropsound = 'sound/effects/woodhit.ogg'

/obj/item/weapon/reagent_containers/glass/grease_horn/update_icon()
	icon_state = is_open_container() ? "grease_horn_open" : "grease_horn"

/obj/item/weapon/reagent_containers/glass/grease_horn/New()
	..()
	update_icon()

////////////////////
// STONE FAT LAMP //
////////////////////

/obj/item/flashlight/lantern/fat_lamp
	name = "stone fat lamp"
	desc = "A hollowed stone with a moss wick. It burns animal fat slowly, with a small steady flame."
	icon = 'icons/obj/fat_lights.dmi'
	icon_state = "fat_lamp"
	on_state = "fat_lamp-on"
	off_state = "fat_lamp"
	item_state = "candle1"
	brightness_on = CANDLE_LUM
	light_color = "#E09D37"
	slot_flags = 0 // an open dish of melted fat is carried in the hand
	value = 3
	fuel = 0
	max_fuel = 3600 // two pieces of fat fill the bowl for an hour
	on = FALSE
	turn_on_sound = 'sound/effects/woodhit.ogg'
	empty_message = "has no fat in it"
	// A wick sips fat: one piece of animal fat (10 lard) lasts half an hour.
	refuel_reagents = list("lard" = 180, "fat_oil" = 360, "olive_oil" = 360, "cornoil" = 360, "sunflower_oil" = 360, "linseed_oil" = 360)

/obj/item/flashlight/lantern/fat_lamp/New()
	..()
	flags &= ~CONDUCT

/obj/item/flashlight/lantern/fat_lamp/examine(mob/user)
	..()
	if (fuel > 0)
		to_chat(user, "It holds fat for about [max(1, round(fuel / 60))] more minute\s of light.")
