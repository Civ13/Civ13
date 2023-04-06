/obj/item/clothing/suit/storage/coat/germcoat
	name = "german coat"
	desc = "A German army coat."
	icon_state = "germtrench"
	item_state = "germtrench"
	worn_state = "germtrench"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 20)
	value = 65
	var/colorn = 1

/obj/item/clothing/suit/storage/coat/frenchcoat
	name = "french trench coat"
	desc = "A French trench coat."
	icon_state = "frenchtrench"
	item_state = "frenchtrench"
	worn_state = "frenchtrench"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 30)
	value = 65
	var/colorn = 1

/obj/item/clothing/suit/storage/coat/britishcoat
	name = "british coat"
	desc = "A British coat."
	icon_state = "britishtrench"
	item_state = "britishtrench"
	worn_state = "britishtrench"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 20)
	value = 65
	var/colorn = 1


/obj/item/clothing/head/ww/germcap
	name = "german cap"
	desc = "A cap worn by german soldiers."
	icon_state = "germcap2"
	item_state = "germcap2"

/obj/item/clothing/head/ww/frenchcap
	name = "french kepi"
	desc = "A flat circular cap worn by french soldiers."
	icon_state = "frenchcap"
	item_state = "frenchcap"

/obj/item/clothing/head/ww/britishcap
	name = "british cap"
	desc = "A cap worn by british soldiers."
	icon_state = "brittcap"
	item_state = "brittcap"

/obj/item/clothing/head/helmet/ww
	health = 18

/obj/item/clothing/head/helmet/ww/stahlhelm
	name = "M1915 stahlhelm"
	desc = "A typical grman stahlhelm helmet."
	icon_state = "stahlhelm_old"
	item_state = "stahlhelm_old"
	worn_state = "stahlhelm_old"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 45, arrow = 35, gun = 10, energy = 15, bomb = 45, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww/adriangreek
	name = "Greek M15 Adrian helmet"
	desc = "A typical greek adrian helmet."
	icon_state = "adrian_greek"
	item_state = "adrian_greek"
	worn_state = "adrian_greek"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

	var/strap = FALSE

/obj/item/clothing/head/helmet/ww/adriangreek/verb/toggle_strap()
	set category = null
	set src in usr
	set name = "Toggle Strap"
	if (strap)
		icon_state = "adrian_greek"
		item_state = "adrian_greek"
		worn_state = "adrian_greek"
		body_parts_covered = HEAD
		item_state_slots["slot_wear_head"] = "adrian_greek"
		usr << "<span class = 'danger'>You put down your helmets strap.</span>"
		update_icon()
		strap = FALSE
		usr.update_inv_head(1)
	else if (!strap)
		icon_state = "adrian_greek_strap"
		item_state = "adrian_greek_strap"
		worn_state = "adrian_greek_strap"
		body_parts_covered = HEAD
		item_state_slots["slot_wear_head"] = "adrian_greek_strap"
		usr << "<span class = 'danger'>You put up your helmets strap.</span>"
		update_icon()
		strap = TRUE
		usr.update_inv_head(1)

/obj/item/clothing/head/helmet/ww/adrian
	name = "M15 Adrian helmet"
	desc = "A typical french adrian."
	icon_state = "adrian_standard"
	item_state = "adrian_standard"
	worn_state = "adrian_standard"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

	var/strap = FALSE

/obj/item/clothing/head/helmet/ww/adrian/verb/toggle_strap()
	set category = null
	set src in usr
	set name = "Toggle Strap"
	if (strap)
		icon_state = "adrian_standard"
		item_state = "adrian_standard"
		worn_state = "adrian_standard"
		body_parts_covered = HEAD
		item_state_slots["slot_wear_head"] = "adrian_standard"
		usr << "<span class = 'danger'>You put down your helmets strap.</span>"
		update_icon()
		strap = FALSE
		usr.update_inv_head(1)
	else if (!strap)
		icon_state = "adrian_standard_strap"
		item_state = "adrian_standard_strap"
		worn_state = "adrian_standard_strap"
		body_parts_covered = HEAD
		item_state_slots["slot_wear_head"] = "adrian_standard_strap"
		usr << "<span class = 'danger'>You put up your helmets strap.</span>"
		update_icon()
		strap = TRUE
		usr.update_inv_head(1)

/obj/item/clothing/head/helmet/ww/adriansoviet
	name = "Russian M15 Adrian helmet"
	desc = "The adrian helmet but soviet, used by the red army"
	icon_state = "adrian_russian"
	item_state = "adrian_russian"
	worn_state = "adrian_russian"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

	var/strap = FALSE

/obj/item/clothing/head/helmet/ww/adriansoviet/verb/toggle_strap()
	set category = null
	set src in usr
	set name = "Toggle Strap"
	if (strap)
		icon_state = "adrian_russian"
		item_state = "adrian_russian"
		worn_state = "adrian_russian"
		body_parts_covered = HEAD
		item_state_slots["slot_wear_head"] = "adrian_standard"
		usr << "<span class = 'danger'>You put down your helmets strap.</span>"
		update_icon()
		strap = FALSE
		usr.update_inv_head(1)
	else if (!strap)
		icon_state = "adrian_russian_strap"
		item_state = "adrian_russian_strap"
		worn_state = "adrian_russian_strap"
		body_parts_covered = HEAD
		item_state_slots["slot_wear_head"] = "adrian_standard_strap"
		usr << "<span class = 'danger'>You put up your helmets strap.</span>"
		update_icon()
		strap = TRUE
		usr.update_inv_head(1)

/obj/item/clothing/head/helmet/ww/adrianm15medic
	name = "Medic M15 Adrian helmet"
	desc = "The adrian helmet but soviet, used by the red army"
	icon_state = "m15_adrian_m"
	item_state = "m15_adrian_m"
	worn_state = "m15_adrian_m"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww2/adrianm26
	name = "M26 Adrian helmet"
	desc = "A Typical M26 Adrian Helmet"
	icon_state = "m26_adrian"
	item_state = "m26_adrian"
	worn_state = "m26_adrian"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

	var/strap = FALSE

/obj/item/clothing/head/helmet/ww2/adrianm26/verb/toggle_strap()
	set category = null
	set src in usr
	set name = "Toggle Strap"
	if (strap)
		icon_state = "m26_adrian"
		item_state = "m26_adrian"
		worn_state = "m26_adrian"
		body_parts_covered = HEAD
		item_state_slots["slot_wear_head"] = "m26_adrian"
		usr << "<span class = 'danger'>You put down your helmets strap.</span>"
		update_icon()
		strap = FALSE
		usr.update_inv_head(1)
	else if (!strap)
		icon_state = "m26_adrian_s"
		item_state = "m26_adrian_s"
		worn_state = "m26_adrian_s"
		body_parts_covered = HEAD
		item_state_slots["slot_wear_head"] = "m26_adrian_s"
		usr << "<span class = 'danger'>You put up your helmets strap.</span>"
		update_icon()
		strap = TRUE
		usr.update_inv_head(1)

/obj/item/clothing/head/helmet/ww2/adrianm26medic
	name = "Medic M26 Adrian helmet"
	desc = "A Typical M26 Adrian Helmet, this one for medics"
	icon_state = "m26_medic"
	item_state = "m26_medic"
	worn_state = "m26_medic"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww/mk1brodiedeb
	name = "Mk1 Brodie Helmet"
	desc = "A typical british helmet in WW1, this one being in duck egg blue."
	icon_state = "brodie_mk1_deb"
	item_state = "brodie_mk1_deb"
	worn_state = "brodie_mk1_deb"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww/mk1brodieag
	name = "Mk1 Brodie Helmet"
	desc = "A typical british helmetin WW1, this one being in apple green."
	icon_state = "brodie_mk1_ag"
	item_state = "brodie_mk1_ag"
	worn_state = "brodie_mk1_ag"

/obj/item/clothing/head/helmet/ww/mk2brodieog
	name = "Mk2 Brodie Helmet"
	desc = "A typical british helmet in WW2, this one being in olive green."
	icon_state = "brodie_mk2_og"
	item_state = "brodie_mk2_og"
	worn_state = "brodie_mk2_og"

/obj/item/clothing/head/helmet/ww/mk2brodiemedic
	name = "Mk2 Brodie Medic Helmet"
	desc = "A typical british helmet in WW2, this one being for medics."
	icon_state = "brodie_mk2_medic"
	item_state = "brodie_mk2_medic"
	worn_state = "brodie_mk2_medic"


/obj/item/clothing/head/helmet/ww/mk2brodieirish
	name = "Irish Mk2 Brodie Helmet"
	desc = "A typical british helmet in WW2, this one being the Irish Royal Rifles."
	icon_state = "brodie_mk2_irish"
	item_state = "brodie_mk2_irish"
	worn_state = "brodie_mk2_irish"

/obj/item/clothing/head/helmet/ww/mk2brodiegnet
	name = "Mk2 Brodie Helmet with green netting"
	desc = "A typical british helmet in WW2, this one being having green netting."
	icon_state = "brodie_mk2_netgreen"
	item_state = "brodie_mk2_netgreen"
	worn_state = "brodie_mk2_netgreen"

/obj/item/clothing/head/helmet/ww/mk2brodietnet
	name = "Mk2 Brodie Helmet with tan netting"
	desc = "A typical british helmet in WW2, this one being having tan netting."
	icon_state = "brodie_mk2_nettan"
	item_state = "brodie_mk2_nettan"
	worn_state = "brodie_mk2_nettan"

/obj/item/clothing/head/helmet/ww/mk2brodieog/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return//I really don't understand why this check is needed
	if (istype(W, /obj/item/stack/material/leaf))
		playsound(loc, 'sound/machines/click.ogg', 75, TRUE)
		user << "<span class='notice'>You put foliage on the helmet.</span>"
		new/obj/item/clothing/head/helmet/ww/mk2brodiegnet(user.loc)
		qdel(src)
		qdel(W)

/obj/item/clothing/head/helmet/ww/mk2brodiegnet/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return//I really don't understand why this check is needed
	if (istype(W, /obj/item/stack/material/leaf))
		playsound(loc, 'sound/machines/click.ogg', 75, TRUE)
		user << "<span class='notice'>You put foliage on the helmet.</span>"
		new/obj/item/clothing/head/helmet/ww/mk2brodiegreennetf(user.loc)
		qdel(src)
		qdel(W)

/obj/item/clothing/head/helmet/ww/mk2brodietnet/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return//I really don't understand why this check is needed
	if (istype(W, /obj/item/stack/material/leaf))
		playsound(loc, 'sound/machines/click.ogg', 75, TRUE)
		user << "<span class='notice'>You put foliage on the helmet.</span>"
		new/obj/item/clothing/head/helmet/ww/mk2brodietannetf(user.loc)
		qdel(src)
		qdel(W)

/obj/item/clothing/head/helmet/ww/mk2brodietannetf
	name = "camouflaged Mk2 Brodie Helmet"
	desc = "A typical british helmet in WW2, this one being having tan netting and foliage for camoflauge."
	icon_state = "brodie_mk2_nettanf"
	item_state = "brodie_mk2_nettanf"
	worn_state = "brodie_mk2_nettanf"

/obj/item/clothing/head/helmet/ww/mk2brodiegreennetf
	name = "camouflaged Mk2 Brodie Helmet"
	desc = "A typical british helmet in WW2, this one being having green netting and foliage for camoflauge."
	icon_state = "brodie_mk2_netgreenf"
	item_state = "brodie_mk2_netgreenf"
	worn_state = "brodie_mk2_netgreenf"

/obj/item/clothing/head/helmet/ww/pickelhaube2
	name = "leather pickelhaube"
	desc = "A typical pointed helmet."
	icon_state = "pickelhaube2"
	item_state = "pickelhaube2"
	worn_state = "pickelhaube2"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 30, arrow = 30, gun = 3, energy = 10, bomb = 35, bio = 20, rad = FALSE)


/obj/item/clothing/glasses/pilot
	name = "pilot goggles"
	desc = "Early 20th century pilot goggles."
	icon_state = "biker"
	item_state = "biker"
	worn_state = "biker"

/obj/item/clothing/under/ww2/gulag_prisoner
	name = "GULAG prisoner clothing"
	desc = "A worn out GULAG prisoner outfit."
	icon_state = "gulagprisoner"
	item_state = "gulagprisoner"
	worn_state = "gulagprisoner"

////////////////////////////////////////////////////////////////////////
///////////////////////////////WW2 JAPS/////////////////////////////////
////////////////////////////////////////////////////////////////////////
/obj/item/clothing/head/helmet/ww2
	health = 20
/obj/item/clothing/head/helmet/ww2/japhelm
	name = "japanese helmet"
	desc = "A typical rounded steel helmet."
	icon_state = "japhelm"
	item_state = "japhelm"
	worn_state = "japhelm"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 43, arrow = 33, gun = 10, energy = 15, bomb = 44, bio = 20, rad = FALSE)
	var/has_headband = FALSE
	var/has_havelock = FALSE
/obj/item/clothing/head/helmet/ww2/japhelm/verb/strip_accessories(mob/user as mob)
	set category = null
	set src in usr
	if (type != /obj/item/clothing/head/helmet/ww2/japhelm)
		return
	else
		if (has_headband && !has_havelock)
			item_state = "japhelm"
			icon_state = "japhelm"
			worn_state = "japhelm"
			item_state_slots["slot_w_uniform"] = "japhelm"
			usr << "<span class = 'danger'>You remove the headband from your helmet</span>"
			has_headband = FALSE
			new/obj/item/clothing/head/ww2/jap_headband(user.loc)
			update_clothing_icon()
		else if (has_havelock && !has_headband)
			item_state = "japhelm"
			icon_state = "japhelm"
			worn_state = "japhelm"
			item_state_slots["slot_w_uniform"] = "japhelm"
			usr << "<span class = 'danger'>You remove the havelocks from your helmet</span>"
			has_havelock = FALSE
			new/obj/item/havelock(user.loc)
			update_clothing_icon()
		else if (has_headband && has_havelock)
			item_state = "japhelm"
			icon_state = "japhelm"
			worn_state = "japhelm"
			item_state_slots["slot_w_uniform"] = "japhelm"
			usr << "<span class = 'danger'>You remove the havelocks and the headband from your helmet</span>"
			has_havelock = FALSE
			has_headband = FALSE
			new/obj/item/havelock(user.loc)
			new/obj/item/clothing/head/ww2/jap_headband(user.loc)
			update_clothing_icon()
		else if (!has_headband && !has_havelock)
			item_state = "japhelm"
			icon_state = "japhelm"
			worn_state = "japhelm"
			item_state_slots["slot_w_uniform"] = "japhelm"
			usr << "<span class = 'danger'>You have nothing attached to your helmet</span>"
			update_clothing_icon()


