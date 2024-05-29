
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
	var/ergonomics = 1

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
		G.ergonomics *= src.ergonomics
		user << "<span class = 'notice'>You attach [src] to the [G].</span>"
	else
		return

/obj/item/weapon/attachment/proc/removed(mob/user, obj/item/weapon/gun/G)
	if (do_after(user, 15, user))
		G.attachments -= src
		G.actions -= actions
		G.verbs -= verbs
		G.attachment_slots += attachment_type
		G.ergonomics /= src.ergonomics
		dropped(user)
		A_attached = FALSE
		loc = get_turf(src)
		user << "You remove [src] from the [G]."
	else
		return//

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
	force = 35
	weight = 0.450
	value = 12
	var/attack_sound = 'sound/weapons/slice.ogg'
//	var/datum/action/bayonet/amelee
	var/atk_mode = SLASH
	var/mounted_dmg = 45

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
		G.update_icon()
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
			loc = G
			G.bayonet = src
			G.update_icon()
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
		G.update_icon()
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
		G.shake_strength = initial(G.shake_strength)
		G.update_icon()
	else
		return

/obj/item/weapon/attachment/scope/iron_sights
	name = "iron sights"
	attachment_type = ATTACH_IRONSIGHTS
	zoom_amt = ZOOM_CONSTANT

/obj/item/weapon/attachment/scope/iron_sights/removed(mob/user, obj/item/weapon/gun/G)
	return

/obj/item/weapon/attachment/scope/adjustable/sniper_scope
	name = "sniper scope"
	icon = 'icons/obj/gun_att.dmi'
	icon_state = "sniper_scope"
	desc = "You can attach this to rifles... or use them as binoculars. Amplifies 8x."
	mount = "sniper_scope_mount"
	max_zoom = ZOOM_CONSTANT*2

/// JAPANESE ///

/obj/item/weapon/attachment/scope/adjustable/sniper_scope/type97
	name = "Type 97 Optic"
	desc = "You can attach this to japanese arisaka rifles."
	icon_state = "type97"
	mount = "type97_cronstein"

/obj/item/weapon/attachment/scope/adjustable/sniper_scope/type99
	name = "Type 99 Optic"
	desc = "You can attach this to japanese mgs."
	icon_state = "type99"
	mount = "type99_cronstein"
/obj/item/weapon/attachment/scope/adjustable/sniper_scope/type99/type96
	name = "Type 96 Optic"

/obj/item/weapon/attachment/scope/adjustable/sniper_scope/type97tank
	name = "Type 97 Scope"
	desc = "You can attach this to the type 97 heavy tank rifle."
	icon_state = "type97_tank"
	mount = "type97_tank"

/// FRENCH ///

/obj/item/weapon/attachment/scope/adjustable/sniper_scope/apx
	name = "APX"
	desc = "You can attach this to french ww1 sniper rifles"
	icon_state = "apx"
	mount = "apx_cronstein"

/// RUSSIAN ///

/obj/item/weapon/attachment/scope/adjustable/sniper_scope/pu
	name = "PU"
	desc = "You can attach this scope to sniper Mosin-Nagan and SVT rifles"
	icon_state = "pu"
	mount = "kochetov"

/obj/item/weapon/attachment/scope/adjustable/sniper_scope/pu/ppu8
	name = "PPU-8"
	desc = "You can attach this scope to DTM machinegun."
	icon_state = "ppu8"
	mount = "dt_mount"
	max_zoom = ZOOM_CONSTANT+2

/obj/item/weapon/attachment/scope/adjustable/sniper_scope/pso1
	name = "PSO-1"
	desc = "You can attach this scope to any rifle with dovetail rail"
	icon_state = "pso1"
	mount = "dovetail"
	max_zoom = ZOOM_CONSTANT+3
/obj/item/weapon/attachment/scope/adjustable/sniper_scope/pso4
	name = "PSO-4"
	desc = "You can attach this scope to any rifle with dovetail rail"
	icon_state = "pso4"
	mount = "dovetail"
	max_zoom = ZOOM_CONSTANT+4
	ergonomics = 1.15
/obj/item/weapon/attachment/scope/adjustable/sniper_scope/spp
	name = "SPP"
	desc = "Optical sight designed for heavy machineguns. You can attach this scope to any rifle with dovetail rail"
	icon_state = "spp"
	mount = "dovetail"
	max_zoom = ZOOM_CONSTANT+3

/// GERMAN ///

