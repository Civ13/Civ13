/datum/body_build
	var/name			= "Default"
	var/gender 			= MALE
	var/identifying_gender = MALE
	var/index			= "" 					// For icon_ovveride body_build supply
	var/uniform_icon	= 'icons/mob/uniform.dmi'
	var/suit_icon		= 'icons/mob/suit.dmi'
	var/gloves_icon		= 'icons/mob/hands.dmi'
	var/glasses_icon	= 'icons/mob/eyes.dmi'
	var/ears_icon		= 'icons/mob/ears.dmi'
	var/mask_icon		= 'icons/mob/mask.dmi'
	var/hat_icon		= 'icons/mob/head.dmi'
	var/shoes_icon		= 'icons/mob/feet.dmi'
	var/misk_icon		= 'icons/mob/mob.dmi'
	var/belt_icon		= 'icons/mob/belt.dmi'
	var/s_store_icon	= 'icons/mob/belt_mirror.dmi'
	var/backpack_icon	= 'icons/mob/back.dmi'
	var/underwear_icon	= 'icons/mob/underwear.dmi'

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
	glasses_icon	= 'icons/mob/eyes.dmi'
	ears_icon		= 'icons/mob/ears.dmi'
	mask_icon		= 'icons/mob/mask.dmi'
	hat_icon		= 'icons/mob/head.dmi'
	shoes_icon		= 'icons/mob/feet.dmi'
//	misk_icon		= 'icons/mob/mob.dmi'
	belt_icon		= 'icons/mob/belt.dmi'
	s_store_icon	= 'icons/mob/belt_mirror.dmi'
	backpack_icon	= 'icons/mob/back.dmi'
	underwear_icon	= 'icons/mob/underwear.dmi'

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
	glasses_icon	= 'icons/mob/eyes.dmi'
	ears_icon		= 'icons/mob/ears.dmi'
	mask_icon		= 'icons/mob/mask.dmi'
	hat_icon		= 'icons/mob/head.dmi'
	shoes_icon		= 'icons/mob/feet.dmi'
//	misk_icon		= 'icons/mob/mob.dmi'
	belt_icon		= 'icons/mob/belt.dmi'
	s_store_icon	= 'icons/mob/belt_mirror.dmi'
	backpack_icon	= 'icons/mob/back.dmi'
	underwear_icon	= 'icons/mob/underwear.dmi'

/datum/body_build/fat/female
	gender 			= FEMALE