/obj/item/clothing/head/helmet/ww2/japhelm/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return//I really don't understand why this check is needed
	if (istype(W, /obj/item/clothing/head/ww2/jap_headband) && !has_headband)
		playsound(loc, 'sound/machines/click.ogg', 75, TRUE)
		user << "<span class='notice'>You place the headband on the helmet.</span>"
		src.has_headband = TRUE
		qdel(W)
		if(src.has_havelock == TRUE)
			src.item_state = "japhelm_bandana_extended"
			src.icon_state = "japhelm_bandana_extended"
			src.worn_state = "japhelm_bandana_extended"
		else
			src.item_state = "japhelm_bandana"
			src.icon_state = "japhelm_bandana"
			src.worn_state = "japhelm_bandana"
		update_clothing_icon()
		return
	if (istype(W, /obj/item/havelock) && !has_havelock)
		playsound(loc, 'sound/machines/click.ogg', 75, TRUE)
		user << "<span class='notice'>You place the headband on the helmet.</span>"
		src.has_havelock = TRUE
		qdel(W)
		if(src.has_headband == TRUE)
			src.item_state = "japhelm_bandana_extended"
			src.icon_state = "japhelm_bandana_extended"
			src.worn_state = "japhelm_bandana_extended"
		else
			src.item_state = "japhelm_extended"
			src.icon_state = "japhelm_extended"
			src.worn_state = "japhelm_extended"
		update_clothing_icon()
		return


/obj/item/clothing/head/helmet/ww2/japhelm_snlf
	name = "japanese helmet"
	desc = "A typical rounded steel helmet."
	icon_state = "japhelm_snlf"
	item_state = "japhelm_snlf"
	worn_state = "japhelm_snlf"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 43, arrow = 33, gun = 10, energy = 15, bomb = 44, bio = 20, rad = FALSE)
	var/has_havelock = FALSE

/obj/item/clothing/head/helmet/ww2/japhelm_snlf/verb/strip_accessories(mob/user as mob)
	set category = null
	set src in usr
	if (type != /obj/item/clothing/head/helmet/ww2/japhelm_snlf)
		return
	else
		if (has_havelock)
			item_state = "japhelm_snlf"
			icon_state = "japhelm_snlf"
			worn_state = "japhelm_snlf"
			item_state_slots["slot_w_uniform"] = "japhelm_snlf"
			usr << "<span class = 'danger'>You remove the havelocks from your helmet</span>"
			has_havelock = FALSE
			new/obj/item/havelock(user.loc)
			update_clothing_icon()
		else
			item_state = "japhelm_snlf"
			icon_state = "japhelm_snlf"
			worn_state = "japhelm_snlf"
			item_state_slots["slot_w_uniform"] = "japhelm_snlf"
			usr << "<span class = 'danger'>You have nothing attached to the helmet!</span>"
			update_clothing_icon()
/obj/item/clothing/head/helmet/ww2/japhelm_snlf/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return//I really don't understand why this check is needed
	if (istype(W, /obj/item/havelock) && !has_havelock)
		playsound(loc, 'sound/machines/click.ogg', 75, TRUE)
		user << "<span class='notice'>You place the havelocks on the helmet.</span>"
		src.has_havelock = TRUE
		qdel(W)
		src.item_state = "japhelm_snlf_extended"
		src.icon_state = "japhelm_snlf_extended"
		src.worn_state = "japhelm_snlf_extended"
		update_clothing_icon()
		return


/obj/item/clothing/head/helmet/ww2/japhelm_med
	name = "japanese medic helmet"
	desc = "A typical rounded steel helmet, this one bearing the marks of a medic."
	icon_state = "japhelm_medic"
	item_state = "japhelm_medic"
	worn_state = "japhelm_medic"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 43, arrow = 33, gun = 10, energy = 15, bomb = 44, bio = 20, rad = FALSE)
	var/has_havelock = FALSE

/obj/item/clothing/head/helmet/ww2/japhelm_med/verb/strip_accessories(mob/user as mob)
	set category = null
	set src in usr
	if (type != /obj/item/clothing/head/helmet/ww2/japhelm_med)
		return
	else
		if (has_havelock)
			item_state = "japhelm_medic"
			icon_state = "japhelm_medic"
			worn_state = "japhelm_medic"
			item_state_slots["slot_w_uniform"] = "japhelm_medic"
			usr << "<span class = 'danger'>You remove the havelocks from your helmet</span>"
			has_havelock = FALSE
			new/obj/item/havelock(user.loc)
			update_clothing_icon()
		else
			item_state = "japhelm_medic"
			icon_state = "japhelm_medic"
			worn_state = "japhelm_medic"
			item_state_slots["slot_w_uniform"] = "japhelm_medic"
			usr << "<span class = 'danger'>You have nothing attached to the helmet!</span>"
			update_clothing_icon()

/obj/item/clothing/head/helmet/ww2/japhelm_med/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return//I really don't understand why this check is needed
	if (istype(W, /obj/item/havelock) && !has_havelock)
		playsound(loc, 'sound/machines/click.ogg', 75, TRUE)
		user << "<span class='notice'>You place the havelocks on the helmet.</span>"
		src.has_havelock = TRUE
		qdel(W)
		src.item_state = "japhelm_med_extended"
		src.icon_state = "japhelm_med_extended"
		src.worn_state = "japhelm_med_extended"
		update_clothing_icon()
		return

/obj/item/clothing/head/helmet/ww2/japhelm_tanker
	name = "japanese tanker helmet"
	desc = "A typical rounded steel helmet, this one more made of meshes and hard leather."
	icon_state = "japtanker"
	item_state = "japtanker"
	worn_state = "japtanker"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww2/japhelm/bandana
	has_headband = TRUE
/obj/item/clothing/head/helmet/ww2/japhelm/bandana/New()
	..()
	update_clothing_icon()

/obj/item/clothing/head/ww2/japcap
	name = "japanese cap"
	desc = "A cap worn by japanese soldiers."
	icon_state = "ww2_japcap"
	item_state = "ww2_japcap"
	worn_state = "ww2_japcap"
	var/has_havelock = FALSE

/obj/item/clothing/head/ww2/japcap/verb/strip_accessories(mob/user as mob)
	set category = null
	set src in usr
	if (type != /obj/item/clothing/head/ww2/japcap)
		return
	else
		if (has_havelock)
			item_state = "ww2_japcap"
			icon_state = "ww2_japcap"
			worn_state = "ww2_japcap"
			item_state_slots["slot_w_uniform"] = "ww2_japcap"
			usr << "<span class = 'danger'>You remove the havelocks from your cap</span>"
			has_havelock = FALSE
			new/obj/item/havelock(user.loc)
			update_clothing_icon()
		else
			item_state = "ww2_japcap"
			icon_state = "ww2_japcap"
			worn_state = "ww2_japcap"
			item_state_slots["slot_w_uniform"] = "ww2_japcap"
			usr << "<span class = 'danger'>You have nothing attached to the cap!</span>"
			update_clothing_icon()

/obj/item/clothing/head/ww2/japcap/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return//I really don't understand why this check is needed
	if (istype(W, /obj/item/havelock) && !has_havelock)
		playsound(loc, 'sound/machines/click.ogg', 75, TRUE)
		user << "<span class='notice'>You place the havelocks on the cap.</span>"
		src.has_havelock = TRUE
		qdel(W)
		src.item_state = "ww2_japcap_extended"
		src.icon_state = "ww2_japcap_extended"
		src.worn_state = "ww2_japcap_extended"
		update_clothing_icon()
		return

/obj/item/clothing/head/ww2/japoffcap
	name = "japanese officer cap"
	desc = "A cap worn by japanese officers."
	icon_state = "ww2_japoffcap"
	item_state = "ww2_japoffcap"
	worn_state = "ww2_japoffcap"
	var/has_havelock = FALSE

/obj/item/clothing/head/ww2/japoffcap/verb/strip_accessories(mob/user as mob)
	set category = null
	set src in usr
	if (type != /obj/item/clothing/head/ww2/japoffcap)
		return
	else
		if (has_havelock)
			item_state = "ww2_japoffcap"
			icon_state = "ww2_japoffcap"
			worn_state = "ww2_japoffcap"
			item_state_slots["slot_w_uniform"] = "ww2_japoffcap"
			usr << "<span class = 'danger'>You remove the havelocks from your cap</span>"
			has_havelock = FALSE
			new/obj/item/havelock(user.loc)
			update_clothing_icon()
		else
			item_state = "ww2_japoffcap"
			icon_state = "ww2_japoffcap"
			worn_state = "ww2_japoffcap"
			item_state_slots["slot_w_uniform"] = "ww2_japoffcap"
			usr << "<span class = 'danger'>You have nothing attached to the cap!</span>"
			update_clothing_icon()
/obj/item/clothing/head/ww2/japoffcap/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return//I really don't understand why this check is needed
	if (istype(W, /obj/item/havelock) && !has_havelock)
		playsound(loc, 'sound/machines/click.ogg', 75, TRUE)
		user << "<span class='notice'>You place the havelocks on the cap.</span>"
		src.has_havelock = TRUE
		qdel(W)
		src.item_state = "ww2_japoffcap_extended"
		src.icon_state = "ww2_japoffcap_extended"
		src.worn_state = "ww2_japoffcap_extended"
		update_clothing_icon()
		return


/obj/item/clothing/head/ww2/japcap_snlf
	name = "japanese cap"
	desc = "A cap worn by japanese soldiers in the SNLF."
	icon_state = "ww2_japcap_snlf"
	item_state = "ww2_japcap_snlf"
	worn_state = "ww2_japcap_snlf"
	var/has_havelock = FALSE

/obj/item/clothing/head/ww2/japcap_snlf/verb/strip_accessories(mob/user as mob)
	set category = null
	set src in usr
	if (type != /obj/item/clothing/head/ww2/japcap_snlf)
		return
	else
		if (has_havelock)
			item_state = "ww2_japcap_snlf"
			icon_state = "ww2_japcap_snlf"
			worn_state = "ww2_japcap_snlf"
			item_state_slots["slot_w_uniform"] = "ww2_japcap_snlf"
			usr << "<span class = 'danger'>You remove the havelocks from your cap</span>"
			has_havelock = FALSE
			new/obj/item/havelock(user.loc)
			update_clothing_icon()
		else
			item_state = "ww2_japcap_snlf"
			icon_state = "ww2_japcap_snlf"
			worn_state = "ww2_japcap_snlf"
			item_state_slots["slot_w_uniform"] = "ww2_japcap_snlf"
			usr << "<span class = 'danger'>You have nothing attached to the cap!</span>"
			update_clothing_icon()

/obj/item/clothing/head/ww2/japcap_snlf/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return//I really don't understand why this check is needed
	if (istype(W, /obj/item/havelock) && !has_havelock)
		playsound(loc, 'sound/machines/click.ogg', 75, TRUE)
		user << "<span class='notice'>You place the havelocks on the cap.</span>"
		src.has_havelock = TRUE
		qdel(W)
		src.item_state = "ww2_japcap_snlf_extended"
		src.icon_state = "ww2_japcap_snlf_extended"
		src.worn_state = "ww2_japcap_snlf_extended"
		update_clothing_icon()
		return

/obj/item/clothing/under/ww2/japoffuni
	name = "japanese officer uniform"
	desc = "A imperial japanese army officer uniform."
	icon_state = "ww2_japoffuni"
	item_state = "ww2_japoffuni"
	worn_state = "ww2_japoffuni"
	var/rolled = FALSE

/obj/item/clothing/under/ww2/japoffuni/verb/roll_sleeves()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/under/ww2/japoffuni)
		return
	else
		if (rolled)
			item_state = "ww2_japoffuni"
			worn_state = "ww2_japoffuni"
			icon_state = "ww2_japoffuni"
			item_state_slots["w_uniform"] = "ww2_japoffuni"
			usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
			rolled = FALSE
			cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
			update_clothing_icon()
		else if (!rolled)
			item_state = "ww2_japoffuni_rolled"
			worn_state = "ww2_japoffuni_rolled"
			icon_state = "ww2_japoffuni_rolled"
			item_state_slots["w_uniform"] = "ww2_japoffuni_rolled"
			usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
			rolled = TRUE
			heat_protection = ARMS
			cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS
			update_clothing_icon()

/obj/item/clothing/under/ww2/japuni
	name = "japanese uniform"
	desc = "A imperial japanese army uniform."
	icon_state = "ww2_japuni"
	item_state = "ww2_japuni"
	worn_state = "ww2_japuni"
	var/rolled = FALSE
	var/stripped = FALSE

/obj/item/clothing/under/ww2/japuni/update_icon()
	if (map && (map.ID == MAP_NANKOU || map.ID == MAP_NANJING))
		worn_state = "1937_japuni"
		item_state = "1937_japuni"
		icon_state = "1937_japuni"
	else
		worn_state = "ww2_japuni"
		item_state = "ww2_japuni"
		icon_state = "ww2_japuni"
/obj/item/clothing/under/ww2/japuni/verb/roll_sleeves()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/under/ww2/japuni)
		return
	else
		if (!stripped)
			if (rolled)
				if (map.ID == MAP_NANKOU || map.ID == MAP_NANJING)
					worn_state = "1937_japuni"
					item_state = "1937_japuni"
					icon_state = "1937_japuni"
					item_state_slots["w_uniform"] = "1937_japuni"
					usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
					rolled = FALSE
					cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
					update_clothing_icon()
					return
				else
					worn_state = "ww2_japuni"
					item_state = "ww2_japuni"
					icon_state = "ww2_japuni"
					item_state_slots["w_uniform"] = "ww2_japuni"
					usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
					rolled = FALSE
					cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
					update_clothing_icon()
					return
			if (!rolled)
				if (map.ID == MAP_NANKOU || map.ID == MAP_NANJING)
					worn_state = "1937_japuni_rolled"
					item_state = "1937_japuni_rolled"
					icon_state = "1937_japuni_rolled"
					item_state_slots["w_uniform"] = "1937_japuni_rolled"
					usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
					rolled = TRUE
					heat_protection = ARMS
					cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS
					update_clothing_icon()
					return
				else
					worn_state = "ww2_japuni_rolled"
					item_state = "ww2_japuni_rolled"
					icon_state = "ww2_japuni_rolled"
					item_state_slots["w_uniform"] = "ww2_japuni_rolled"
					usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
					rolled = TRUE
					cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
					update_clothing_icon()
					return
		else
			if (rolled)
				worn_state = "japuni_summer"
				item_state = "japuni_summer"
				icon_state = "japuni_summer"
				item_state_slots["w_uniform"] = "japuni_summer"
				usr << "<span class = 'danger'>You roll down your jyuban's sleeves.</span>"
				rolled = FALSE
				cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
				update_clothing_icon()
				return
			else
				worn_state = "japuni_summer_rolled"
				item_state = "japuni_summer_rolled"
				icon_state = "japuni_summer_rolled"
				item_state_slots["w_uniform"] = "japuni_summer_rolled"
				usr << "<span class = 'danger'>You roll up your jyuban's sleeves.</span>"
				rolled = TRUE
				cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
				update_clothing_icon()
				return
