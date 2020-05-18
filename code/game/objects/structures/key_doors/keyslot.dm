/datum/keyslot
	var/code = -1
	var/locked = TRUE

/datum/keyslot/New()
	..()

/datum/keyslot/proc/check_weapon(var/obj/item/weapon/W, var/mob/living/human/H, var/msg = FALSE)
	. = FALSE

	if (istype(W, /obj/item/weapon/key))
		if (check_individual_key(W))
			. = TRUE
	else if (istype(W, /obj/item/weapon/storage/belt/keychain))
		if (check_individual_keychain(W))
			. = TRUE
	else
		. = FALSE

	if (msg && . == FALSE)
		if (istype(H.get_active_hand(), /obj/item/weapon/key))
			H << "<span class = 'danger'>Your key doesn't match this lock.</span>"
		else
			H << "<span class = 'danger'>You don't have a key which matches this lock.</span>"

	return .

/datum/keyslot/proc/check_user(var/mob/living/human/H, var/msg = FALSE)
	if (code == -1)
		return TRUE

	else if (istype(H))

		var/obj/item/weapon/storage/belt/belt = H.belt
		var/list/keys = list()

		if (belt && istype(belt) && belt.keychain && istype(belt.keychain))
			keys |= belt.keychain.keys
		if (istype(H.l_hand, /obj/item/weapon/storage/belt/keychain))
			keys |= H.l_hand:keys
		if (istype(H.r_hand, /obj/item/weapon/storage/belt/keychain))
			keys |= H.r_hand:keys
		if (istype(H.l_hand, /obj/item/weapon/key))
			keys |= H.l_hand
		if (istype(H.r_hand, /obj/item/weapon/key))
			keys |= H.r_hand

		if (istype(H.wear_id, /obj/item/weapon/storage/belt/keychain))
			var/obj/item/weapon/storage/belt/keychain/keychain = H.wear_id
			keys |= keychain.keys

		for (var/obj/item/weapon/key/key in keys)
			if (check_individual_key(key))
				return TRUE

	if (msg)
		if (istype(H.get_active_hand(), /obj/item/weapon/key))
			H << "<span class = 'danger'>Your key doesn't match this lock.</span>"
		else
			H << "<span class = 'danger'>You don't have a key which matches this lock.</span>"

	return FALSE

/datum/keyslot/proc/check_individual_key(var/obj/item/weapon/key/key)
	if (key.code == code)
		return TRUE
	return FALSE

/datum/keyslot/proc/check_individual_keychain(var/obj/item/weapon/storage/belt/keychain/keychain)
	for (var/obj/item/weapon/key/K in keychain)
		if (check_individual_key(K))
			return TRUE
	return FALSE