/obj/item/weapon/attachment/scope/adjustable/sniper_scope/zf39
	name = "ZF-39"
	desc = "You can attach this to Kar98 rifles."
	icon_state = "zf39"
	mount = "swept_back"
	max_zoom = ZOOM_CONSTANT+3
/obj/item/weapon/attachment/scope/adjustable/sniper_scope/zf4
	name = "ZF-4"
	desc = "You can attach this to FG42, StG44 and G42 rifles."
	icon_state = "zf4"
	mount = "swept_back"
	max_zoom = ZOOM_CONSTANT+2

/// AMERICAN ///

/obj/item/weapon/attachment/scope/adjustable/sniper_scope/m84
	name = "M84"
	desc = "You can attach this to Springfield sniper rifles."
	icon_state = "m84"
	mount = "picatinny"
/obj/item/weapon/attachment/scope/adjustable/sniper_scope/acog
	name = "ACOG"
	desc = "You can attach this to any rifle with a Picatinny rail."
	icon_state = "acog"
	mount = "picatinny"
	max_zoom = ZOOM_CONSTANT+3
	ergonomics = 1.25
/obj/item/weapon/attachment/scope/adjustable/sniper_scope/elcan
	name = "Elcan"
	desc = "You can attach this to any rifle with Picatinny rail."
	icon_state = "elcan"
	mount = "picatinny"
	max_zoom = ZOOM_CONSTANT+2
	ergonomics = 1.35
/obj/item/weapon/attachment/scope/adjustable/sniper_scope/elcan/arid
	icon_state = "elcan_arid"
/obj/item/weapon/attachment/scope/adjustable/sniper_scope/elcan/winter
	icon_state = "elcan_winter"
/obj/item/weapon/attachment/scope/adjustable/sniper_scope/vortex_viper
	name = "Viper Vortex"
	desc = "You can attach this to any rifle with picatinny rail"
	icon_state = "vortex_viper"
	mount = "picatinny"
	max_zoom = ZOOM_CONSTANT * 3

/obj/item/weapon/attachment/scope/adjustable/sniper_scope/removed(mob/user, obj/item/weapon/gun/G)
	if (do_after(user, 15, user))
		G.attachments -= src
		G.actions -= actions
		G.verbs -= verbs
		G.attachment_slots += attachment_type
		G.ergonomics /= src.ergonomics
		dropped(user)
		A_attached = FALSE
		loc = get_turf(src)
		user << "You remove [src] from the [G]."
		//This should only be temporary until more attachment icons are made, then we switch to adding/removing icon masks
		if (istype(G, /obj/item/weapon/gun/projectile))
			var/obj/item/weapon/gun/projectile/W = G
			W.scope = null
		G.update_icon()
	else
		return

/obj/item/weapon/attachment/scope/adjustable/sniper_scope/attached(mob/user, obj/item/weapon/gun/G, var/quick = FALSE)
	if(!G.scope_mounts.Find(src.mount))
		to_chat(user, SPAN_WARNING("\The [src.name] can't be attached!"))
		return
	if (quick)
		A_attached = TRUE
		G.attachment_slots -= attachment_type
		loc = G
		G.scope = src
		G.actions += actions
		G.verbs += verbs
		G.attachments += src
		G.ergonomics *= ergonomics
		if (istype(G, /obj/item/weapon/gun/projectile))
			var/obj/item/weapon/gun/projectile/W = G
			W.update_icon()
	else
		if (do_after(user, 15, user))
			user.unEquip(src)
			A_attached = TRUE
			G.attachment_slots -= attachment_type
			loc = G
			G.actions += actions
			G.verbs += verbs
			G.scope = src
			G.attachments += src
			G.update_attachment_actions(user)
			G.ergonomics *= src.ergonomics
			user << "<span class = 'notice'>You attach [src] to the [G].</span>"
			if (istype(G, /obj/item/weapon/gun/projectile))
				var/obj/item/weapon/gun/projectile/W = G
				W.update_icon()
		else
			return

/////////////////ADVANCED OPTICS//////////////////////////////

/obj/item/weapon/attachment/scope/adjustable/advanced
	icon = 'icons/obj/gun_att.dmi'
	icon_state = "holographic"
	var/scopeonly = TRUE //if the gun must be on scope mode to give the bonuses
	attachment_type = ATTACH_SCOPE
	var/image/ongun
	mount = "scope_mount"
	New()
		..()
		ongun = image("icon" = 'icons/obj/gun_att.dmi', "icon_state" = "[icon_state]_ongun")