/obj/item/clothing/under/ww2/japuni/verb/strip()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/under/ww2/japuni)
		return
	else
		if (stripped)
			if (map.ID == MAP_NANKOU || map.ID == MAP_NANJING)
				if (!rolled)
					worn_state = "1937_japuni"
					item_state = "1937_japuni"
					icon_state = "1937_japuni"
					item_state_slots["w_uniform"] = "1937_japuni"
					usr << "<span class = 'danger'>You put on your uniform.</span>"
					stripped = FALSE
					cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
					update_clothing_icon()
					return
				else
					worn_state = "1937_japuni_rolled"
					item_state = "1937_japuni_rolled"
					icon_state = "1937_japuni_rolled"
					item_state_slots["w_uniform"] = "1937_japuni_rolled"
					usr << "<span class = 'danger'>You put on your uniform.</span>"
					stripped = FALSE
					cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
					update_clothing_icon()
					return
			else
				if (!rolled)
					worn_state = "ww2_japuni"
					item_state = "ww2_japuni"
					icon_state = "ww2_japuni"
					item_state_slots["w_uniform"] = "ww2_japuni"
					usr << "<span class = 'danger'>You put on your uniform.</span>"
					stripped = FALSE
					cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
					update_clothing_icon()
					return
				else
					worn_state = "ww2_japuni_rolled"
					item_state = "ww2_japuni_rolled"
					icon_state = "ww2_japuni_rolled"
					item_state_slots["w_uniform"] = "1937_japuni_rolled"
					usr << "<span class = 'danger'>You put on your uniform.</span>"
					stripped = FALSE
					cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
					update_clothing_icon()
					return
		else
			if (!rolled)
				worn_state = "japuni_summer"
				item_state = "japuni_summer"
				icon_state = "japuni_summer"
				item_state_slots["w_uniform"] = "japuni_summer"
				usr << "<span class = 'danger'>You strip to your jyuban.</span>"
				stripped = TRUE
				heat_protection = ARMS
				cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS
				update_clothing_icon()
				return
			else
				worn_state = "japuni_summer_rolled"
				item_state = "japuni_summer_rolled"
				icon_state = "japuni_summer_rolled"
				item_state_slots["w_uniform"] = "japuni_summer_rolled"
				usr << "<span class = 'danger'>You strip to your jyuban.</span>"
				stripped = TRUE
				heat_protection = ARMS
				cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS
				update_clothing_icon()
				return

/obj/item/clothing/under/ww2/japuni/New()
	..()
	update_clothing_icon()

/obj/item/clothing/under/ww2/japuni_snlf
	name = "japanese uniform"
	desc = "A imperial japanese SNLF uniform."
	icon_state = "ww2_japuni_snlf"
	item_state = "ww2_japuni_snlf"
	worn_state = "ww2_japuni_snlf"
	var/rolled = FALSE

/obj/item/clothing/under/ww2/japuni_snlf/verb/roll_sleeves()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/under/ww2/japuni_snlf)
		return
	else
		if (rolled)
			worn_state = "ww2_japuni_snlf"
			item_state = "ww2_japuni_snlf"
			icon_state = "ww2_japuni_snlf"
			item_state_slots["w_uniform"] = "ww2_japuni_snlf"
			usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
			rolled = FALSE
			cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
			update_clothing_icon()
		else if (!rolled)
			worn_state = "ww2_japuni_snlf_rolled"
			item_state = "ww2_japuni_snlf_rolled"
			icon_state = "ww2_japuni_snlf_rolled"
			item_state_slots["w_uniform"] = "ww2_japuni_snlf_rolled"
			usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
			rolled = TRUE
			heat_protection = ARMS
			cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS
			update_clothing_icon()

obj/item/clothing/under/ww2/japuni_tanker
	name = "japanese tanker uniform"
	desc = "A imperial japanese army uniform, this one bears the rank of a tanker."
	icon_state = "japtanker"
	item_state = "japtanker"
	worn_state = "japtanker"

/obj/item/clothing/head/ww2/jap_headband
	name = "japanese headband"
	desc = "A headband worn by japanese soldiers."
	icon_state = "japbandana"
	item_state = "japbandana"
	worn_state = "japbandana"

obj/item/clothing/accessory/harness
	name = "japanese pilot harness"
	desc = "a harness made to strap someone to their plane."
	icon = 'icons/obj/clothing/ties.dmi'
	icon_state = "jap_harn"
	item_state = "jap_harn"
	worn_state = "jap_harn"
	ripable = FALSE
	flags = CONDUCT

/obj/item/clothing/suit/storage/coat/ww2/japcoat
	name = "japanese coat"
	desc = "A japanese army coat."
	icon_state = "ww2_japcoat"
	item_state = "ww2_japcoat"
	worn_state = "ww2_japcoat"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 25)
	value = 65

/obj/item/clothing/suit/storage/coat/ww2/japcoat/sand
	name = "sand-colored jacket"
	desc = "A sand-colored army jacket."

/obj/item/clothing/suit/storage/coat/ww2/japcoat_rain
	name = "japanese rain coat"
	desc = "A japanese army coat."
	icon_state = "jap_raincoat"
	item_state = "jap_raincoat"
	worn_state = "jap_raincoat"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 25)
	value = 75

/obj/item/clothing/suit/storage/coat/ww2/japcoat_pilot
	name = "japanese pilot coat"
	desc = "A japanese air force kamikaze jacket."
	icon_state = "jappilotcoat"
	item_state = "jappilotcoat"
	worn_state = "jappilotcoat"
	body_parts_covered = UPPER_TORSO||ARMS
	cold_protection = UPPER_TORSO|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 25)
	value = 100

obj/item/clothing/head/ww2/jap_pilotcap
	name = "japanese pilot cap"
	desc = "A cap worn by japanese pilots."
	icon_state = "jappilotcap"
	item_state = "jappilotcap"
	worn_state = "jappilotcap"
	flags = CONDUCT

obj/item/clothing/head/ww2/jap_mp
	name = "Kenpeitai cap"
	desc = "A cap worn by japanese Kenpeitai."
	icon_state = "japcap_mp"
	item_state = "japcap_mp"
	worn_state = "japcap_mp"

/obj/item/clothing/head/ww2/japwinter
	name = "japanese winter cap"
	desc = "A japanese winter cap, used by soldiers in the imperial army."
	icon_state = "japwinter_up"
	item_state = "japwinter_up"
	worn_state = "japwinter_up"
	flags_inv = BLOCKHEADHAIR
	cold_protection = HEAD

/obj/item/clothing/head/ww2/japwinter/down
	icon_state = "japwinter"
	item_state = "japwinter"
	worn_state = "japwinter"

/obj/item/clothing/head/ww2/japwinter/attack_self(mob/user as mob)
	if (icon_state == "japwinter")
		icon_state = "japwinter_up"
		item_state = "japwinter_up"
		user << "You raise the ear flaps on the fur cap."
	else
		icon_state = "japwinter"
		item_state = "japwinter"
		user << "You lower the ear flaps on the fur cap."

/obj/item/puttees
	name = "Puttees"
	desc = "Leg wraps to keep rocks out of your boots and tension on your calves."
	icon = 'icons/obj/items.dmi'
	icon_state = "puttees"

/obj/item/havelock
	name = "Bou-tare"
	desc = "A piece of cloth hung on a senbou cap to protect the wearer's neck from the sun."
	icon = 'icons/obj/items.dmi'
	icon_state = "havelock"

/obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2
	name = "leather boots"
	desc = "A pair of hobnailed leather boots"
	icon_state = "japboots_ww2"
	item_state = "japboots_ww2"
	worn_state = "japboots_ww2"
	var/puttees = FALSE
/obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/update_icon()
	if (puttees)
		item_state = "japboots_ww2_puttees"
		icon_state = "japboots_ww2_puttees"
		worn_state = "japboots_ww2_puttees"
		item_state_slots["shoes"] = "japboots_ww2_puttees"
	else
		item_state = "japboots_ww2"
		icon_state = "japboots_ww2"
		worn_state = "japboots_ww2"
		item_state_slots["slot_w_uniform"] = "japboots_ww2"
/obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/verb/strip_off_puttees(mob/user as mob)
	set category = null
	set src in usr
	if (type != /obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2 && type != /obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/puttees)
		return
	else
		if (puttees)
			item_state = "japboots_ww2"
			icon_state = "japboots_ww2"
			worn_state = "japboots_ww2"
			item_state_slots["slot_w_uniform"] = "japboots_ww2"
			usr << "<span class = 'danger'>You unwrap your puttees.</span>"
			puttees = FALSE
			new/obj/item/puttees(user.loc)
			update_clothing_icon()
		else if (!puttees)
			item_state = "japboots_ww2"
			icon_state = "japboots_ww2"
			worn_state = "japboots_ww2"
			item_state_slots["slot_w_uniform"] = "japboots_ww2"
			usr << "<span class = 'danger'>You haven't any puttees on the boots!</span>"
			puttees = FALSE
			update_clothing_icon()

/obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return//I really don't understand why this check is needed
	if (istype(W, /obj/item/puttees) && !puttees)
		playsound(loc, 'sound/machines/click.ogg', 75, TRUE)
		user << "<span class='notice'>You wrap the puttees around your legs.</span>"
		src.puttees = TRUE
		qdel(W)
		src.item_state = "japboots_ww2_puttees"
		src.icon_state = "japboots_ww2_puttees"
		src.worn_state = "japboots_ww2_puttees"
		item_state_slots["shoes"] = "japboots_ww2_puttees"
		update_clothing_icon()
		return

/obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/puttees
	puttees = TRUE
/obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/puttees/update_icon()
	if (puttees)
		item_state = "japboots_ww2_puttees"
		icon_state = "japboots_ww2_puttees"
		worn_state = "japboots_ww2_puttees"
		item_state_slots["shoes"] = "japboots_ww2_puttees"
	else
		item_state = "japboots_ww2"
		icon_state = "japboots_ww2"
		worn_state = "japboots_ww2"
		item_state_slots["slot_w_uniform"] = "japboots_ww2"
/obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/puttees/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return//I really don't understand why this check is needed
	if (istype(W, /obj/item/puttees) && !puttees)
		playsound(loc, 'sound/machines/click.ogg', 75, TRUE)
		user << "<span class='notice'>You wrap the puttees around your legs.</span>"
		src.puttees = TRUE
		qdel(W)
		src.item_state = "japboots_ww2_puttees"
		src.icon_state = "japboots_ww2_puttees"
		src.worn_state = "japboots_ww2_puttees"
		item_state_slots["shoes"] = "japboots_ww2_puttees"
		update_clothing_icon()
		return
/obj/item/clothing/shoes/heavyboots/wrappedboots/jap_ww2/puttees/New()
	..()
	update_icon()
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////BRITISH////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/obj/item/clothing/head/ww2/britishoffcap
	name = "british officer cap"
	desc = "A cap worn by british officers."
	icon_state = "ww2_british_officer"
	item_state = "ww2_british_officer"
	worn_state = "ww2_british_officer"
	var/toggled = FALSE

/obj/item/clothing/head/ww2/britishoffcap/verb/toggle_flaps()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/head/ww2/britishoffcap)
		return
	else
		if (toggled)
			item_state = "ww2_british_officer"
			icon_state = "ww2_british_officer"
			worn_state = "ww2_british_officer"
			item_state_slots["slot_w_uniform"] = "ww2_british_officer"
			usr << "<span class = 'danger'>You put up your cap's flaps.</span>"
			toggled = FALSE
			update_clothing_icon()
		else if (!toggled)
			item_state = "ww2_british_officer_flap"
			icon_state = "ww2_british_officer_flap"
			worn_state = "ww2_british_officer_flap"
			item_state_slots["slot_w_uniform"] = "ww2_british_officer_flap"
			usr << "<span class = 'danger'>You put down your cap's flaps.</span>"
			toggled = TRUE
			update_clothing_icon()

/obj/item/clothing/head/ww2/britishoffcap_tropical
	name = "british officer cap"
	desc = "A cap worn by british officers, this one being a tropical green."
	icon_state = "ww2_british_officer_tropical"
	item_state = "ww2_british_officer_tropical"
	worn_state = "ww2_british_officer_tropical"
	var/toggled = FALSE

/obj/item/clothing/head/ww2/britishoffcap_tropical/verb/toggle_flaps()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/head/ww2/britishoffcap_tropical)
		return
	else
		if (toggled)
			item_state = "ww2_british_officer_tropical"
			worn_state = "ww2_british_officer_tropical"
			icon_state = "ww2_british_officer_tropical"
			item_state_slots["slot_w_uniform"] = "ww2_british_officer_tropical"
			usr << "<span class = 'danger'>You put up your cap's flaps.</span>"
			toggled = FALSE
			update_clothing_icon()
		else if (!toggled)
			item_state = "ww2_british_officer_tropical_flap"
			worn_state = "ww2_british_officer_tropical_flap"
			icon_state = "ww2_british_officer_tropical_flap"
			item_state_slots["slot_w_uniform"] = "ww2_british_officer_tropical_flap"
			usr << "<span class = 'danger'>You put down your cap's flaps.</span>"
			toggled = TRUE
			update_clothing_icon()

/obj/item/clothing/under/ww2/british
	name = "british uniform"
	desc = "A khaki british uniform."
	icon_state = "ww2_british_tropical"
	item_state = "ww2_british_tropical"
	worn_state = "ww2_british_tropical"
	var/rolled = FALSE

/obj/item/clothing/under/ww2/british/verb/roll_sleeves()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/under/ww2/british)
		return
	else
		if (rolled)
			item_state = "ww2_british_tropical"
			icon_state = "ww2_british_tropical"
			worn_state = "ww2_british_tropical"
			item_state_slots["w_uniform"] = "ww2_british_tropical"
			usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
			rolled = FALSE
			update_clothing_icon()
		else if (!rolled)
			item_state = "ww2_british_tropical_rolled"
			worn_state = "ww2_british_tropical_rolled"
			icon_state = "ww2_british_tropical_rolled"
			item_state_slots["w_uniform"] = "ww2_british_tropical_rolled"
			usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
			rolled = TRUE
			update_clothing_icon()

