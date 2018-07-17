
/*
TODO:
Optimize this code as much as possible
Add Sounds
Replace snowflaked icon manipulation with proper icon mask manipulation
Add more attachments
Add attached bayonet sprite

Current Defines (_defines/attachment.dm)

#define ATTACH_IRONSIGHTS TRUE
#define ATTACH_SCOPE 2
#define ATTACH_STOCK 4
#define ATTACH_BARREL 8
#define ATTACH_UNDER TRUE6
*/

/obj/item/weapon/attachment
  var/attachable = TRUE
  var/attachment_type //Use the 'ATTACH_' defines above (should only use one for this)
  var/A_attached = FALSE //Is attached
  w_class = 2

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
  var/attachment_slots = null //Use the 'ATTACH_' defines above; can ise in combination Ex. ATTACH_SCOPE|ATTACH_BARREL

/obj/item/weapon/gun/examine(mob/user)
  ..()
  if (attachments.len)
    for (var/obj/item/weapon/attachment/A in attachments)
      user << "<span class='notice'>It has [A] attached.</span>"

/obj/item/weapon/gun/dropped(mob/user)
  ..()
  if (attachments.len)
    for (var/obj/item/weapon/attachment/A in attachments)
      A.dropped(user)

/obj/item/weapon/gun/pickup(mob/user)
  if (attachments.len)
    for (var/obj/item/weapon/attachment/A in attachments)
      A.pickup(user)

/obj/item/weapon/gun/verb/field_strip()
  set name = "Field Strip"
  set desc = "Removes any attachments."
  set category = null
  var/mob/living/carbon/human/user = usr

  for (var/obj/item/weapon/attachment/A in attachments)
    A.removed(user, src)

//Use this under /New() of weapons if they spawn with attachments
/obj/item/weapon/gun/proc/spawn_add_attachment(obj/item/weapon/attachment/A)
  A.A_attached = TRUE
  attachment_slots -= A.attachment_type
  attachments += A
  actions += A.actions

/obj/item/weapon/gun/proc/update_attachment_actions(mob/user)
  for (var/datum/action/action in actions)
    action.Grant(user)

/obj/item/weapon/gun/proc/try_attach(obj/item/weapon/attachment/A, mob/user)
  if (!A || !user)
    return
  if (user.get_inactive_hand() != src)
    user << "You must be holding the [src] to add attachments."
    return
  attach_A(A, user)

//Do not use this; use try_attach instead
/obj/item/weapon/gun/proc/attach_A(obj/item/weapon/attachment/A, mob/user)
  switch(A.attachment_type)
    if (ATTACH_IRONSIGHTS)
      if (attachment_slots & ATTACH_IRONSIGHTS)
        A.attached(user, src)
      else
        user << "You already have iron sights."
    if (ATTACH_SCOPE)
      if (attachment_slots & ATTACH_SCOPE)
        A.attached(user, src)
      else
        user << "You fumble around with the attachment."
    if (ATTACH_STOCK)
      if (attachment_slots & ATTACH_STOCK)
        A.attached(user, src)
      else
        user << "You fumble around with the attachment."
    if (ATTACH_BARREL)
      if (attachment_slots & ATTACH_BARREL)
        A.attached(user, src)
      else
        user << "You fumble around with the attachment."
    if (ATTACH_UNDER)
      if (attachment_slots & ATTACH_UNDER)
        A.attached(user, src)
      else
        user << "You fumble around with the attachment."
    else
      user << "[A] cannot be attached to the [src]."

//ATTACHMENTS

//Scope code is found in code/modules/WW2/weapons/zoom.dm

//This is reserved for bayonet charging
/*
/datum/action/toggle_scope
	name = "Bayonet Charge"
	check_flags = AB_CHECK_ALIVE|AB_CHECK_RESTRAINED|AB_CHECK_STUNNED|AB_CHECK_LYING
	button_icon_state = ""
	var/obj/item/weapon/attachment/bayonet = null

/obj/item/weapon/attachment/bayonet/proc/build_bayonet()
	amelee = new()
	amelee.bayonet = src
	actions += amelee

/datum/action/bayonet/IsAvailable()
	. = ..()

/datum/action/bayonet/Trigger()
	..()

/datum/action/bayonet/Remove(mob/living/L)
	..()

/obj/item/weapon/attachment/bayonet/New()
	..()
	build_bayonet()

/obj/item/weapon/attachment/bayonet/pickup(mob/user)
	..()
	if (amelee)
		amelee.Grant(user)

/obj/item/weapon/attachment/bayonet/dropped(mob/user)
	..()
	if (amelee)
		amelee.Remove(user)
*/
/obj/item/weapon/attachment/bayonet
	name = "bayonet"
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "bayonet"
	item_state = "knife"
	flags = CONDUCT
	sharp = TRUE
	edge = TRUE
	attack_verb = list("slashed", "stabbed", "sliced", "torn", "ripped", "diced", "cut")
	attachment_type = ATTACH_BARREL
	force = 5
	var/attack_sound = 'sound/weapons/slice.ogg'
	var/weakens = 0
	//var/datum/action/bayonet/amelee

/obj/item/weapon/attachment/bayonet/attached(mob/user, obj/item/weapon/gun/G)
  ..()
  G.bayonet = src

/obj/item/weapon/attachment/bayonet/removed(mob/user, obj/item/weapon/gun/G)
  ..()
  G.bayonet = null

/obj/item/weapon/attachment/bayonet/german
	force = WEAPON_FORCE_DANGEROUS/2
	weakens = 1
	weight = 0.361

/obj/item/weapon/attachment/bayonet/soviet
	force = WEAPON_FORCE_DANGEROUS
	weakens = 2
	weight = 0.419

/obj/item/weapon/attachment/scope/iron_sights
	name = "iron sights"
	attachment_type = ATTACH_IRONSIGHTS
	zoom_amt = ZOOM_CONSTANT

/obj/item/weapon/attachment/scope/adjustable/sniper_scope
	name = "sniper scope"
	icon_state = "kar_scope"
	desc = "You can attach this to rifles... or use them as binoculars."
	max_zoom = ZOOM_CONSTANT*2

/obj/item/weapon/attachment/scope/adjustable/sniper_scope/removed(mob/user, obj/item/weapon/gun/G)
  ..()
  //This should only be temporary until more attachment icons are made, then we switch to adding/removing icon masks
  G.icon_state = initial(G.icon_state)
  G.item_state = initial(G.item_state)
  if (istype(G, /obj/item/weapon/gun/projectile/boltaction))
    var/obj/item/weapon/gun/projectile/boltaction/W = G
    if (W.bolt_open)
      W.icon_state = addtext(W.icon_state, "_open")

/obj/item/weapon/attachment/scope/adjustable/sniper_scope/attached(mob/user, obj/item/weapon/gun/G)
  ..()
  if (istype(G, /obj/item/weapon/gun/projectile/boltaction))
    var/obj/item/weapon/gun/projectile/boltaction/W = G
    W.update_icon(1)

/obj/item/weapon/attachment/scope/removed(mob/user, obj/item/weapon/gun/G)
  ..()
  G.accuracy = initial(G.accuracy)
  G.recoil = initial(G.recoil)

/obj/item/weapon/attachment/scope/iron_sights/removed(mob/user, obj/item/weapon/gun/G)
  return
