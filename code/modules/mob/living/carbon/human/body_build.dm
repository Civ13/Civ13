/datum/body_build
	var/name			= "Default"
	var/gender 			= MALE
	var/index			= "" 					// For icon_ovveride body_build supply
	var/uniform_icon	= 'icons/mob/uniform.dmi'
	var/suit_icon		= 'icons/mob/suit.dmi'
	var/gloves_icon		= 'icons/mob/hands.dmi'
	var/ears_icon		= 'icons/mob/ears.dmi'
	var/mask_icon		= 'icons/mob/mask.dmi'
	var/hat_icon		= 'icons/mob/head.dmi'
	var/shoes_icon		= 'icons/mob/feet.dmi'
	var/misk_icon		= 'icons/mob/mob.dmi'
	var/belt_icon		= 'icons/mob/belt.dmi'
	var/backpack_icon	= 'icons/mob/back.dmi'
	var/nohair = FALSE
	var/nofacialhair = FALSE

/datum/body_build/female
	gender 			= FEMALE
	uniform_icon	= 'icons/mob/uniform.dmi'
	suit_icon		= 'icons/mob/suit.dmi'

/datum/body_build/slim
	name			= "Slim"
	index			= "_slim"
	uniform_icon	= 'icons/mob/uniform.dmi'
	suit_icon		= 'icons/mob/suit.dmi'
	gloves_icon		= 'icons/mob/hands.dmi'
	ears_icon		= 'icons/mob/ears.dmi'
	mask_icon		= 'icons/mob/mask.dmi'
	hat_icon		= 'icons/mob/head.dmi'
	shoes_icon		= 'icons/mob/feet.dmi'
	belt_icon		= 'icons/mob/belt.dmi'

/datum/body_build/slim/female
	gender 			= FEMALE
	uniform_icon	= 'icons/mob/uniform.dmi'
	suit_icon		= 'icons/mob/suit.dmi'

/datum/body_build/fat
	name			= "Fat"
	index			= "_fat"
	uniform_icon	= 'icons/mob/uniform.dmi'
	suit_icon		= 'icons/mob/suit.dmi'
	gloves_icon		= 'icons/mob/hands.dmi'
	ears_icon		= 'icons/mob/ears.dmi'
	mask_icon		= 'icons/mob/mask.dmi'
	hat_icon		= 'icons/mob/head.dmi'
	shoes_icon		= 'icons/mob/feet.dmi'
	belt_icon		= 'icons/mob/belt.dmi'
	backpack_icon	= 'icons/mob/back.dmi'

/datum/body_build/fat/female
	gender 			= FEMALE



/datum/body_build/gorilla
	name			= "Gorilla"
	index			= "_gorilla"
	nohair = TRUE
	nofacialhair = TRUE

/datum/body_build/gorilla/female
	gender 			= FEMALE

/datum/body_build/wolfman
	name			= "Wolfman"
	index			= "_wolfman"
	nohair = TRUE
	nofacialhair = TRUE

/datum/body_build/wolfman/female
	gender 			= FEMALE