/obj/item/clothing/under/ww2/british_off
	name = "british officer uniform"
	desc = "A tropical green british officer uniform."
	icon_state = "ww2_british_off_tropical"
	item_state = "ww2_british_off_tropical"
	worn_state = "ww2_british_off_tropical"
	var/rolled = FALSE

/obj/item/clothing/under/ww2/british_off/verb/roll_sleeves()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/under/ww2/british_off)
		return
	else
		if (rolled)
			item_state = "ww2_british_off_tropical"
			worn_state = "ww2_british_off_tropical"
			icon_state = "ww2_british_off_tropical"
			item_state_slots["w_uniform"] = "ww2_british_off_tropical"
			usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
			rolled = FALSE
			update_clothing_icon()
		else if (!rolled)
			item_state = "ww2_british_off_tropical_rolled"
			worn_state = "ww2_british_off_tropical_rolled"
			icon_state = "ww2_british_off_tropical_rolled"
			item_state_slots["w_uniform"] = "ww2_british_off_tropical_rolled"
			usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
			rolled = TRUE
			update_clothing_icon()

/obj/item/clothing/head/ww2/british_hat
	name = "british hat"
	desc = "A brown hat sometimes worn by british soldiers."
	icon_state = "ww2_aussie"
	item_state = "ww2_aussie"
	worn_state = "ww2_aussie"

/obj/item/clothing/head/ww2/british_tropical_hat
	name = "tropical british hat"
	desc = "A khaki hat worn by british soldiers in tropical climates."
	icon_state = "ww2_british_tropical"
	item_state = "ww2_british_tropical"
	worn_state = "ww2_british_tropical"

/obj/item/clothing/head/ww2/british_beret
	name = "british beret"
	desc = "A khaki beret worn by british soldiers."
	icon_state = "ww2_british_beret"
	item_state = "ww2_british_beret"
	worn_state = "ww2_british_beret"
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/obj/item/clothing/under/ww2/chiuni
	name = "chinese uniform"
	desc = "A chinese army uniform."
	icon_state = "ww2_china"
	item_state = "ww2_china"
	worn_state = "ww2_china"
	var/rolled = FALSE

/obj/item/clothing/under/ww2/chiuni/verb/roll_sleeves()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/under/ww2/chiuni)
		return
	else
		if (rolled)
			item_state = "ww2_china"
			icon_state = "ww2_china"
			worn_state = "ww2_china"
			item_state_slots["w_uniform"] = "ww2_china"
			usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
			rolled = FALSE
			update_clothing_icon()
		else if (!rolled)
			item_state = "ww2_china_rolled"
			worn_state = "ww2_china_rolled"
			icon_state = "ww2_china_rolled"
			item_state_slots["w_uniform"] = "ww2_china_rolled"
			usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
			rolled = TRUE
			update_clothing_icon()

/obj/item/clothing/under/ww2/chiuni_off
	name = "chinese uniform"
	desc = "A chinese army uniform."
	icon_state = "ww2_china_off"
	item_state = "ww2_china_off"
	worn_state = "ww2_china_off"
	var/rolled = FALSE

/obj/item/clothing/under/ww2/chiuni_off/verb/roll_sleeves()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/under/ww2/chiuni_off)
		return
	else
		if (rolled)
			item_state = "ww2_china_off"
			worn_state = "ww2_china_off"
			icon_state = "ww2_china_off"
			item_state_slots["w_uniform"] = "ww2_china_off"
			usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
			rolled = FALSE
			update_clothing_icon()
		else if (!rolled)
			item_state = "ww2_china_off_rolled"
			worn_state = "ww2_china_off_rolled"
			icon_state = "ww2_china_off_rolled"
			item_state_slots["w_uniform"] = "ww2_china_off_rolled"
			usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
			rolled = TRUE
			update_clothing_icon()

/obj/item/clothing/under/ww2/chiuni2
	name = "chinese uniform"
	desc = "A chinese army uniform."
	icon_state = "ww2_china2"
	item_state = "ww2_china2"
	worn_state = "ww2_china2"
	var/rolled = FALSE

/obj/item/clothing/under/ww2/chiuni2/verb/roll_sleeves()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/under/ww2/chiuni2)
		return
	else
		if (rolled)
			item_state = "ww2_china2"
			icon_state = "ww2_china2"
			worn_state = "ww2_china2"
			item_state_slots["w_uniform"] = "ww2_china2"
			usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
			rolled = FALSE
			update_clothing_icon()
		else if (!rolled)
			item_state = "ww2_china2_rolled"
			worn_state = "ww2_china2_rolled"
			icon_state = "ww2_china2_rolled"
			item_state_slots["w_uniform"] = "ww2_china2_rolled"
			usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
			rolled = TRUE
			update_clothing_icon()

/obj/item/clothing/under/ww2/chiuni2_off
	name = "chinese uniform"
	desc = "A chinese army uniform."
	icon_state = "ww2_china2_off"
	item_state = "ww2_china2_off"
	worn_state = "ww2_china2_off"
	var/rolled = FALSE

/obj/item/clothing/under/ww2/chiuni2_off/verb/roll_sleeves()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/under/ww2/chiuni2_off)
		return
	else
		if (rolled)
			item_state = "ww2_china_off"
			worn_state = "ww2_china_off"
			icon_state = "ww2_china_off"
			item_state_slots["w_uniform"] = "ww2_china_off"
			usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
			rolled = FALSE
			update_clothing_icon()
		else if (!rolled)
			item_state = "ww2_china_off_rolled"
			icon_state = "ww2_china_off_rolled"
			worn_state = "ww2_china_off_rolled"
			item_state_slots["w_uniform"] = "ww2_china_off_rolled"
			usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
			rolled = TRUE
			update_clothing_icon()

obj/item/clothing/head/ww2/chicap
	name = "chinese cap"
	desc = "A cap worn by the chinese army."
	icon_state = "fieldcap_china"
	item_state = "fieldcap_china"
	worn_state = "fieldcap_china"

obj/item/clothing/head/ww2/chicap2
	name = "chinese cap"
	desc = "A cap worn by the chinese army."
	icon_state = "fieldcap_china2"
	item_state = "fieldcap_china2"
	worn_state = "fieldcap_china2"

/obj/item/clothing/under/ww2/cra_uni
	name = "Chinese Red Army uniform"
	desc = "An uniform worn by the Chinese Red Army troops."
	icon_state = "cra_uni"
	item_state = "cra_uni"
	worn_state = "cra_uni"

obj/item/clothing/head/ww2/cra_cap
	name = "Chinese Red Army cap"
	desc = "A cap worn by the Chinese Red Army."
	icon_state = "cra_cap"
	item_state = "cra_cap"
	worn_state = "cra_cap"

///////////WW1 UNIFORMS///////////
/obj/item/clothing/under/ww1/german
	name = "german uniform"
	desc = "A german feldgrau uniform, used by the Imperial German Army."
	icon_state = "ww1_german"
	item_state = "ww1_german"
	worn_state = "ww1_german"

/obj/item/clothing/under/ww1/british
	name = "british uniform"
	desc = "A british khaki uniform, used by the Royal Army."
	icon_state = "ww1_british"
	item_state = "ww1_british"
	worn_state = "ww1_british"

/obj/item/clothing/under/ww1/trenchsuit
	name = "british uniform"
	desc = "A british khaki uniform, used by the army."
	icon_state = "trenchsuit"
	item_state = "trenchsuit"
	worn_state = "trenchsuit"

/obj/item/clothing/under/ww1/trenchsuit/poland //looks very similiar to the ww2 polish uniform so lets pretend that its the polish uniform
	name = "polish uniform"
	desc = "A polish uniform, used by the army."

/obj/item/clothing/under/ww1/french
	name = "french uniform"
	desc = "A french light blue uniform, used by the French Army."
	icon_state = "ww1_french"
	item_state = "ww1_french"
	worn_state = "ww1_french"


/obj/item/clothing/accessory/storage/webbing/ww1
	name = "webbing"
	desc = "two leather belts with small pouches for ammunition and grenades."
	icon_state = "german_vest"
	item_state = "german_vest"
	slots = 8
	New()
		..()
		hold.storage_slots = slots
		hold.can_hold = list(/obj/item/ammo_casing, /obj/item/ammo_magazine, /obj/item/weapon/grenade, /obj/item/weapon/attachment/bayonet,/obj/item/weapon/material/shovel/trench,/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen,/obj/item/weapon/reagent_containers/food/snacks/MRE,/obj/item/stack/medical/bruise_pack)

/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosin
	New()
		..()
		new/obj/item/stack/medical/bruise_pack/gauze(hold)
		new/obj/item/ammo_magazine/mosin(hold)
		new/obj/item/ammo_magazine/mosin(hold)
		new/obj/item/ammo_magazine/mosin(hold)
		new/obj/item/ammo_magazine/mosin(hold)
		new/obj/item/ammo_magazine/mosin(hold)

/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosinalt
	New()
		..()
		new/obj/item/stack/medical/bruise_pack/gauze(hold)
		new/obj/item/ammo_magazine/mosin(hold)
		new/obj/item/ammo_magazine/mosin(hold)
		new/obj/item/ammo_magazine/mosin(hold)
		new/obj/item/weapon/grenade/modern/f1(hold)

/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosinbay
	New()
		..()
		new/obj/item/stack/medical/bruise_pack/gauze(hold)
		new/obj/item/ammo_magazine/mosin(hold)
		new/obj/item/ammo_magazine/mosin(hold)
		new/obj/item/ammo_magazine/mosin(hold)
		new/obj/item/weapon/attachment/bayonet(hold)

/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/mosinaltsmoke
	New()
		..()
		new/obj/item/stack/medical/bruise_pack/gauze(hold)
		new/obj/item/ammo_magazine/mosin(hold)
		new/obj/item/ammo_magazine/mosin(hold)
		new/obj/item/ammo_magazine/mosin(hold)
		new/obj/item/weapon/grenade/smokebomb(hold)

/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/snipermosin
	New()
		..()
		new/obj/item/stack/medical/bruise_pack/gauze(hold)
		new/obj/item/ammo_magazine/mosin(hold)
		new/obj/item/ammo_magazine/mosin(hold)
		new/obj/item/ammo_magazine/mosinbox(hold)

/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/svt
	New()
		..()
		new/obj/item/stack/medical/bruise_pack/gauze(hold)
		new/obj/item/ammo_magazine/svt(hold)
		new/obj/item/ammo_magazine/svt(hold)
		new/obj/item/ammo_magazine/svt(hold)
		new/obj/item/ammo_magazine/svt(hold)
		new/obj/item/ammo_magazine/svt(hold)

/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/svt/frag
	New()
		..()
		new/obj/item/weapon/grenade/ww2/rgd33(hold)

/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/svtassault
	New()
		..()
		new/obj/item/stack/medical/bruise_pack/gauze(hold)
		new/obj/item/ammo_magazine/svt(hold)
		new/obj/item/ammo_magazine/mosinbox(hold)
		new/obj/item/ammo_magazine/svt(hold)
		new/obj/item/weapon/grenade/smokebomb(hold)

/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/ppsh
	New()
		..()
		new/obj/item/stack/medical/bruise_pack/gauze(hold)
		new/obj/item/ammo_magazine/c762x25_ppsh(hold)
		new/obj/item/ammo_magazine/c762x25_ppsh(hold)
		new/obj/item/ammo_magazine/c762x25_pps(hold)
		new/obj/item/ammo_magazine/c762x25_pps(hold)
		new/obj/item/ammo_magazine/c762x25_pps(hold)

/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/ppsh/grenade
	New()
		..()
		new/obj/item/weapon/grenade/ww2/rgd33(hold)

/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/ppshassault
	New()
		..()
		new/obj/item/stack/medical/bruise_pack/gauze(hold)
		new/obj/item/ammo_magazine/c762x25_ppsh(hold)
		new/obj/item/ammo_magazine/c762x25_ppsh(hold)
		new/obj/item/ammo_magazine/c762x25_ppsh(hold)
		new/obj/item/weapon/grenade/smokebomb(hold)
		new/obj/item/weapon/grenade/ww2/rgd33(hold)

/obj/item/clothing/accessory/storage/webbing/ww1/leather/ww2/dpgun
	New()
		..()
		new/obj/item/stack/medical/bruise_pack/gauze(hold)
		new/obj/item/ammo_magazine/dp(hold)
		new/obj/item/ammo_magazine/dp(hold)
		new/obj/item/ammo_magazine/dp(hold)
		new/obj/item/weapon/grenade/smokebomb(hold)

/obj/item/clothing/accessory/storage/webbing/ww1/ww2/stormgroup
	name = "Stormgroup Webbing"
	desc = "Specially made webbing used by stormgroups."
	slots = 9
	New()
		..()
		hold.can_hold = list(/obj/item/ammo_casing, /obj/item/ammo_magazine, /obj/item/weapon/grenade, /obj/item/weapon/attachment/bayonet,/obj/item/weapon/material/shovel/trench,/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen,/obj/item/weapon/reagent_containers/food/snacks/MRE,/obj/item/stack/medical/bruise_pack,/obj/item/weapon/gun/projectile/pistol)

obj/item/clothing/accessory/storage/webbing/ww1/ww2/stormgroup/svt
	New()
		..()
		new/obj/item/stack/medical/bruise_pack/gauze(hold)
		new/obj/item/ammo_magazine/svt(hold)
		new/obj/item/ammo_magazine/svt(hold)
		new/obj/item/ammo_magazine/mosinbox(hold)
		new/obj/item/ammo_magazine/svt(hold)
		new/obj/item/weapon/grenade/smokebomb(hold)
		new/obj/item/weapon/grenade/ww2/rgd33(hold)
		new/obj/item/weapon/compass(hold)
		new/obj/item/weapon/attachment/bayonet(hold)

obj/item/clothing/accessory/storage/webbing/ww1/ww2/stormgroup/Scout
	New()
		..()
		new/obj/item/stack/medical/bruise_pack/gauze(hold)
		new/obj/item/ammo_magazine/c762x25_ppsh(hold)
		new/obj/item/ammo_magazine/c762x25_ppsh(hold)
		new/obj/item/ammo_magazine/c762x25_ppsh(hold)
		new/obj/item/ammo_magazine/c762x25_ppsh(hold)
		new/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(hold)
		new/obj/item/weapon/grenade/ww2/rgd33(hold)
		new/obj/item/weapon/grenade/smokebomb(hold)
		new/obj/item/weapon/compass(hold)
		new/obj/item/weapon/attachment/bayonet(hold)

