
/*
TODO:
Optimize this code as much as possible
Add Sounds
Replace snowflaked icon manipulation with proper icon mask manipulation
Add more attachments
Add attached bayonet sprite

Current Defines (_defines/attachment.dm)

#define ATTACH_IRONSIGHTS 1
#define ATTACH_SCOPE 2
#define ATTACH_STOCK 4
#define ATTACH_BARREL 8
#define ATTACH_UNDER 16
#define ATTACH_ADV_SCOPE 32
#define ATTACH_SILENCER 64
*/

/obj/item/weapon/attachment
	var/attachable = TRUE
	var/attachment_type // Use the 'ATTACH_' defines above (should only use one for this)
	var/A_attached = FALSE // Is attached?
	w_class = ITEM_SIZE_SMALL
	var/list/fits = list("pistol", "smg", "rifle", "shotgun", "mg") // What does it fit on?

/obj/item/weapon/attachment/proc/attached(mob/user, obj/item/weapon/gun/G)
	user << "<span class = 'notice'>You start to attach [src] to the [G].</span>"
	if (do_after(user, 15, user))
		user.unEquip(src)
		A_attached = TRUE
		G.attachment_slots -= attachment_type
		loc = G
		G.actions += actions
		G.verbs += verbs
		G.attachments += src
		G.update_attachment_actions(user)
		user << "<span class = 'notice'>You attach [src] to the [G].</span>"
	else
		return

/obj/item/weapon/attachment/proc/removed(mob/user, obj/item/weapon/gun/G)
	if (do_after(user, 15, user))
		G.attachments -= src
		G.actions -= actions
		G.verbs -= verbs
		G.attachment_slots += attachment_type
		dropped(user)
		A_attached = FALSE
		loc = get_turf(src)
		user << "You remove [src] from the [G]."
	else
		return

/obj/item/weapon/gun
	var/list/attachments = list()
	var/attachment_slots = null // Use the 'ATTACH_' defines above; can ise in combination Ex. ATTACH_SCOPE|ATTACH_BARREL

/obj/item/weapon/gun/examine(mob/user)
	..()
	if (attachments.len)
		for (var/obj/item/weapon/attachment/A in attachments)
			if (!(istype(A,/obj/item/weapon/attachment/scope/iron_sights)))
				user << "<span class='notice'>It has [A] attached.</span>"

/obj/item/weapon/gun/dropped(mob/user)
	..()
	if (attachments && attachments.len)
		for (var/obj/item/weapon/attachment/A in attachments)
			A.dropped(user)
		for (var/obj/item/weapon/gun/launcher/grenade/underslung/G in attachments)
			G.dropped(user)

/obj/item/weapon/gun/pickup(mob/user)
	if (attachments && attachments.len)
		for (var/obj/item/weapon/attachment/A in attachments)
			A.pickup(user)
		for (var/obj/item/weapon/gun/launcher/grenade/underslung/G in attachments)
			G.pickup(user)

/obj/item/weapon/gun/verb/field_strip()
	set name = "Field Strip"
	set desc = "Removes any attachments."
	set category = null
	var/mob/living/human/user = usr

	for (var/obj/item/weapon/attachment/A in attachments)
		A.removed(user, src)
	for (var/obj/item/weapon/gun/launcher/grenade/underslung/G in attachments)
		G.removed(user, src)

// Use this under /New() of weapons if they spawn with attachments
/obj/item/weapon/gun/proc/spawn_add_attachment(obj/item/weapon/attachment/A)
	A.A_attached = TRUE
	attachment_slots -= A.attachment_type
	attachments += A
	actions += A.actions

/obj/item/weapon/gun/proc/update_attachment_actions(mob/user)
	for (var/datum/action/action in actions)
		action.Grant(user)

/obj/item/weapon/gun/proc/try_attach(obj/item/I, mob/user)
	if (!I || !user)
		return
	if (user.get_inactive_hand() != src)
		user << "You must be holding the [src] to add attachments."
		return
	attach_A(I, user)