/obj/item/weapon/attachment/scope/adjustable/advanced/attached(mob/user, obj/item/weapon/gun/G, var/quick = FALSE)
	if(!G.scope_mounts.Find(src.mount))
		user << "[src.name] can't be attached!"
		return
	if (quick)
		A_attached = TRUE
		G.attachment_slots -= attachment_type
		loc = G
		G.actions += actions
		G.verbs += verbs
		G.attachments += src
		G.scope = src
		G.ergonomics *= src.ergonomics
		G.update_icon()
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
			G.ergonomics *= src.ergonomics
			G.scope = src
			G.update_icon()
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
		G.scope = null
		G.ergonomics /= src.ergonomics
		G.update_icon()
	else
		return

/obj/item/weapon/attachment/scope/adjustable/advanced/reddot
	name = "red dot sight"
	icon_state = "reddot"
	desc = "A red dot laser sight. Increases accuracy and gives a slight magnification."
	mount = "picatinny"
	max_zoom = ZOOM_CONSTANT+1
	ergonomics = 2

/obj/item/weapon/attachment/scope/adjustable/advanced/holographic
	name = "holographic sight"
	desc = "A reflector holographic sight. Does not give magnification but greatly reduces parallax error."
	icon_state = "holographic"
	mount = "picatinny"
	max_zoom = ZOOM_CONSTANT
	ergonomics = 2.5

/obj/item/weapon/attachment/scope/adjustable/advanced/nvs
	name = "night vision scope"
	desc = "A bulky scope that allows images be produced in levels of light approaching total darkness."
	icon_state = "nvs"
	mount = "picatinny"
	max_zoom = ZOOM_CONSTANT

/////////////////UNDER BARREL//////////////////////////////

/obj/item/weapon/attachment/under
	icon = 'icons/obj/gun_att.dmi'
	icon_state = "foregrip"
	attachment_type = ATTACH_UNDER
	var/mount = "picatinny"

/obj/item/weapon/attachment/under/attached(mob/user, obj/item/weapon/gun/G, var/quick = FALSE)
	if(!G.under_mounts.Find(src.mount))
		user << "[src.name] can't be attached!"
		return
	if (quick)
		A_attached = TRUE
		G.attachment_slots -= attachment_type
		loc = G
		G.actions += actions
		G.verbs += verbs
		G.attachments += src
		G.under = src
		G.ergonomics *= src.ergonomics
		G.update_icon()
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
			G.ergonomics *= src.ergonomics
			user << "<span class = 'notice'>You attach [src] to the [G].</span>"
			G.under = src
			G.update_icon()
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
		G.ergonomics /= src.ergonomics
		G.update_icon()
	else
		return
/obj/item/weapon/attachment/under/laser
	name = "laser pointer"
	icon_state = "laser"
	desc = "A basic laser pointer, increases accuracy by a bit."
	ergonomics = 1.25

/obj/item/weapon/attachment/under/foregrip
	name = "foregrip"
	icon_state = "foregrip"
	desc = "A foregrip, to increase stability when firing."
	ergonomics = 1.5

/obj/item/weapon/attachment/under/foregrip/alt
	name = "foregrip"
	icon_state = "foregrip_alt"
	desc = "A foregrip, to increase stability when firing."
	ergonomics = 1.5

/obj/item/weapon/gun/launcher/grenade/underslung/proc/attached(mob/user, obj/item/weapon/gun/G, var/quick = FALSE)
	if(!G.under_mounts.Find(src.mount))
		user << "[src.name] can't be attached!"
		return
	if (quick)
		A_attached = TRUE
		G.attachment_slots -= ATTACH_UNDER
		loc = G
		G.attachments += src
		G.launcher = src
		G.update_icon()
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
			G.update_icon()
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
		G.update_icon()
	else
		return

/obj/item/weapon/gun
	var/obj/item/weapon/attachment/silencer/silencer = null


/////////////////SILENCERS//////////////////////////////

/obj/item/weapon/attachment/silencer
	icon = 'icons/obj/gun_att.dmi'
	icon_state = "silencer"
	name = "silencer"
	desc = "A gun silencer."
	attachment_type = ATTACH_BARREL
	var/reduction = 50
	var/caliber = "multicaliber"
	ergonomics = 1.25
	fits = null