/obj/item/clothing/accessory/storage/webbing/russian
	name = "russian webbing"
	desc = "4 green poly pouches."
	icon_state = "russian_vest"
	item_state = "russian_vest"
	slots = 6
	New()
		..()
		hold.can_hold = list(/obj/item/ammo_casing, /obj/item/ammo_magazine, /obj/item/weapon/grenade, /obj/item/weapon/attachment/bayonet,/obj/item/weapon/material/shovel/trench,/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen,/obj/item/weapon/reagent_containers/food/snacks/MRE,/obj/item/stack/medical/bruise_pack)

/obj/item/clothing/accessory/storage/webbing/russian/guns
	New()
		..()
		new /obj/item/stack/medical/bruise_pack/gauze(hold)
/obj/item/clothing/accessory/storage/webbing/russian/guns/pkm
	New()
		..()
		new /obj/item/ammo_magazine/pkm/c100(hold)
		new /obj/item/ammo_magazine/pkm/c100(hold)
		new /obj/item/ammo_magazine/pkm/c100(hold)
		new /obj/item/ammo_magazine/pkm/c100(hold)
		new /obj/item/weapon/grenade/coldwar/rgd5(hold)
/obj/item/clothing/accessory/storage/webbing/russian/guns/rpk
	New()
		..()
		new /obj/item/ammo_magazine/rpk74/drum(hold)
		new /obj/item/ammo_magazine/rpk74(hold)
		new /obj/item/ammo_magazine/rpk74(hold)
		new /obj/item/ammo_magazine/rpk74(hold)
		new /obj/item/weapon/grenade/coldwar/rgd5(hold)
/obj/item/clothing/accessory/storage/webbing/russian/guns/rpd
	New()
		..()
		new /obj/item/ammo_magazine/rpd(hold)
		new /obj/item/ammo_magazine/rpd(hold)
		new /obj/item/ammo_magazine/rpd(hold)
		new /obj/item/weapon/grenade/coldwar/rgd5(hold)
/obj/item/clothing/accessory/storage/webbing/russian/guns/ak47
	New()
		..()
		new /obj/item/ammo_magazine/ak47(hold)
		new /obj/item/ammo_magazine/ak47(hold)
		new /obj/item/ammo_magazine/ak47(hold)

/obj/item/clothing/accessory/storage/webbing/ww1/german
	name = "german webbing"
	icon_state = "german_vest"
	item_state = "german_vest"

/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2
	New()
		..()
		new/obj/item/stack/medical/bruise_pack/gauze(hold)

/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98
	New()
		..()
		new/obj/item/ammo_magazine/gewehr98(hold)
		new/obj/item/ammo_magazine/gewehr98(hold)
		new/obj/item/ammo_magazine/gewehr98(hold)
		new/obj/item/ammo_magazine/gewehr98(hold)

/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98/assault
	New()
		..()
		new/obj/item/ammo_magazine/gewehr98(hold)
		new/obj/item/weapon/grenade/modern/stg1915(hold)
		new/obj/item/weapon/grenade/smokebomb(hold)

/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98/smoke
	New()
		..()
		new/obj/item/ammo_magazine/gewehr98(hold)
		new/obj/item/weapon/grenade/smokebomb(hold)

/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/mg34
	New()
		..()
		new/obj/item/ammo_magazine/mg34(hold)
		new/obj/item/ammo_magazine/mg34(hold)
		new/obj/item/ammo_magazine/mg34(hold)
		new/obj/item/ammo_magazine/mg34(hold)
		new/obj/item/weapon/grenade/smokebomb(hold)

/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/gewehr98/sniper
	New()
		..()
		new/obj/item/ammo_magazine/gewehr98box(hold)
		new/obj/item/weapon/grenade/smokebomb(hold)

/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/mauser
	New()
		..()
		new/obj/item/ammo_magazine/mauser(hold)
		new/obj/item/ammo_magazine/mauser(hold)
		new/obj/item/ammo_magazine/mauser(hold)
		new/obj/item/ammo_magazine/mauser(hold)

/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/mp40
	New()
		..()
		new/obj/item/ammo_magazine/mp40(hold)
		new/obj/item/ammo_magazine/mp40(hold)
		new/obj/item/ammo_magazine/mp40(hold)
		new/obj/item/ammo_magazine/mp40(hold)

/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/mp40assault
	New()
		..()
		new/obj/item/ammo_magazine/mp40(hold)
		new/obj/item/ammo_magazine/mp40(hold)
		new/obj/item/ammo_magazine/mp40(hold)
		new/obj/item/ammo_magazine/mp40(hold)
		new/obj/item/weapon/grenade/ww2/stg1924(hold)

/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/fg42
	New()
		..()
		new/obj/item/ammo_magazine/fg42(hold)
		new/obj/item/ammo_magazine/fg42(hold)
		new/obj/item/ammo_magazine/fg42/small(hold)
		new/obj/item/ammo_magazine/fg42/small(hold)
		new/obj/item/ammo_magazine/fg42/small(hold)

/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/g43
	New()
		..()
		new/obj/item/ammo_magazine/g43(hold)
		new/obj/item/ammo_magazine/g43(hold)
		new/obj/item/ammo_magazine/g43(hold)
		new/obj/item/ammo_magazine/g43(hold)

/obj/item/clothing/accessory/storage/webbing/ww1/german/ww2/stg
	New()
		..()
		new/obj/item/ammo_magazine/stg(hold)
		new/obj/item/ammo_magazine/stg(hold)
		new/obj/item/ammo_magazine/stg(hold)
		new/obj/item/ammo_magazine/stg(hold)
		new/obj/item/weapon/grenade/modern/stg1915(hold)
		new/obj/item/weapon/grenade/antitank/stg24_bundle(hold)

/obj/item/clothing/accessory/storage/webbing/ww1/french
	name = "french webbing"
	icon_state = "french_vest"
	item_state = "french_vest"

/obj/item/clothing/accessory/storage/webbing/ww1/british
	name = "british webbing"
	icon_state = "british_vest"
	item_state = "british_vest"

/obj/item/clothing/accessory/storage/webbing/ww1/leather
	name = "leather webbing"
	icon_state = "british_vest"
	item_state = "british_vest"

/obj/item/clothing/accessory/armor/modern
	health = 20
/obj/item/clothing/accessory/armor/modern/plate
	name = "breastplate body armor"
	desc = "Wearable armor made of steel sheets."
	icon = 'icons/obj/clothing/ties.dmi'
	icon_state = "modern_platearmor"
	item_state = "modern_platearmor"
	worn_state = "modern_platearmor"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 70, arrow = 95, gun = 45, energy = 15, bomb = 45, bio = 20, rad = 20)
	value = 50
	slowdown = 0.8

/obj/item/clothing/accessory/armor/modern/british
	name = "Dayfield body armor"
	desc = "British-made wearable armor made of steel sheets."
	icon = 'icons/obj/clothing/ties.dmi'
	icon_state = "modern_dayfield"
	item_state = "modern_dayfield"
	worn_state = "modern_dayfield"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 70, arrow = 90, gun = 40, energy = 12, bomb = 40, bio = 20, rad = 15)
	value = 50
	slowdown = 0.8

///////////////other////////////////

/obj/item/clothing/accessory/armor/modern/lightplate
	name = "light breastplate body armor"
	desc = "Wearable light armor made of steel sheets."
	icon = 'icons/obj/clothing/ties.dmi'
	icon_state = "modern_armorvest"
	item_state = "modern_armorvest"
	worn_state = "modern_armorvest"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 50, arrow = 95, gun = 35, energy = 15, bomb = 45, bio = 20, rad = 20)
	value = 50
	slowdown = 0.6
	health = 50

/obj/item/clothing/accessory/armor/modern/lightplate/lead
	name = "green lead breastplate body armor"
	desc = "Wearable breastplate armor made out of steel sheets and lead."
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 60, arrow = 95, gun = 35, energy = 15, bomb = 45, bio = 20, rad = 60)
	value = 50
	slowdown = 0.8
	health = 50

/obj/item/clothing/accessory/armor/modern/lightplate/black
	name = "light black breastplate body armor"
	desc = "Wearable light armor made of steel sheets."
	icon = 'icons/obj/clothing/ties.dmi'
	icon_state = "modern_blackvest"
	item_state = "modern_blackvest"
	worn_state = "modern_blackvest"

/obj/item/clothing/accessory/armor/modern/lightplate/black/lead
	name = "Lead breastplate body armor"
	desc = "Wearable breastplate armor made out of steel sheets and lead."
	body_parts_covered = UPPER_TORSO|LOWER_TORSO
	armor = list(melee = 60, arrow = 95, gun = 35, energy = 15, bomb = 45, bio = 20, rad = 60)
	value = 50
	slowdown = 0.8
	health = 50

////////////////////////////////////
///////////////WW2//////////////////
////////////////////////////////////
/obj/item/clothing/under/ww2/german
	name = "german uniform"
	desc = "A german feldgrau uniform, used by the Wehrmacht."
	icon_state = "geruni_ww2"
	item_state = "geruni_ww2"
	worn_state = "geruni_ww2"
	var/rolled = FALSE
/*
/obj/item/clothing/under/ww2/german/New()
	..()
	if (map && (map.ID == MAP_STALINGRAD || map.ID == MAP_SMALLINGRAD))
		icon_state = "geruni_ww2_winter"
		item_state = "geruni_ww2_winter"
		worn_state = "geruni_ww2_winter"
		item_state_slots["slot_w_uniform"] = "geruni_ww2_winter"
*/
/obj/item/clothing/under/ww2/german/verb/roll_sleeves()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/under/ww2/german)
		return
	else
/*
		if (map && (map.ID == MAP_STALINGRAD || map.ID == MAP_SMALLINGRAD))
			if (rolled)
				item_state = "geruni_ww2_winter"
				worn_state = "geruni_ww2_winter"
				item_state_slots["slot_w_uniform"] = "geruni_ww2_winter"
				usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
				rolled = FALSE
			else if (!rolled)
				item_state = "geruni_ww2_winter_rolled"
				worn_state = "geruni_ww2_winter_rolled"
				item_state_slots["slot_w_uniform"] = "geruni_ww2_winter_rolled"
				usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
				rolled = TRUE
		else
*/
		if (rolled)
			worn_state = "geruni_ww2"
			item_state = "geruni_ww2"
			icon_state = "geruni_ww2"
			item_state_slots["w_uniform"] = "geruni_ww2"
			usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
			rolled = FALSE
			cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
			update_clothing_icon()
		else if (!rolled)
			worn_state = "geruni_ww2_rolled"
			item_state = "geruni_ww2_rolled"
			icon_state = "geruni_ww2_rolled"
			item_state_slots["w_uniform"] = "geruni_ww2_rolled"
			usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
			rolled = TRUE
			heat_protection = ARMS
			cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS
			update_clothing_icon()

/obj/item/clothing/under/ww2/german_doctor
	name = "german doctor uniform"
	desc = "A german feldgrau uniform, used by doctors in the Wehrmacht."
	icon_state = "geruni_doctor"
	item_state = "geruni_doctor"
	worn_state = "geruni_doctor"
	var/rolled = FALSE

/obj/item/clothing/under/ww2/german_doctor/verb/roll_sleeves()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/under/ww2/german_doctor)
		return
	else
		if (rolled)
			worn_state = "geruni_doctor"
			item_state = "geruni_doctor"
			icon_state = "geruni_doctor"
			item_state_slots["w_uniform"] = "geruni_doctor"
			usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
			rolled = FALSE
			cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
			update_clothing_icon()
		else if (!rolled)
			worn_state = "geruni_doctor_rolled"
			item_state = "geruni_doctor_rolled"
			icon_state = "geruni_doctor_rolled"
			item_state_slots["w_uniform"] = "geruni_doctor_rolled"
			usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
			rolled = TRUE
			heat_protection = ARMS
			cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS
			update_clothing_icon()

/obj/item/clothing/under/ww2/german_officer
	name = "german officer uniform"
	desc = "A german feldgrau uniform, used by officers in the Wehrmacht."
	icon_state = "geruni_officer"
	item_state = "geruni_officer"
	worn_state = "geruni_officer"

/obj/item/clothing/under/ww2/german_tanker
	name = "german tanker uniform"
	desc = "A german feldgrau uniform, used by tankers in the Wehrmacht."
	icon_state = "gertanker"
	item_state = "gertanker"
	worn_state = "gertanker"

/obj/item/clothing/under/ww2/german_mp
	name = "german mp uniform"
	desc = "A german feldgrau uniform, used by military police in the Wehrmacht."
	icon_state = "geruni_mp"
	item_state = "geruni_mp"
	worn_state = "geruni_mp"

/obj/item/clothing/under/ww2/german_ss
	name = "german ss uniform"
	desc = "A german SS uniform, used by soldaten in the Schutzstaffel."
	icon_state = "ssuni"
	item_state = "ssuni"
	worn_state = "ssuni"

/obj/item/clothing/under/ww2/german_ss_officer
	name = "german ss officer uniform"
	desc = "A german SS officer uniform, used by officers in the Schutzstaffel."
	icon_state = "ssuni_officer"
	item_state = "ssuni_officer"
	worn_state = "ssuni_officer"

/obj/item/clothing/under/ww2/german_ss_camo
	name = "german camo ss uniform"
	desc = "A german SS uniform, in 1944 Erbsenmuster dot pattern."
	icon_state = "ssuni_camo"
	item_state = "ssuni_camo"
	worn_state = "ssuni_camo"

/obj/item/weapon/storage/ammo_can
	name = "ammunition can"
	desc = "It's a metal box designed for easy carrying of ammo."
	icon_state = "ammo_can"
	item_state = "ammo_can"
	worn_state = "ammo_can"
	throw_speed = 2
	throw_range = 8
	max_storage_space = 14
	max_w_class = 4
	slot_flags = SLOT_BELT | SLOT_BACK
	can_hold = list(
		/obj/item/ammo_magazine,
		/obj/item/ammo_casing,
		/obj/item/weapon/key,
		)
/obj/item/weapon/storage/ammo_can/german_mg
/obj/item/weapon/storage/ammo_can/german_mg/New()
	..()
	new/obj/item/ammo_magazine/mg34belt(src)
	new/obj/item/ammo_magazine/mg34belt(src)
	new/obj/item/ammo_magazine/mg34belt(src)
	new/obj/item/ammo_magazine/mg34belt(src)

/obj/item/weapon/storage/ammo_can/german_mg_drum
/obj/item/weapon/storage/ammo_can/german_mg_drum/New()
	..()
	new/obj/item/ammo_magazine/mg34(src)
	new/obj/item/ammo_magazine/mg34(src)
	new/obj/item/ammo_magazine/mg34(src)
	new/obj/item/ammo_magazine/mg34(src)
	new/obj/item/ammo_magazine/mg34(src)
	new/obj/item/ammo_magazine/mg34(src)