// Do not use this; use try_attach instead
/obj/item/weapon/gun/proc/attach_A(obj/item/I, mob/user)
	if (istype(I, /obj/item/weapon/attachment))
		var/obj/item/weapon/attachment/A = I
		switch(A.attachment_type)
			if (ATTACH_IRONSIGHTS)
				if (attachment_slots & ATTACH_IRONSIGHTS)
					A.attached(user, src)
				else
					user << "You already have iron sights."
			if (ATTACH_SCOPE)
				if (attachment_slots & ATTACH_SCOPE)
					A.attached(user, src, FALSE)
				else
					user << "You fumble around with the attachment."
			if (ATTACH_STOCK)
				if (attachment_slots & ATTACH_STOCK)
					A.attached(user, src, FALSE)
				else
					user << "You fumble around with the attachment."
			if (ATTACH_BARREL)
				if (attachment_slots & ATTACH_BARREL)
					A.attached(user, src, FALSE)
				else
					user << "You fumble around with the attachment."
			if (ATTACH_UNDER)
				if (attachment_slots & ATTACH_UNDER)
					A.attached(user, src, FALSE)
			if (ATTACH_ADV_SCOPE)
				if (attachment_slots & ATTACH_ADV_SCOPE)
					A.attached(user, src, FALSE)
				else
					user << "You fumble around with the attachment."
			if (ATTACH_SILENCER)
				if (gtype in A.fits)
					if (attachment_slots & ATTACH_SILENCER)
						A.attached(user, src, FALSE)
					else
						user << "You fumble around with the attachment."
				else
					user << "[A] cannot be attached to the [src]."
			else
				user << "[A] cannot be attached to the [src]."
	if (istype(I, /obj/item/weapon/gun/launcher/grenade/underslung))
		var/obj/item/weapon/gun/launcher/grenade/underslung/G = I
		if (attachment_slots & ATTACH_UNDER)
			G.attached(user, src, FALSE)


/////////////////MISC ATTACHMENTS//////////////////////////////

//Scope code is found in code/modules/WW2/weapons/zoom.dm

/obj/item/weapon/attachment/bayonet
	name = "bayonet"
	icon = 'icons/obj/gun_att.dmi'
	icon_state = "bayonet"
	item_state = "knife"
	flags = CONDUCT
	sharp = TRUE
	edge = TRUE
	attack_verb = list("slashed", "stabbed", "sliced", "torn", "ripped", "diced", "cut")
	attachment_type = ATTACH_BARREL
	force = 65
	weight = 0.450
	value = 12
	var/attack_sound = 'sound/weapons/slice.ogg'
//	var/datum/action/bayonet/amelee
	var/atk_mode = SLASH

/obj/item/weapon/attachment/bayonet/attack_self(mob/user)
	..()
	if(atk_mode == SLASH)
		atk_mode = STAB
		user << "<span class='notice'>You will now stab.</span>"
		edge = FALSE
		sharp = TRUE
		attack_verb = list("stabbed")
		hitsound = "stab_sound"
		return

	else if(atk_mode == STAB)
		atk_mode = SLASH
		user << "<span class='notice'>You will now slash.</span>"
		attack_verb = list("slashed", "diced")
		hitsound = "slash_sound"
		edge = TRUE
		sharp = TRUE
		return
/obj/item/weapon/attachment/bayonet/attached(var/mob/user = null, obj/item/weapon/gun/G, var/quick = FALSE)
	if (quick)
		if (user)
			user.unEquip(src)
		A_attached = TRUE
		G.attachment_slots -= attachment_type
		loc = G
		G.actions += actions
		G.verbs += verbs
		G.attachments += src
		if (user)
			user << "<span class = 'notice'>You attach [src] to the [G].</span>"
		G.bayonet = src
		G.overlays += G.bayonet_ico
	else
		if (user)
			user << "<span class = 'notice'>You start to attach [src] to the [G].</span>"
		if (do_after(user, 15, user))
			A_attached = TRUE
			G.attachment_slots -= attachment_type
			G.actions += actions
			G.verbs += verbs
			G.attachments += src
			if (user)
				user.unEquip(src)
				G.update_attachment_actions(user)
				user << "<span class = 'notice'>You attach [src] to the [G].</span>"
				if (istype(src, /obj/item/weapon/attachment/bayonet/flag) && G.bayonet_ico)
					G.bayonet_ico.icon_state = "[icon_state]_ongun"
					G.bayonet_ico.pixel_x = 0
					G.bayonet_ico.pixel_y = 0
				else
					G.bayonet_ico.icon_state = "[icon_state]_ongun"
					G.bayonet_ico.pixel_x = 6
					G.bayonet_ico.pixel_y = 6
			loc = G
			G.bayonet = src
			G.overlays += G.bayonet_ico
		else
			return