/obj/item/weapon/attachment/silencer/attached(mob/user, obj/item/weapon/gun/G, var/quick = FALSE)
	if (istype(G, /obj/item/weapon/gun/projectile))
		var/obj/item/weapon/gun/projectile/P = G
		if (caliber != "multicaliber")
			if (P.caliber != caliber)
				to_chat(user, SPAN_WARNING("\The [src.name] can't be attached!"))
				return
	if (quick)
		A_attached = TRUE
		G.attachment_slots -= attachment_type
		loc = G
		G.actions += actions
		G.verbs += verbs
		G.attachments += src
		G.silencer = src
		G.ergonomics *= src.ergonomics
		G.update_icon()
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
			G.ergonomics *= src.ergonomics
			to_chat(user, SPAN_NOTICE("You attach \the [src] to the [G]."))
			G.silencer = src
			G.update_icon()
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
		G.ergonomics /= src.ergonomics
		to_chat(user, SPAN_NOTICE("You remove \the [src] from the [G]."))
		G.silencer = null
		G.update_icon()
	else
		return

// Improvised
/obj/item/weapon/attachment/silencer/plastic_bottle
	name = "plastic bottle suppressor"
	icon_state = "plastic_bottle_suppressor"
	desc = "This suppressor might not even work, but it's worth a try."
	reduction = 5
	fits = list("smg", "rifle")
	ergonomics = 1

/obj/item/weapon/attachment/silencer/oil_filter
	name = "oil filter suppressor"
	icon_state = "oil_filter_suppressor"
	desc = "A makeshift suppressor."
	reduction = 35
	fits = list("smg", "rifle")
	ergonomics = 1.1

// Normal
/obj/item/weapon/attachment/silencer/pistol
	name = "pistol suppressor"
	icon_state = "modern_pistol_suppressor"
	desc = "A pistol suppressor."
	reduction = 50
	fits = list("pistol")
	ergonomics = 1.2

/obj/item/weapon/attachment/silencer/pistol/ww2
	name = "pistol suppressor"
	icon_state = "ww2_pistol_suppressor"
	desc = "A pistol suppressor."
	reduction = 35
	ergonomics = 1.15

/obj/item/weapon/attachment/silencer/rifle
	name = "rifle suppressor"
	icon_state = "modern_rifle_suppressor"
	desc = "A rifle suppressor."
	reduction = 50
	fits = list("rifle")
	ergonomics = 2

/obj/item/weapon/attachment/silencer/rifle/srm
	name = "srm suppressor"
	icon_state = "srm_silencer"
	desc = "A 9x39 SRM suppressor."
	reduction = 50
	fits = list("rifle")
	ergonomics = 2
	caliber = "a9x39"

/obj/item/weapon/attachment/silencer/rifle/pbs1
	name = "PBS-1"
	icon_state = "pbs1"
	desc = "A 7.62x39 AKM suppressor."
	reduction = 50
	fits = list("rifle")
	ergonomics = 2
	caliber = "a762x39"

/obj/item/weapon/attachment/silencer/rifle/pbs4
	name = "PBS-4"
	icon_state = "pbs1"
	desc = "A 5.45x39 AK74 suppressor."
	reduction = 50
	fits = list("rifle")
	ergonomics = 2
	caliber = "a545x39"

/obj/item/weapon/attachment/silencer/rifle/ww2
	name = "rifle suppressor"
	icon_state = "ww2_rifle_suppressor"
	desc = "A rifle suppressor."
	reduction = 35
	ergonomics = 1.5

/obj/item/weapon/attachment/silencer/rifle/ww2/bramid
	name = "Bramid"
	icon_state = "bramid"
	desc = "Mosin rifle suppressor."
	reduction = 50
	fits = list("rifle")
	ergonomics = 1.5
	caliber = "a762x54"

/obj/item/weapon/attachment/silencer/smg
	name = "smg suppressor"
	icon_state = "modern_smg_suppressor"
	desc = "A smg suppressor."
	reduction = 50
	fits = list("smg")
	ergonomics = 1.5

/obj/item/weapon/attachment/silencer/smg/ww2
	name = "smg suppressor"
	icon_state = "ww2_smg_suppressor"
	desc = "A smg suppressor."
	reduction = 35
	ergonomics = 1.25

/obj/item/weapon/attachment/silencer/shotgun
	name = "shotgun suppressor"
	icon_state = "modern_shotgun_suppressor"
	desc = "A shotgun suppressor."
	reduction = 40
	fits = list("shotgun")
	ergonomics = 1.5