/obj/item/weapon/storage/ammo_can/american_bar
/obj/item/weapon/storage/ammo_can/american_bar/New()
	..()
	new/obj/item/ammo_magazine/bar(src)
	new/obj/item/ammo_magazine/bar(src)
	new/obj/item/ammo_magazine/bar(src)
	new/obj/item/ammo_magazine/bar(src)
	new/obj/item/ammo_magazine/bar(src)
	new/obj/item/ammo_magazine/bar(src)

/obj/item/weapon/storage/ammo_can/american_mg
/obj/item/weapon/storage/ammo_can/american_mg/New()
	..()
	new/obj/item/ammo_magazine/browning(src)
	new/obj/item/ammo_magazine/browning(src)
	new/obj/item/ammo_magazine/browning(src)
	new/obj/item/ammo_magazine/browning(src)

/obj/item/weapon/storage/ammo_can/ak74
/obj/item/weapon/storage/ammo_can/ak74/New()
	..()
	new/obj/item/ammo_magazine/ak74(src)
	new/obj/item/ammo_magazine/ak74(src)
	new/obj/item/ammo_magazine/ak74(src)
	new/obj/item/ammo_magazine/ak74(src)
	new/obj/item/ammo_magazine/ak74(src)
	new/obj/item/ammo_magazine/ak74(src)

/obj/item/weapon/storage/ammo_can/stanag
/obj/item/weapon/storage/ammo_can/stanag/New()
	..()
	new/obj/item/ammo_magazine/m16(src)
	new/obj/item/ammo_magazine/m16(src)
	new/obj/item/ammo_magazine/m16(src)
	new/obj/item/ammo_magazine/m16/box(src)
	new/obj/item/ammo_magazine/m16/box(src)

/obj/item/weapon/storage/ammo_can/dp
/obj/item/weapon/storage/ammo_can/dp/New()
	..()
	new/obj/item/ammo_magazine/dp(src)
	new/obj/item/ammo_magazine/dp(src)
	new/obj/item/ammo_magazine/dp(src)
	new/obj/item/ammo_magazine/dp(src)
	new/obj/item/ammo_magazine/dp(src)
	new/obj/item/ammo_magazine/dp(src)

/obj/item/clothing/under/ww2/soviet
	name = "soviet uniform"
	desc = "A soviet uniform, used by infantry in the Red Army."
	icon_state = "sovuni"
	item_state = "sovuni"
	worn_state = "sovuni"
	var/rolled = FALSE
/obj/item/clothing/under/ww2/soviet/update_icon()
	if (ishuman(loc))
		var/mob/living/human/H = loc
		if (H.gender == "female")
			worn_state = "sovuni_f"
		else
			worn_state = "sovuni"
/obj/item/clothing/under/ww2/soviet/verb/roll_sleeves()
	set category = null
	set src in usr
	if (type != /obj/item/clothing/under/ww2/soviet)
		return
	else
		if (rolled && usr.gender == "male")
			item_state = "sovuni"
			worn_state = "sovuni"
			icon_state = "sovuni"
			item_state_slots["w_uniform"] = "sovuni"
			usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
			rolled = FALSE
			cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
			update_clothing_icon()
		else if (!rolled && usr.gender == "male")
			item_state = "sovuni_rolled"
			worn_state = "sovuni_rolled"
			icon_state = "sovuni_rolled"
			item_state_slots["w_uniform"] = "sovuni_rolled"
			usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
			rolled = TRUE
			heat_protection = ARMS
			cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS
			update_clothing_icon()
		if (rolled && usr.gender == "female")
			item_state = "sovuni"
			worn_state = "sovuni_f"
			icon_state = "sovuni"
			item_state_slots["w_uniform"] = "sovuni"
			usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
			rolled = FALSE
			cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
			update_clothing_icon()
		else if (!rolled && usr.gender == "female")
			item_state = "sovuni_rolled"
			worn_state = "sovuni_rolled_f"
			icon_state = "sovuni_rolled"
			item_state_slots["w_uniform"] = "sovuni_rolled"
			usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
			rolled = TRUE
			heat_protection = ARMS
			cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS
			update_clothing_icon()

/obj/item/clothing/under/ww2/soviet_tanker
	name = "soviet tanker uniform"
	desc = "A soviet tanker uniform, used by tank crewmen in the red army."
	icon_state = "sovtanker"
	item_state = "sovtanker"
	worn_state = "sovtanker"

/obj/item/clothing/under/ww2/soviet_officer
	name = "soviet officer uniform"
	desc = "A soviet officer uniform, used by officers in the red army."
	icon_state = "sovuni_officer"
	item_state = "sovuni_officer"
	worn_state = "sovuni_officer"

/obj/item/clothing/under/ww2/soviet_nkvd
	name = "NKVD uniform"
	desc = "A soviet nkvd uniform, used by nkvd."
	icon_state = "nkvd_uni"
	item_state = "nkvd_uni"
	worn_state = "nkvd_uni"

/obj/item/clothing/under/ww2/soviet_berezka
	name = "soviet berezka uniform"
	desc = "A soviet berezka uniform, adapted to the winter wilderness."
	icon_state = "berezka"
	item_state = "berezka"
	worn_state = "berezka"

/obj/item/clothing/under/ww2/soviet_amoeba
	name = "soviet amoeba outfit"
	desc = "A soviet camouflage outfit, concieved for reconnaissance units."
	icon_state = "amoeba"
	item_state = "amoeba"
	worn_state = "amoeba"

/obj/item/clothing/under/ww2/soviet_amoeba/winter
	name = "soviet winter amoeba outfit"
	desc = "A soviet camouflage outfit, concieved for reconnaissance units."
	icon_state = "amoebaw"
	item_state = "amoebaw"
	worn_state = "amoebaw"

/obj/item/clothing/shoes/jackboots/soviet
	name = "soviet sapogi boots"
	desc = "Jackboots of soviet origin. Also known as 'Yuftevyje sapogi'."
	icon_state = "sovietboots"
	item_state = "sovietboots"
	worn_state = "sovietboots"

/obj/item/clothing/under/ww2/civ1
	name = "green civilian outfit"
	desc = "A mid 20th-century civilian outfit."
	icon_state = "ww2_civuni1"
	item_state = "ww2_civuni1"
	worn_state = "ww2_civuni1"

/obj/item/clothing/under/ww2/civ2
	name = "brown civilian outfit"
	desc = "A mid 20th-century civilian outfit."
	icon_state = "ww2_civuni2"
	item_state = "ww2_civuni2"
	worn_state = "ww2_civuni2"

/obj/item/clothing/under/ww2/hitlerjugend
	name = "Hitlerjugend outfit"
	desc = "The standard uniform of the HJ."
	icon_state = "hj_uni"
	icon_state = "hj_uni"
	icon_state = "hj_uni"


///////////////////////////////////////////////////UNITED STATES/////////////////////////////////////////
/obj/item/clothing/under/ww2/us
	name = "american uniform"
	desc = "An american uniform, used by soldiers in the US army during WW2."
	icon_state = "usuni2"
	item_state = "usuni2"
	worn_state = "usuni2"

/obj/item/clothing/under/ww2/us_tanker
	name = "american tanker uniform"
	desc = "An american uniform, used by tankers in the US army."
	icon_state = "ustanker"
	item_state = "ustanker"
	worn_state = "ustanker"

/obj/item/clothing/under/ww2/us_navy
	name = "U.S. Navy uniform"
	desc = "An american uniform, used by sailors in the US navy during WW2."
	icon_state = "us_navy"
	item_state = "us_navy"
	worn_state = "us_navy"

/obj/item/clothing/under/ww2/us_cap
	name = "american captain uniform"
	desc = "An american uniform, used by captains in the US army."
	icon_state = "usuni_cap"
	item_state = "usuni_cap"
	worn_state = "usuni_cap"

/obj/item/clothing/under/ww2/us_mp
	name = "american mp uniform"
	desc = "An american uniform, used by Military Police in the US army."
	icon_state = "usuni_mp"
	item_state = "usuni_mp"
	worn_state = "usuni_mp"

/obj/item/clothing/under/ww2/us_shirtless
	name = "american uniform with shirt"
	desc = "An american uniform, used by soldiers in the US army, this one has no jacket."
	icon_state = "us_shirtless"
	item_state = "us_shirtless"
	worn_state = "us_shirtless"

/obj/item/clothing/accessory/storage/webbing/us_ww2
	name = "US webbing"
	desc = "A khaki canvas pouch rig with 10 pouches total for ammo and other various items"
	icon_state = "us_webbing"
	item_state = "us_webbing"
	New()
		..()
		hold.storage_slots = slots
		hold.can_hold = list(/obj/item/weapon/material/kitchen/utensil,/obj/item/weapon/key,/obj/item/ammo_casing, /obj/item/ammo_magazine, /obj/item/weapon/grenade,/obj/item/weapon/attachment,/obj/item/weapon/handcuffs,/obj/item/stack/medical/bruise_pack)

/obj/item/clothing/accessory/storage/webbing/us_ww2/garand
	New()
		..()
		new /obj/item/stack/medical/bruise_pack/gauze(hold)
		new /obj/item/ammo_magazine/garand(hold)
		new /obj/item/ammo_magazine/garand(hold)
		new /obj/item/ammo_magazine/garand(hold)
		new /obj/item/ammo_magazine/garand(hold)
		new /obj/item/ammo_magazine/garand(hold)
		new /obj/item/ammo_magazine/garand(hold)
		new /obj/item/ammo_magazine/garand(hold)
		new /obj/item/ammo_magazine/garand(hold)
		new /obj/item/ammo_magazine/garand(hold)
		new /obj/item/ammo_magazine/garand(hold)
////////////////////////////////////////////////////////////////////////
/obj/item/clothing/under/ww2/finnish
	name = "finnish uniform"
	desc = "A finnish winter uniform."
	icon_state = "geruni_ww2_winter"
	item_state = "geruni_ww2_winter"
	worn_state = "geruni_ww2_winter"

/obj/item/clothing/suit/storage/coat/ww2/german
	name = "german parka"
	desc = "A german parka, worn by soldaten in the Wehrmacht."
	icon_state = "gerparka"
	item_state = "gerparka"
	worn_state = "gerparka"
	body_parts_covered = UPPER_TORSO||ARMS
	cold_protection = UPPER_TORSO|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 25)
	value = 65

/obj/item/clothing/suit/storage/coat/ww2/german/winter
	icon_state = "gerparka_winter"
	item_state = "gerparka_winter"
	worn_state = "gerparka_winter"
	name = "german winter coat"
	desc = "A german coat, worn by soldaten in the Wehrmacht."
	body_parts_covered = UPPER_TORSO||ARMS
	cold_protection = UPPER_TORSO|ARM_LEFT|ARM_RIGHT|LOWER_TORSO

/obj/item/clothing/suit/storage/coat/ww2/german/civ
	name = "grey parka"
	desc = "A grey parka, good for warmth in the winters."

/obj/item/clothing/suit/storage/coat/ww2/german_officer
	name = "german officer coat"
	desc = "A german officer's coat, worn by officers in the Wehrmacht."
	icon_state = "ger_offcoat"
	item_state = "ger_offcoat"
	worn_state = "ger_offcoat"
	body_parts_covered = UPPER_TORSO||ARMS
	cold_protection = UPPER_TORSO|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 25)
	value = 100

/obj/item/clothing/suit/storage/coat/ww2/ss_parka
	name = "ss parka"
	desc = "A german ss parka, in 1944 Erbsenmuster dot camo, worn by soldaten in the Schutzstaffel."
	icon_state = "sssmock"
	item_state = "sssmock"
	worn_state = "sssmock"
	body_parts_covered = UPPER_TORSO||ARMS
	cold_protection = UPPER_TORSO|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 25)
	value = 65

/obj/item/clothing/suit/storage/coat/ww2/soviet
	name = "soviet coat"
	desc = "A soviet trenchcoat, worn by krasarmanev in the red army."
	icon_state = "ruscoat"
	item_state = "ruscoat"
	worn_state = "ruscoat"
	body_parts_covered = UPPER_TORSO||ARMS
	cold_protection = UPPER_TORSO|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 25)
	value = 65


/obj/item/clothing/suit/storage/coat/ww2/sovcoat
	name = "soviet winter coat"
	desc = "A traditional Soviet coat, in dark yellow."
	icon_state = "gulagguard"
	item_state = "gulagguard"
	worn_state = "gulagguard"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 30)
	value = 65
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT

/obj/item/clothing/suit/storage/coat/ww2/sovcoat2
	name = "soviet winter coat"
	desc = "A traditional Soviet coat, in light blue."
	icon_state = "gulagprisoner1"
	item_state = "gulagprisoner1"
	worn_state = "gulagprisoner1"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 30)
	value = 65
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	New()
		..()
		icon_state = "gulagprisoner[rand(1,3)]"
		item_state = icon_state
		worn_state = icon_state

/obj/item/clothing/suit/storage/coat/ww2/soviet_officer
	name = "soviet officer coat"
	desc = "A soviet trenchcoat, worn by officers in the red army."
	icon_state = "sov_offcoat"
	item_state = "sov_offcoat"
	worn_state = "sov_offcoat"
	body_parts_covered = UPPER_TORSO||ARMS
	cold_protection = UPPER_TORSO|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 25)
	value = 65

/obj/item/clothing/head/helmet/ww2/us_mp
	name = "us mp helmet"
	desc = "A typical rounded steel helmet. This one has the markings of MP on it."
	icon_state = "m1_mp_white"
	item_state = "m1_mp_white"
	worn_state = "m1_mp_white"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/ww2/us_nco_cap
	name = "us nco cap"
	desc = "A cap worn by american NCO's."
	icon_state = "usnco_cap"
	item_state = "usnco_cap"
	worn_state = "usnco_cap"

/obj/item/clothing/head/ww2/us_tanker
	name = "US tanker cap"
	desc = "A cap worn by american tankers."
	icon_state = "ustanker"
	item_state = "ustanker"
	worn_state = "ustanker"
	flags = CONDUCT

/obj/item/clothing/head/ww2/us_sailor_hat
	name = "us sailor hat"
	desc = "A hat worn by american sailors."
	icon_state = "sailor_hat"
	item_state = "sailor_hat"
	worn_state = "sailor_hat"

/obj/item/clothing/head/ww2/german_tanker
	name = "german tanker headset"
	desc = "A cap and radio headset worn by german tank crewmen of the Wehrmacht."
	icon_state = "gertanker"
	item_state = "gertanker"
	worn_state = "gertanker"
	flags = CONDUCT