/obj/item/weapon/attachment/bayonet/removed(mob/user, obj/item/weapon/gun/G)
	if (do_after(user, 15, user))
		G.attachments -= src
		G.actions -= actions
		G.verbs -= verbs
		G.attachment_slots += attachment_type
		dropped(user)
		A_attached = FALSE
		loc = get_turf(src)
		user << "You remove [src] from the [G]."
		G.bayonet = null
		G.overlays -= G.bayonet_ico
	else
		return

/obj/item/weapon/attachment/bayonet/flag
	name = "japanese flag"
	icon_state = "jap_flag"
	item_state = "jap_flag"
	sharp = FALSE
	edge = FALSE
	attack_verb = list("bashed")
	attachment_type = ATTACH_BARREL
	force = 1

/obj/item/weapon/attachment/bayonet/flag/attack_self(mob/user)
	return


/////////////////OPTICS//////////////////////////////

/obj/item/weapon/attachment/scope/removed(mob/user, obj/item/weapon/gun/G)
	if (do_after(user, 15, user))
		G.attachments -= src
		G.actions -= actions
		G.verbs -= verbs
		G.attachment_slots += attachment_type
		dropped(user)
		A_attached = FALSE
		loc = get_turf(src)
		user << "You remove [src] from the [G]."
		G.accuracy = initial(G.accuracy)
		G.recoil = initial(G.recoil)
	else
		return

/obj/item/weapon/attachment/scope/iron_sights
	name = "iron sights"
	attachment_type = ATTACH_IRONSIGHTS
	zoom_amt = ZOOM_CONSTANT

/obj/item/weapon/attachment/scope/iron_sights/removed(mob/user, obj/item/weapon/gun/G)
	return

/obj/item/weapon/attachment/scope/iron_sights/mg
	name = "iron sights"
	attachment_type = ATTACH_IRONSIGHTS
	zoom_amt = ZOOM_CONSTANT + 5

/obj/item/weapon/attachment/scope/iron_sights/mg/type99
	name = "telescopic sights"
	attachment_type = ATTACH_IRONSIGHTS
	zoom_amt = ZOOM_CONSTANT + 5

/obj/item/weapon/attachment/scope/adjustable/sniper_scope
	name = "sniper scope"
	icon_state = "kar_scope"
	desc = "You can attach this to rifles... or use them as binoculars. Amplifies 8x."
	max_zoom = ZOOM_CONSTANT*2

/obj/item/weapon/attachment/scope/adjustable/sniper_scope/removed(mob/user, obj/item/weapon/gun/G)
	if (do_after(user, 15, user))
		G.attachments -= src
		G.actions -= actions
		G.verbs -= verbs
		G.attachment_slots += attachment_type
		dropped(user)
		A_attached = FALSE
		loc = get_turf(src)
		user << "You remove [src] from the [G]."
		//This should only be temporary until more attachment icons are made, then we switch to adding/removing icon masks
		if (istype(G, /obj/item/weapon/gun/projectile))
			var/obj/item/weapon/gun/projectile/W = G
			W.sniper_scope = FALSE
			W.update_icon()
	else
		return