/obj/item/clothing/head/ww2/soviet_tanker
	name = "soviet tanker cap"
	desc = "A cap worn by soviet tank crewmen."
	icon_state = "sovtanker"
	item_state = "sovtanker"
	worn_state = "sovtanker"
/obj/item/clothing/head/ww2/soviet_tanker/New()
	..()
	if (map.ordinal_age >= 8)
		name = "russian tanker cap"
		desc = "A cap worn by russian tank crewmen."

/obj/item/clothing/head/ww2/ger_officercap
	name = "german officer cap"
	desc = "A cap and worn by german officers the Wehrmacht."
	icon_state = "ger_officercap"
	item_state = "ger_officercap"
	worn_state = "ger_officercap"

/obj/item/clothing/head/ww2/ger_officercap_tanker
	name = "german panzer officer cap"
	desc = "A cap and worn by german officers the tank corps of the Wehrmacht."
	icon_state = "ger_officercap_tanker"
	item_state = "ger_officercap_tanker"
	worn_state = "ger_officercap_tanker"
	flags = CONDUCT

/obj/item/clothing/head/ww2/sov_officercap
	name = "soviet officer cap"
	desc = "A cap and worn by soviet officers the red army."
	icon_state = "sov_officercap"
	item_state = "sov_officercap"
	worn_state = "sov_officercap"

/obj/item/clothing/head/ww2/sov_pilotka
	name = "soviet pilotka"
	desc = "A cap and worn by soviet soldiers of the red army."
	icon_state = "sovpilotka"
	item_state = "sovpilotka"
	worn_state = "sovpilotka"

/obj/item/clothing/head/ww2/sov_ushanka
	name = "soviet ushanka"
	desc = "A soviet ushanka, used by soldiers in the red army."
	icon_state = "ushanka_up"
	item_state = "ushanka_up"
	worn_state = "ushanka_up"
	flags_inv = BLOCKHEADHAIR

/obj/item/clothing/head/ww2/sov_ushanka/down
	icon_state = "ushanka"
	item_state = "ushanka"
	worn_state = "ushanka"

/obj/item/clothing/head/ww2/sov_ushanka/attack_self(mob/user as mob)
	if (icon_state == "ushanka")
		icon_state = "ushanka_up"
		item_state = "ushanka_up"
		user << "You raise the ear flaps on the ushanka."
	else
		icon_state = "ushanka"
		item_state = "ushanka"
		user << "You lower the ear flaps on the ushanka."

/obj/item/clothing/head/ww2/sov_ushanka/nomads
	name = "ushanka"
	desc = "A warm ushanka, often used by citizens & soldiers in cold climates."
	icon_state = "ushanka_plain_up"
	item_state = "ushanka_plain_up"
	cold_protection = HEAD|FACE

/obj/item/clothing/head/ww2/sov_ushanka/nomads/down
	icon_state = "ushanka_plain"
	item_state = "ushanka_plain"
	worn_state = "ushanka_plain"

/obj/item/clothing/head/ww2/sov_ushanka/nomads/attack_self(mob/user as mob)
	if (icon_state == "ushanka")
		icon_state = "ushanka_plain_up"
		item_state = "ushanka_plain_up"
		user << "You raise the ear flaps on the ushanka."
	else
		icon_state = "ushanka_plain"
		item_state = "ushanka_plain"
		user << "You lower the ear flaps on the ushanka."

/obj/item/clothing/head/ww2/nkvd_cap
	name = "NKVD cap"
	desc = "A cap and worn by NKVD."
	icon_state = "nkvd_cap"
	item_state = "nkvd_cap"
	worn_state = "nkvd_cap"

/obj/item/clothing/head/ww2/ss_cap
	name = "SS cap"
	desc = "A cap and worn by officers in the Schutzstaffel."
	icon_state = "sscap"
	item_state = "sscap"
	worn_state = "sscap"

/obj/item/clothing/head/ww2/german_fieldcap
	name = "german field cap"
	desc = "A cap and worn by german Wehrmacht."
	icon_state = "fieldcap1"
	item_state = "fieldcap1"
	worn_state = "fieldcap1"

/obj/item/clothing/head/ww2/german_fieldcap/New()
	..()
	if (map && (map.ID == MAP_STALINGRAD || map.ID == MAP_SMALLINGRAD))
		var/randhead = rand(1,2)
		if (randhead == 1)
			icon_state = "fieldcap1_winter"
			item_state = "fieldcap1_winter"
			worn_state = "fieldcap1_winter"
			item_state_slots["slot_w_uniform"] = "fieldcap1_winter"
		else if (randhead == 2)
			icon_state = "fieldcap1_winter2"
			item_state = "fieldcap1_winter2"
			worn_state = "fieldcap1_winter2"
			item_state_slots["slot_w_uniform"] = "fieldcap1_winter2"

/obj/item/clothing/head/ww2/soviet_fieldcap
	name = "soviet field cap"
	desc = "A cap and worn by soviets in the red army."
	icon_state = "fieldcap2"
	item_state = "fieldcap2"
	worn_state = "fieldcap2"

/obj/item/clothing/head/helmet/ww2/gerhelm
	name = "german stahlhelm"
	desc = "The typical rounded steel helmet of the Wehrmacht"
	icon_state = "stahlhelm"
	item_state = "stahlhelm"
	worn_state = "stahlhelm"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww2/gerhelm/New()
	..()
	if (map && (map.ID == MAP_STALINGRAD || map.ID == MAP_SMALLINGRAD))
		var/randhead = rand(1,2)
		if (randhead == 1)
			icon_state = "gerhelm_winter"
			item_state = "gerhelm_winter"
			worn_state = "gerhelm_winter"
			item_state_slots["slot_w_uniform"] = "gerhelm_winter"
		else if (randhead == 2)
			icon_state = "gerhelm_winter2"
			item_state = "gerhelm_winter2"
			worn_state = "gerhelm_winter2"
			item_state_slots["slot_w_uniform"] = "gerhelm_winter2"

/obj/item/clothing/head/helmet/ww2/gerhelm/winter
	name = "german stahlhelm"
	desc = "The typical rounded steel helmet of the Wehrmacht"
	icon_state = "gerhelm_winter"
	item_state = "gerhelm_winter"
	worn_state = "gerhelm_winter"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww2/gerhelm_medic
	name = "german medic stahlhelm"
	desc = "The typical rounded steel helmet of the Wehrmacht, this one belonging to a medic."
	icon_state = "gerhelm_medic"
	item_state = "gerhelm_medic"
	worn_state = "gerhelm_medic"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww2/gerhelm_mp
	name = "german stahlhelm"
	desc = "The typical rounded steel helmet of the Wehrmacht, this one specifically for MP's."
	icon_state = "gerhelm_mp"
	item_state = "gerhelm_mp"
	worn_state = "gerhelm_mp"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww2/ss
	name = "german ss helmet"
	desc = "The typical rounded steel helmet of the Schutzstaffel. This one is prepared with camo."
	icon_state = "sshelm"
	item_state = "sshelm"
	worn_state = "sshelm"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 42, arrow = 32, gun = 12, energy = 15, bomb = 42, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww2/ss/dark
	name = "german ss helmet"
	desc = "The typical rounded steel helmet of the Schutzstaffel."
	icon_state = "sshelm_dark"
	item_state = "sshelm_dark"
	worn_state = "sshelm_dark"

/obj/item/clothing/head/helmet/ww2/soviet
	name = "soviet helmet"
	desc = "The typical rounded steel helmet of the red army."
	icon_state = "sovhelm"
	item_state = "sovhelm"
	worn_state = "sovhelm"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)
/obj/item/clothing/head/helmet/ww2/soviet/New()
	..()
	if (map && (map.ID == MAP_STALINGRAD || map.ID == MAP_SMALLINGRAD))
		icon_state = "sovhelm_winter"
		item_state = "sovhelm_winter"
		worn_state = "sovhelm_winter"
		item_state_slots["sovhelm_winter"] = "sovhelm_winter"

/obj/item/clothing/head/helmet/ww2/soviet/winter
	icon_state = "sovhelm_winter"
	item_state = "sovhelm_winter"
	worn_state = "sovhelm_winter"

/obj/item/clothing/head/helmet/ww2/usm1
	name = "M1 Helmet"
	desc = "The typical rounded steel helmet of the US Army."
	icon_state = "m1_standard"
	item_state = "m1_standard"
	worn_state = "m1_standard"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww2/usm1/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return//I really don't understand why this check is needed
	if (istype(W, /obj/item/stack/material/rope))
		playsound(loc, 'sound/machines/click.ogg', 75, TRUE)
		user << "<span class='notice'>You put netting on the helmet.</span>"
		new/obj/item/clothing/head/helmet/ww2/ustannet(user.loc)
		qdel(src)
		qdel(W)

/obj/item/clothing/head/helmet/ww2/ustannet/verb/toggle_color()
	set category = null
	set src in usr
	set name = "Toggle Color"
	if (color)
		icon_state = "m1_tan_netting"
		item_state = "m1_tan_netting"
		worn_state = "m1_tan_netting"
		body_parts_covered = HEAD
		item_state_slots["slot_wear_head"] = "m1_tan_netting"
		usr << "<span class = 'danger'>You switch out your tan netting for green netting.</span>"
		update_icon()
		color = FALSE
		usr.update_inv_head(1)
	else if (!color)
		icon_state = "m1_green_netting"
		item_state = "m1_green_netting"
		worn_state = "m1_green_netting"
		body_parts_covered = HEAD
		item_state_slots["slot_wear_head"] = "m1_green_netting"
		usr << "<span class = 'danger'>You switch out your green netting for tan netting.</span>"
		update_icon()
		color = TRUE
		usr.update_inv_head(1)

/obj/item/clothing/head/helmet/ww2/usgreennet
	name = "M1 Helmet with green netting"
	desc = "The typical rounded steel helmet of the US Army, with green netting."
	icon_state = "m1_green_netting"
	item_state = "m1_green_netting"
	worn_state = "m1_green_netting"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww2/usgreennet/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return//I really don't understand why this check is needed
	if (istype(W, /obj/item/stack/material/leaf))
		playsound(loc, 'sound/machines/click.ogg', 75, TRUE)
		user << "<span class='notice'>You put foliage on the helmet.</span>"
		new/obj/item/clothing/head/helmet/ww2/usm1camogreen(user.loc)
		qdel(src)
		qdel(W)

/obj/item/clothing/head/helmet/ww2/usm1camogreen
	name = "M1 Helmet with netting"
	desc = "The typical rounded steel helmet of the US Army, with tan netting."
	icon_state = "m1_greennet_leaves"
	item_state = "m1_greennet_leaves"
	worn_state = "m1_greennet_leaves"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww2/ustannet
	name = "M1 Helmet with netting"
	desc = "The typical rounded steel helmet of the US Army, with tan netting."
	icon_state = "m1_tan_netting"
	item_state = "m1_tan_netting"
	worn_state = "m1_tan_netting"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww2/us_chaplain
	name = "M1 Chaplain Helmet"
	desc = "The typical rounded steel helmet of the US Army, this one brandishing a cross."
	icon_state = "m1_chaplain"
	item_state = "m1_chaplain"
	worn_state = "m1_chaplain"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)


/obj/item/clothing/head/helmet/ww2/usm1mpblack
	name = "Black M1 MP Helmet"
	desc = "The typical rounded steel helmet of the US Army, this one for Military Police."
	icon_state = "m1_mp_black"
	item_state = "m1_mp_black"
	worn_state = "m1_mp_black"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww2/usm1mpgreen
	name = "M1 MP Helmet"
	desc = "The typical rounded steel helmet of the US Army, this one for Military Police."
	icon_state = "m1_mp_green"
	item_state = "m1_mp_green"
	worn_state = "m1_mp_green"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)


/obj/item/clothing/head/helmet/ww2/us_medic
	name = "M1 Medic Helmet"
	desc = "The typical rounded steel helmet of the US Army, this one for medics"
	icon_state = "m1_medic"
	item_state = "m1_medic"
	worn_state = "m1_medic"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww2/us_2lt
	name = "M1 2nd LT Helmet"
	desc = "The typical rounded steel helmet of the US Army, this one bearing the rank of 2nd Lieutenant."
	icon_state = "m1_2nd_lt"
	item_state = "m1_2nd_lt"
	worn_state = "m1_2nd_lt"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww2/us_1lt
	name = "M1 1st LT Helmet"
	desc = "The typical rounded steel helmet of the US Army, this one bearing the rank of 1st Lieutenant."
	icon_state = "m1_1st_lt"
	item_state = "m1_1st_lt"
	worn_state = "m1_1st_lt"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww2/us_cap
	name = "M1 Captain Helmet"
	desc = "The typical rounded steel helmet of the US Army, this one bearing the rank of Captain."
	icon_state = "m1_cpt"
	item_state = "m1_cpt"
	worn_state = "m1_cpt"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww2/us_mar
	name = "USMC helmet"
	desc = "The typical rounded steel helmet of the USMC."
	icon_state = "ushelmet_mar"
	item_state = "ushelmet_mar"
	worn_state = "ushelmet_mar"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww2/us_mar_sgt
	name = "USMC sergeant helmet"
	desc = "The typical rounded steel helmet of the USMC, this one bearing the rank of Sergeant."
	icon_state = "ushelmet_mar_nco"
	item_state = "ushelmet_mar_nco"
	worn_state = "ushelmet_mar_nco"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/ww2/soviet_medic
	name = "soviet medical helmet"
	desc = "The typical rounded steel helmet of the red army, with the white markings of the medical corps."
	icon_state = "sovhelm_medic"
	item_state = "sovhelm_medic"
	worn_state = "sovhelm_medic"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 30, gun = 10, energy = 15, bomb = 40, bio = 20, rad = FALSE)
/////////////////////////////////////////UPA////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/obj/item/clothing/under/ww2/upa
	name = "UPA uniform"
	desc = "A Ukrayins'ka Povstans'ka Armiya uniform."
	icon_state = "upa_uni"
	item_state = "upa_uni"
	var/base_state = "upa_uni"
	var/rolled = FALSE
/obj/item/clothing/under/ww2/upa/update_icon()
	if (ishuman(loc))
		var/mob/living/human/H = loc
		if (H.gender == "female")
			worn_state = "upa_uni_f"
			H.update_inv_w_uniform()
		else
			worn_state = "upa_uni"
			H.update_inv_w_uniform()
/obj/item/clothing/under/ww2/upa/off
	name = "UPA officer uniform"
	desc = "A Ukrayins'ka Povstans'ka Armiya officer uniform."
	icon_state = "upa_off"
	item_state = "upa_off"
	worn_state = "upa_off"
	base_state = "upa_off"
	rolled = FALSE
/obj/item/clothing/under/ww2/upa/verb/roll_sleeves()
	set category = null
	set src in usr
	if (rolled && usr.gender == "male")
		item_state = "[base_state]"
		worn_state = "[base_state]"
		icon_state = "[base_state]"
		item_state_slots["w_uniform"] = "[base_state]"
		usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
		rolled = FALSE
		cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
		update_clothing_icon()
	else if (!rolled && usr.gender == "male")
		item_state = "[base_state]_rolled"
		worn_state = "[base_state]_rolled"
		icon_state = "[base_state]_rolled"
		item_state_slots["w_uniform"] = "[base_state]_rolled"
		usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
		rolled = TRUE
		heat_protection = ARMS
		cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS
		update_clothing_icon()
	if (rolled && usr.gender == "female")
		item_state = "[base_state]"
		worn_state = "upa_uni_f"
		icon_state = "[base_state]"
		item_state_slots["w_uniform"] = "[base_state]"
		usr << "<span class = 'danger'>You roll down your uniform's sleeves.</span>"
		rolled = FALSE
		cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
		update_clothing_icon()
	else if (!rolled && usr.gender == "female")
		item_state = "[base_state]_rolled"
		worn_state = "upa_uni_rolled_f"
		icon_state = "[base_state]_rolled"
		item_state_slots["w_uniform"] = "[base_state]_rolled"
		usr << "<span class = 'danger'>You roll up your uniform's sleeves.</span>"
		rolled = TRUE
		heat_protection = ARMS
		cold_protection = UPPER_TORSO|LOWER_TORSO|LEGS
		update_clothing_icon()

/obj/item/clothing/head/ww2/upa_cap
	name = "UPA field cap"
	desc = "A cap and worn by the Ukrayins'ka Povstans'ka Armiya."
	icon_state = "upa_cap"
	item_state = "upa_cap"
	worn_state = "upa_cap"
/obj/item/clothing/head/ww2/upa_pilotka
	name = "UPA pilotka"
	desc = "A pilotka and worn by the Ukrayins'ka Povstans'ka Armiya."
	icon_state = "upapilotka"
	item_state = "upapilotka"
	worn_state = "upapilotka"
/obj/item/clothing/head/ww2/upa_cap_off
	name = "UPA officer cap"
	desc = "A cap and worn by the Ukrayins'ka Povstans'ka Armiya NCO's."
	icon_state = "upa_off"
	item_state = "upa_off"
	worn_state = "upa_off"
/obj/item/clothing/head/ww2/upa_cap_commander
	name = "UPA officer cap"
	desc = "A cap and worn by the Ukrayins'ka Povstans'ka Armiya Officers."
	icon_state = "upa_commander"
	item_state = "upa_commander"
	worn_state = "upa_commander"
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/obj/item/clothing/accessory/armband/redcross
	name = "red cross armband"
	desc = "A white armband with the red cross in it."
	icon_state = "redcross"
	slot = "armband"

/obj/item/clothing/accessory/armband/nsdap
	name = "NSDAP armband"
	desc = "A red armband with the swastika on it."
	icon_state = "nsdap"
	slot = "armband"

/obj/item/clothing/accessory/armband/kenpeitai
	name = "Kenpeitai armband"
	desc = "A white armband with red japanese characters on it."
	icon_state = "japanesemp"
	slot = "armband"

/obj/item/clothing/accessory/armband/usmp
	name = "military police armband"
	desc = "A black armband with \"MP\" written on it."
	icon_state = "usmp"
	slot = "armband"

/obj/item/clothing/accessory/armband/volkssturm
	name = "Volkssturm armband"
	desc = "A red, white and black armband of the Volkssturm"
	icon_state = "volkssturm"
	slot = "armband"

/obj/item/clothing/suit/storage/coat/ww2/moderncoat
	name = "modern coat"
	desc = "A standard coat made from wool."
	icon_state = "moderncoat"
	item_state = "moderncoat"
	worn_state = "moderncoat"
	body_parts_covered = UPPER_TORSO||ARMS
	cold_protection = UPPER_TORSO|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 30)
	value = 100

/obj/item/clothing/suit/storage/coat/ww2/fancycoat
	name = "black coat"
	desc = "A fancy coat made from wool."
	icon_state = "woolcoat"
	item_state = "woolcoat"
	worn_state = "woolcoat"
	body_parts_covered = UPPER_TORSO||ARMS
	cold_protection = UPPER_TORSO|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 30)
	value = 100

/obj/item/clothing/suit/storage/coat/ww1/royalcoat
	name = "royal coat"
	desc = "A royal coat used for royal people."
	icon_state = "royalcoat"
	item_state = "royalcoat"
	worn_state = "royalcoat"
	body_parts_covered = UPPER_TORSO||ARMS
	cold_protection = UPPER_TORSO|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 30)
	value = 100

/obj/item/clothing/suit/storage/coat/ww2/expensivecoat
	name = "fancy  coat"
	desc = "A expensive coat made from wool and leather."
	icon_state = "expensivecoat"
	item_state = "expensivecoat"
	worn_state = "expensivecoat"
	body_parts_covered = UPPER_TORSO||ARMS
	cold_protection = UPPER_TORSO|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 30)
	value = 100

/obj/item/clothing/suit/storage/coat/ww2/servicejacket
	name = "service jacket"
	desc = "A standard military jacket."
	icon_state = "servicejacket"
	item_state = "servicejacket"
	worn_state = "servicejacket"
	body_parts_covered = UPPER_TORSO||ARMS
	cold_protection = UPPER_TORSO|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 5, arrow = 0, gun = FALSE, energy = 10, bomb = 5, bio = 15, rad = 15)
	value = 100

/obj/item/clothing/suit/storage/coat/ww2/bomberjacketbrown
	name = "brown bomber's jacket"
	desc = "A brown jacket meant for high-alititude temperatures."
	icon_state = "bomberjacket"
	item_state = "bomberjacket"
	worn_state = "bomberjacket"
	body_parts_covered = UPPER_TORSO||ARMS
	cold_protection = UPPER_TORSO|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 30)
	value = 100

/obj/item/clothing/suit/storage/coat/ww2/bomberjacketblack
	name = "black bomber's jacket"
	desc = "A black jacket meant for high-alititude temperatures."
	icon_state = "blackbomberjacket"
	item_state = "blackbomberjacket"
	worn_state = "blackbomberjacket"
	body_parts_covered = UPPER_TORSO||ARMS
	cold_protection = UPPER_TORSO|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 30)
	value = 100

/obj/item/clothing/suit/storage/coat/ww2/biker //it may have started this 'era', but biker jackets became popular still long after
	name = "biker jacket"
	desc = "A black jacket, favoured by the bold and recreational thrill seekers."
	icon_state = "biker"
	item_state = "biker"
	worn_state = "biker"
	body_parts_covered = UPPER_TORSO||ARMS
	cold_protection = UPPER_TORSO|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 30)
	value = 100

/obj/item/clothing/suit/storage/coat/ww2/biker/gator_jacket
	name = "alligator scale jacket"
	desc = "A sleek alligator scale jacket, bold and impression-setting like the people who wear it. 'See-ya later alligator'."
	icon_state = "gator_jacket"
	item_state = "gator_jacket"
	worn_state = "gator_jacket"
	value = 150

/obj/item/weapon/storage/belt/gulagguard
	name = "guard belt"
	desc = "A belt that can hold the standard issue gear of guards."
	icon_state = "japbelt"
	item_state = "japbelt"
	storage_slots = 10
	max_w_class = 3
	max_storage_space = 24
	can_hold = list(
		/obj/item/ammo_magazine,
		/obj/item/weapon/material,
		/obj/item/weapon/grenade,
		/obj/item/weapon/attachment,
		/obj/item/weapon/gun/projectile/pistol,
		/obj/item/weapon/gun/projectile/revolver,
		/obj/item/weapon/handcuffs,
		/obj/item/ammo_casing,
		/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen,
		/obj/item/weapon/melee/classic_baton,
		/obj/item/stack/medical/bruise_pack,
		/obj/item/weapon/whistle,
		/obj/item/weapon/pen,
		)

//swimwear//
/obj/item/clothing/under/red/strappedbikini
	name = "Red Strap Bikini"
	desc = "Seems to be two piece red Bikini, the top is held up by straps."
	icon_state = "r_strapbikini"
	item_state = "r_strapbikini"
	worn_state = "r_strapbikini"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	heat_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT

/obj/item/clothing/under/red/bandbikini
	name = "Red Band Bikini"
	desc = "Seems to be two piece red Bikini, the top is held up by a tight horizontal band."
	icon_state = "r_bandbikini"
	item_state = "r_bandbikini"
	worn_state = "r_bandbikini"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	heat_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT


/obj/item/clothing/under/red/swimtrunks
	name = "Red Swimtrunks"
	desc = "Seems to be pants made for swiming in."
	icon_state = "r_swimtrunks"
	item_state = "r_swimtrunks"
	worn_state = "r_swimtrunks"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	heat_protection = LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT


/obj/item/clothing/under/blue/strappedbikini
	name = "Blue Strap Bikini"
	desc = "Seems to be two piece blue Bikini, the top is held up by straps."
	icon_state = "b_strapbikini"
	item_state = "b_strapbikini"
	worn_state = "b_strapbikini"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	heat_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT

/obj/item/clothing/under/blue/bandbikini
	name = "Blue Band Bikini"
	desc = "Seems to be two piece blue Bikini, the top is held up by a tight horizontal band."
	icon_state = "b_bandbikini"
	item_state = "b_bandbikini"
	worn_state = "b_bandbikini"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	heat_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT

/obj/item/clothing/under/blue/swimtrunks
	name = "Blue Swimtrunks"
	desc = "Seems to be pants made for swiming in."
	icon_state = "b_swimtrunks"
	item_state = "b_swimtrunks"
	worn_state = "b_swimtrunks"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	heat_protection = LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT

/obj/item/clothing/under/green/strappedbikini
	name = "Green Strap Bikini"
	desc = "Seems to be two piece green Bikini, the top is held up by straps."
	icon_state = "g_strapbikini"
	item_state = "g_strapbikini"
	worn_state = "g_strapbikini"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	heat_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT

/obj/item/clothing/under/green/bandbikini
	name = "Green Band Bikini"
	desc = "Seems to be two piece green Bikini, the top is held up by a tight horizontal cloth."
	icon_state = "g_bandbikini"
	item_state = "g_bandbikini"
	worn_state = "g_bandbikini"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	heat_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT


/obj/item/clothing/under/green/swimtrunks
	name = "Green Swimtrunks"
	desc = "Seems to be pants made for swiming in."
	icon_state = "g_swimtrunks"
	item_state = "g_swimtrunks"
	worn_state = "g_swimtrunks"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	heat_protection = LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT


/obj/item/weapon/storage/belt/gulagguard/filled/New()
	..()
	new /obj/item/weapon/material/classic_baton(src)
	new /obj/item/stack/medical/bruise_pack/bint(src)
	new /obj/item/weapon/handcuffs(src)
	new /obj/item/weapon/handcuffs(src)
	new /obj/item/weapon/handcuffs(src)
	new /obj/item/weapon/handcuffs(src)
	new /obj/item/weapon/whistle(src)
	new /obj/item/weapon/pen/pencil(src)
	new /obj/item/weapon/clipboard/full(src)

/obj/item/weapon/storage/belt/gulagguard/filledwar/New()
	..()
	new /obj/item/weapon/material/classic_baton(src)
	new /obj/item/stack/medical/bruise_pack/bint(src)
	new /obj/item/weapon/handcuffs(src)
	new /obj/item/weapon/handcuffs(src)
	new /obj/item/weapon/grenade/smokebomb(src)
	new /obj/item/weapon/whistle(src)
	new /obj/item/ammo_magazine/c762x25_ppsh(src)
	new /obj/item/ammo_magazine/c762x25_ppsh(src)

/obj/item/weapon/storage/belt/gulagguard/filledwarak/New()
	..()
	new /obj/item/weapon/material/classic_baton(src)
	new /obj/item/stack/medical/bruise_pack/bint(src)
	new /obj/item/weapon/handcuffs(src)
	new /obj/item/weapon/handcuffs(src)
	new /obj/item/weapon/whistle(src)
	new /obj/item/ammo_magazine/ak47(src)
	new /obj/item/ammo_magazine/ak47(src)
	new /obj/item/ammo_magazine/ak47(src)

/obj/item/weapon/storage/belt/smallpouches/gerbelt
	icon_state = "gerbelt"
	item_state = "gerbelt"

/obj/item/weapon/storage/belt/smallpouches/gerbelt/officer
/obj/item/weapon/storage/belt/smallpouches/gerbelt/officer/New()
	..()
	new/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(src)
	new/obj/item/stack/medical/bruise_pack/bint(src)
	new/obj/item/weapon/horn(src)
	new/obj/item/weapon/reagent_containers/food/drinks/flask/officer/schnapps(src)

/obj/item/weapon/storage/belt/smallpouches/us/officer
/obj/item/weapon/storage/belt/smallpouches/us/officer/New()
	..()
	new/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(src)
	new/obj/item/stack/medical/bruise_pack/bint(src)
	new/obj/item/weapon/whistle(src)
	new/obj/item/weapon/reagent_containers/food/drinks/flask/officer/whiskey(src)

/obj/item/weapon/storage/belt/smallpouches/us/idfoff
/obj/item/weapon/storage/belt/smallpouches/us/idfoff/New()
	..()
	new/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(src)
	new/obj/item/stack/medical/bruise_pack/bint(src)
	new/obj/item/weapon/whistle(src)
	new/obj/item/weapon/reagent_containers/food/drinks/flask/officer/wine(src)

/obj/item/clothing/suit/storage/coat/leathercoat_black
	name = "black leather long coat"
	desc = "A long black leather coat."
	icon_state = "leathercoat_black"
	item_state = "leathercoat_black"
	worn_state = "leathercoat_black"

/obj/item/clothing/suit/storage/coat/modern_long_brown
	name = "modern brown coat"
	desc = "A modern long brown coat."
	icon_state = "mlongcoat_brown"
	item_state = "mlongcoat_brown"
	worn_state = "mlongcoat_brown"

/obj/item/clothing/suit/storage/coat/modern_long_black
	name = "modern black coat"
	desc = "A modern long black coat."
	icon_state = "mlongcoat_black"
	item_state = "mlongcoat_black"
	worn_state = "mlongcoat_black"

/obj/item/clothing/suit/storage/coat/gentleman
	name = "gentleman coat"
	desc = "An elegant black coat."
	icon_state = "gentlemancoat"
	item_state = "gentlemancoat"
	worn_state = "gentlemancoat"