/obj/item/weapon/attachment/scope/adjustable/sniper_scope/attached(mob/user, obj/item/weapon/gun/G, var/quick = FALSE)
	if (quick)
		A_attached = TRUE
		G.attachment_slots -= attachment_type
		loc = G
		G.actions += actions
		G.verbs += verbs
		G.attachments += src
		if (istype(G, /obj/item/weapon/gun/projectile))
			var/obj/item/weapon/gun/projectile/W = G
			W.sniper_scope = TRUE
			W.update_icon()
	else
		if (do_after(user, 15, user))
			user.unEquip(src)
			A_attached = TRUE
			G.attachment_slots -= attachment_type
			loc = G
			G.actions += actions
			G.verbs += verbs
			G.attachments += src
			G.update_attachment_actions(user)
			user << "<span class = 'notice'>You attach [src] to the [G].</span>"
			if (istype(G, /obj/item/weapon/gun/projectile))
				var/obj/item/weapon/gun/projectile/W = G
				W.sniper_scope = TRUE
				W.update_icon()
		else
			return

/////////////////ADVANCED OPTICS//////////////////////////////

/obj/item/weapon/attachment/scope/adjustable/advanced
	icon = 'icons/obj/gun_att.dmi'
	icon_state = "acog"
	var/acc_modifier = 1
	var/scopeonly = TRUE //if the gun must be on scope mode to give the bonuses
	attachment_type = ATTACH_ADV_SCOPE
	var/image/ongun
	New()
		..()
		ongun = image("icon" = 'icons/obj/gun_att.dmi', "icon_state" = "[icon_state]_ongun")

/obj/item/weapon/attachment/scope/adjustable/advanced/attached(mob/user, obj/item/weapon/gun/G, var/quick = FALSE)
	if (quick)
		A_attached = TRUE
		G.attachment_slots -= attachment_type
		loc = G
		G.actions += actions
		G.verbs += verbs
		G.attachments += src
		G.specialoptics = src
		G.optics_ico = ongun
		G.overlays += G.optics_ico
	else
		if (do_after(user, 15, user))
			user.unEquip(src)
			A_attached = TRUE
			G.attachment_slots -= attachment_type
			loc = G
			G.actions += actions
			G.verbs += verbs
			G.attachments += src
			G.update_attachment_actions(user)
			user << "<span class = 'notice'>You attach [src] to the [G].</span>"
			G.specialoptics = src
			G.optics_ico = ongun
			G.overlays += G.optics_ico
		else
			return
/obj/item/weapon/attachment/scope/adjustable/advanced/removed(mob/user, obj/item/weapon/gun/G)
	if (do_after(user, 15, user))
		G.attachments -= src
		G.actions -= actions
		G.verbs -= verbs
		G.attachment_slots += attachment_type
		dropped(user)
		A_attached = FALSE
		loc = get_turf(src)
		user << "You remove [src] from the [G]."
		G.specialoptics = null
		G.overlays -= G.optics_ico
	else
		return

/obj/item/weapon/attachment/scope/adjustable/advanced/pso1
	name = "PSO-1 scope"
	icon_state = "pso1"
	desc = "A soviet 4x scope. Increases magnification but does not increase accuracy."
	max_zoom = ZOOM_CONSTANT+3

/obj/item/weapon/attachment/scope/adjustable/advanced/acog
	name = "4x ACOG scope"
	icon_state = "acog"
	desc = "A 4x scope. Increases magnification but does not increase accuracy."
	max_zoom = ZOOM_CONSTANT+3

/obj/item/weapon/attachment/scope/adjustable/advanced/reddot
	name = "red dot sight"
	icon_state = "reddot"
	desc = "A red dot laser sight. Increases accuracy and gives a slight magnification."
	max_zoom = ZOOM_CONSTANT+1
	acc_modifier = 1.3

/obj/item/weapon/attachment/scope/adjustable/advanced/holographic
	name = "holographic sight"
	desc = "A reflector holographic sight. Does not give magnification but greatly reduces parallax error."
	icon_state = "holographic"
	max_zoom = ZOOM_CONSTANT
	acc_modifier = 1.4

/obj/item/weapon/attachment/scope/adjustable/advanced/nvs
	name = "night vision scope"
	desc = "A bulky scope that allows images be produced in levels of light approaching total darkness."
	icon_state = "nvs"
	max_zoom = ZOOM_CONSTANT
	acc_modifier = 0.8

/obj/item/weapon/attachment/scope/adjustable/advanced/elcan
	name = "C79A2 Elcan sight"
	icon_state = "elcan"
	desc = "A 3.4x scope. Increases magnification and reduces some parallax error."
	max_zoom = ZOOM_CONSTANT+2
	acc_modifier = 1.1

/obj/item/weapon/attachment/scope/adjustable/advanced/fg42
	name = "FG42 sight"
	icon_state = "fg42"
	desc = "A 1.5x scope. Increases magnification and reduces some parallax error."
	max_zoom = ZOOM_CONSTANT+2
	acc_modifier = 1.1

/////////////////UNDER BARREL//////////////////////////////

/obj/item/weapon/attachment/under
	icon = 'icons/obj/gun_att.dmi'
	icon_state = "foregrip"
	var/acc_modifier = 1
	var/scopeonly = TRUE //if the gun must be on scope mode to give the bonuses
	attachment_type = ATTACH_UNDER
	var/image/ongun
	New()
		..()
		ongun = image("icon" = 'icons/obj/gun_att.dmi', "icon_state" = "[icon_state]_ongun")

/obj/item/weapon/attachment/under/attached(mob/user, obj/item/weapon/gun/G, var/quick = FALSE)
	if (quick)
		A_attached = TRUE
		G.attachment_slots -= attachment_type
		loc = G
		G.actions += actions
		G.verbs += verbs
		G.attachments += src
		G.under = src
		G.under_ico = ongun
		G.overlays += G.under_ico
	else
		if (do_after(user, 15, user))
			user.unEquip(src)
			A_attached = TRUE
			G.attachment_slots -= attachment_type
			loc = G
			G.actions += actions
			G.verbs += verbs
			G.attachments += src
			G.update_attachment_actions(user)
			user << "<span class = 'notice'>You attach [src] to the [G].</span>"
			G.under = src
			G.under_ico = ongun
			G.overlays += G.under_ico
		else
			return

/obj/item/weapon/attachment/under/removed(mob/user, obj/item/weapon/gun/G)
	if (do_after(user, 15, user))
		G.attachments -= src
		G.actions -= actions
		G.verbs -= verbs
		G.attachment_slots += attachment_type
		dropped(user)
		A_attached = FALSE
		loc = get_turf(src)
		user << "You remove [src] from the [G]."
		G.under = null
		G.overlays -= G.under_ico
	else
		return
/obj/item/weapon/attachment/under/laser
	name = "laser pointer"
	icon_state = "laser"
	desc = "a basic laser pointer, increases accuracy by a bit."
	acc_modifier = 1.2
	scopeonly = FALSE

/obj/item/weapon/attachment/under/foregrip
	name = "foregrip"
	icon_state = "foregrip"
	desc = "a foregrip, to increase stability when firing."
	acc_modifier = 1.4
	scopeonly = FALSE

/obj/item/weapon/attachment/under/foregrip/alt
	name = "foregrip"
	icon_state = "foregrip_alt"
	desc = "a foregrip, to increase stability when firing."
	acc_modifier = 1.4
	scopeonly = FALSE

/obj/item/weapon/gun/launcher/grenade/underslung/proc/attached(mob/user, obj/item/weapon/gun/G, var/quick = FALSE)
	if (quick)
		A_attached = TRUE
		G.attachment_slots -= ATTACH_UNDER
		loc = G
		G.attachments += src
		G.launcher = src
		G.under_ico = ongun
		G.overlays += G.under_ico
	else
		if (do_after(user, 15, user))
			user.unEquip(src)
			A_attached = TRUE
			G.attachment_slots -= ATTACH_UNDER
			loc = G
			G.attachments += src
			G.update_attachment_actions(user)
			user << "<span class = 'notice'>You attach [src] to the [G].</span>"
			G.launcher = src
			G.under_ico = ongun
			G.overlays += G.under_ico
		else
			return

/obj/item/weapon/gun/launcher/grenade/underslung/proc/removed(mob/user, obj/item/weapon/gun/G)
	if (do_after(user, 15, user))
		G.attachments -= src
		G.attachment_slots += ATTACH_UNDER
		dropped(user)
		A_attached = FALSE
		loc = get_turf(src)
		user << "You remove [src] from the [G]."
		G.launcher = null
		G.overlays -= G.under_ico
	else
		return

/obj/item/weapon/gun
	var/silencer_ico
	var/obj/item/weapon/attachment/silencer/silencer = null


/////////////////SILENCERS//////////////////////////////

/obj/item/weapon/attachment/silencer
	icon = 'icons/obj/gun_att.dmi'
	icon_state = "silencer"
	name = "silencer"
	desc = "a gun silencer."
	attachment_type = ATTACH_SILENCER
	var/image/ongun
	var/reduction = 50

	New()
		..()
		ongun = image("icon" = 'icons/obj/gun_att.dmi', "icon_state" = "[icon_state]_ongun")
		ongun.pixel_x = 16
		ongun.pixel_y = 16
		if (findtext(icon_state,"pistol"))
			ongun.pixel_x = 20
			ongun.pixel_y = 0
/obj/item/weapon/attachment/silencer/attached(mob/user, obj/item/weapon/gun/G, var/quick = FALSE)
	if (quick)
		A_attached = TRUE
		G.attachment_slots -= attachment_type
		loc = G
		G.actions += actions
		G.verbs += verbs
		G.attachments += src
		G.silencer = src
		G.silencer_ico = ongun
		G.overlays += G.silencer_ico
	else
		if (do_after(user, 15, user))
			user.unEquip(src)
			A_attached = TRUE
			G.attachment_slots -= attachment_type
			loc = G
			G.actions += actions
			G.verbs += verbs
			G.attachments += src
			G.update_attachment_actions(user)
			user << "<span class = 'notice'>You attach [src] to the [G].</span>"
			G.silencer = src
			G.silencer_ico = ongun
			G.overlays += G.silencer_ico
		else
			return

/obj/item/weapon/attachment/silencer/removed(mob/user, obj/item/weapon/gun/G)
	if (do_after(user, 15, user))
		G.attachments -= src
		G.actions -= actions
		G.verbs -= verbs
		G.attachment_slots += attachment_type
		dropped(user)
		A_attached = FALSE
		loc = get_turf(src)
		user << "You remove [src] from the [G]."
		G.silencer = null
		G.overlays -= G.silencer_ico
	else
		return

// Improvised
/obj/item/weapon/attachment/silencer/plastic_bottle
	name = "plastic bottle suppressor"
	icon_state = "plastic_bottle_suppressor"
	desc = "a makeshift suppressor."
	reduction = 25
	fits = list("smg", "rifle")

/obj/item/weapon/attachment/silencer/oil_filter
	name = "oil filter suppressor"
	icon_state = "oil_filter_suppressor"
	desc = "a makeshift suppressor."
	reduction = 35
	fits = list("smg", "rifle")

// Normal
/obj/item/weapon/attachment/silencer/pistol
	name = "pistol suppressor"
	icon_state = "modern_pistol_suppressor"
	desc = "a pistol suppressor."
	reduction = 50
	fits = list("pistol")

/obj/item/weapon/attachment/silencer/pistol/ww2
	name = "pistol suppressor"
	icon_state = "ww2_pistol_suppressor"
	desc = "a pistol suppressor."
	reduction = 35

/obj/item/weapon/attachment/silencer/rifle
	name = "rifle suppressor"
	icon_state = "modern_rifle_suppressor"
	desc = "a rifle suppressor."
	reduction = 50
	fits = list("rifle")

/obj/item/weapon/attachment/silencer/rifle/ww2
	name = "rifle suppressor"
	icon_state = "ww2_rifle_suppressor"
	desc = "a rifle suppressor."
	reduction = 35

/obj/item/weapon/attachment/silencer/smg
	name = "smg suppressor"
	icon_state = "modern_smg_suppressor"
	desc = "a smg suppressor."
	reduction = 50
	fits = list("smg")

/obj/item/weapon/attachment/silencer/smg/ww2
	name = "smg suppressor"
	icon_state = "ww2_smg_suppressor"
	desc = "a smg suppressor."
	reduction = 35

/obj/item/weapon/attachment/silencer/shotgun
	name = "shotgun suppressor"
	icon_state = "modern_shotgun_suppressor"
	desc = "a shotgun suppressor."
	reduction = 40
	fits = list("shotgun")