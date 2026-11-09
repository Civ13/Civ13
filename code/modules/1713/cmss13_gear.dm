// Small gear adapted from CM-SS13 (cmss13-devs/cmss13, AGPL-3.0); reimplemented
// for Civ13. Sprites in icons/obj/cmss13_ports.dmi: the megaphone and display
// case come from CM-SS13 (CC BY-SA 3.0, see icons/obj/ATTRIBUTION.md); the
// glowsticks and tripwire were drawn for Civ13.

//////////////////////////////////////////////////////////////////////////////
// MEGAPHONE (CM-SS13 megaphone.dm): speech carries twice as far.
//////////////////////////////////////////////////////////////////////////////

#define MEGAPHONE_RANGE 14

/obj/item/weapon/megaphone
	name = "megaphone"
	desc = "A hand-held cone that makes your voice carry. Hold it in your hand while you speak."
	icon = 'icons/obj/cmss13_ports.dmi'
	icon_state = "megaphone"
	item_state = "zippo"
	w_class = ITEM_SIZE_SMALL
	slot_flags = SLOT_BELT
	flags = CONDUCT
	force = WEAPON_FORCE_WEAK

// Speech range for a living speaker: a megaphone in either hand extends it.
/mob/living/proc/speech_range_bonus(range)
	if (istype(l_hand, /obj/item/weapon/megaphone) || istype(r_hand, /obj/item/weapon/megaphone))
		return max(range, MEGAPHONE_RANGE)
	return range

#undef MEGAPHONE_RANGE

//////////////////////////////////////////////////////////////////////////////
// GLOWSTICKS (CM-SS13 lightstick.dm): snap to light, no flame, lasts 30 min.
//////////////////////////////////////////////////////////////////////////////

/obj/item/flashlight/flare/glowstick
	name = "green glowstick"
	desc = "A plastic tube of chemicals. Bend it to snap the inner vial and it glows for about half an hour. It cannot be switched off."
	icon = 'icons/obj/cmss13_ports.dmi'
	icon_state = "glowstick_green"
	item_state = "flare"
	brightness_on = 3
	light_power = 1
	light_color = "#40ff60"
	turn_on_sound = 'sound/effects/Custom_flashlight.ogg'
	show_flame = FALSE
	w_class = ITEM_SIZE_TINY
	var/glow_state = "glowstick_green"

/obj/item/flashlight/flare/glowstick/on_runtime_spawn()
	..()
	fuel = 1800

/obj/item/flashlight/flare/glowstick/update_icon()
	overlays?.Cut()
	if (on)
		icon_state = "[glow_state]_on"
		set_light(brightness_on)
	else
		icon_state = glow_state
		set_light(0)
	if (burnt_out)
		name = "spent [initial(name)]"

/obj/item/flashlight/flare/glowstick/turn_on()
	on = TRUE
	processing_objects |= src
	update_icon()
	return TRUE

/obj/item/flashlight/flare/glowstick/attack_self(mob/living/user)
	if (on)
		to_chat(user, SPAN_NOTICE("\The [src] is already glowing."))
		return FALSE
	if (burnt_out || fuel <= 0)
		to_chat(user, SPAN_NOTICE("\The [src] is spent."))
		return FALSE
	user.visible_message(SPAN_NOTICE("[user] bends \the [src] and it starts to glow."), SPAN_NOTICE("You bend \the [src] and it starts to glow."))
	playsound(src, turn_on_sound, 50, TRUE)
	turn_on()
	return TRUE

/obj/item/flashlight/flare/glowstick/throw_impact(atom/hit_atom)
	return ..(hit_atom) // no fire: skip the flare's ignition

/obj/item/flashlight/flare/glowstick/blue
	name = "blue glowstick"
	icon_state = "glowstick_blue"
	glow_state = "glowstick_blue"
	light_color = "#4080ff"

/obj/item/flashlight/flare/glowstick/red
	name = "red glowstick"
	icon_state = "glowstick_red"
	glow_state = "glowstick_red"
	light_color = "#ff4040"

/obj/item/flashlight/flare/glowstick/yellow
	name = "yellow glowstick"
	icon_state = "glowstick_yellow"
	glow_state = "glowstick_yellow"
	light_color = "#ffe040"

//////////////////////////////////////////////////////////////////////////////
// CONTAINER LABELS (CM-SS13 label component): name a crate or barrel with a pen.
//////////////////////////////////////////////////////////////////////////////

#define CONTAINER_LABEL_MAX 24

/obj/var/container_label = null

/proc/container_label_clean(text)
	text = sanitize(text, CONTAINER_LABEL_MAX)
	return trim(text)

// Sets or clears the label. Returns TRUE when the name changed.
/obj/proc/set_container_label(text)
	text = container_label_clean(text)
	var/base = initial(name)
	if (!text)
		if (!container_label)
			return FALSE
		container_label = null
		name = base
		return TRUE
	container_label = text
	name = "[base] ([text])"
	return TRUE

/obj/proc/label_container_with_pen(mob/user)
	if (!user || user.stat != CONSCIOUS || !istype(user.get_active_hand(), /obj/item/weapon/pen))
		to_chat(user, SPAN_WARNING("You need a pen in your hand to write a label."))
		return FALSE
	if (get_dist(user, src) > 1)
		return FALSE
	var/text = player_input(user, "Write a label (up to [CONTAINER_LABEL_MAX] letters). Leave it empty to remove the label.", "Label", container_label, "text", null, TRUE)
	if (isnull(text) || get_dist(user, src) > 1 || !istype(user.get_active_hand(), /obj/item/weapon/pen))
		return FALSE
	if (set_container_label(text))
		user.visible_message(SPAN_NOTICE("[user] writes a label on \the [src]."), SPAN_NOTICE("You label \the [src]."))
		return TRUE
	return FALSE

/obj/structure/closet/verb/write_label()
	set name = "Write Label"
	set category = null
	set src in view(1)
	label_container_with_pen(usr)

/obj/item/weapon/reagent_containers/glass/barrel/verb/write_label()
	set name = "Write Label"
	set category = null
	set src in view(1)
	label_container_with_pen(usr)

/obj/item/weapon/storage/verb/write_label()
	set name = "Write Label"
	set category = null
	set src in view(1)
	label_container_with_pen(usr)

#undef CONTAINER_LABEL_MAX

//////////////////////////////////////////////////////////////////////////////
// DISPLAY CASE (CM-SS13 displaycase.dm): shows one item; a key can lock it.
//////////////////////////////////////////////////////////////////////////////

/obj/structure/display_case
	name = "display case"
	desc = "A glass case for showing off one prized item. A key can lock it."
	icon = 'icons/obj/cmss13_ports.dmi'
	icon_state = "display_case"
	density = TRUE
	anchored = TRUE
	flammable = FALSE
	var/locked = FALSE
	var/custom_code = 0
	var/broken = FALSE
	var/health = 40

/obj/structure/display_case/New()
	..()
	update_icon()

/obj/structure/display_case/after_load()
	..()
	update_icon()

// The item on show is whatever the case holds; nothing else keeps a reference.
/obj/structure/display_case/proc/shown_item()
	return locate(/obj/item) in contents

/obj/structure/display_case/Destroy()
	var/turf/T = get_turf(src)
	for (var/obj/item/I in contents)
		I.forceMove(T)
	return ..()

/obj/structure/display_case/update_icon()
	icon_state = broken ? "display_case_broken" : "display_case"
	underlays.Cut()
	var/obj/item/shown = shown_item()
	if (shown)
		var/image/I = image(shown.icon, shown.icon_state)
		var/matrix/M = matrix()
		M.Scale(0.7)
		I.transform = M
		I.pixel_y = 2
		underlays += I

/obj/structure/display_case/examine(mob/user)
	..()
	var/obj/item/shown = shown_item()
	if (shown)
		to_chat(user, "It holds \a [shown].")
	if (locked)
		to_chat(user, "It is locked.")

/obj/structure/display_case/proc/try_key(obj/item/weapon/key/K, mob/user)
	if (custom_code == 0 && K.code != 0)
		custom_code = K.code
	if (K.code != custom_code)
		to_chat(user, SPAN_WARNING("This key does not match the lock."))
		return TRUE
	locked = !locked
	user.visible_message(SPAN_NOTICE("[user] [locked ? "locks" : "unlocks"] \the [src]."))
	playsound(get_turf(src), 'sound/effects/door_lock_unlock.ogg', 60)
	return TRUE

/obj/structure/display_case/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/key) && !broken)
		return try_key(W, user)
	if (user.a_intent == I_HARM && W.force > 0)
		user.do_attack_animation(src)
		playsound(get_turf(src), 'sound/effects/Glasshit.ogg', 75, TRUE)
		if (!broken)
			health -= W.force
			if (health <= 0)
				shatter()
		return TRUE
	if (shown_item() || (locked && !broken))
		to_chat(user, SPAN_WARNING("\The [src] is [shown_item() ? "full" : "locked"]."))
		return TRUE
	if (W.w_class > ITEM_SIZE_LARGE)
		to_chat(user, SPAN_WARNING("\The [W] does not fit."))
		return TRUE
	user.drop_from_inventory(W, src)
	W.forceMove(src)
	user.visible_message(SPAN_NOTICE("[user] puts \the [W] in \the [src]."))
	update_icon()
	return TRUE

/obj/structure/display_case/attack_hand(mob/user)
	var/obj/item/I = shown_item()
	if (!I)
		return ..()
	if (locked && !broken)
		to_chat(user, SPAN_WARNING("\The [src] is locked."))
		return
	I.forceMove(get_turf(src))
	user.put_in_hands(I)
	user.visible_message(SPAN_NOTICE("[user] takes \the [I] from \the [src]."))
	update_icon()

/obj/structure/display_case/proc/shatter()
	broken = TRUE
	locked = FALSE
	visible_message(SPAN_DANGER("\The [src] shatters!"))
	playsound(get_turf(src), "shatter", 70, TRUE)
	update_icon()

/obj/structure/display_case/bullet_act(obj/item/projectile/P)
	if (!broken && P.damage > 0)
		health -= P.damage
		if (health <= 0)
			shatter()
	return ..()

//////////////////////////////////////////////////////////////////////////////
// ALARM TRIPWIRE (idea from CM-SS13 bell_tower.dm tripwires): tin cans on a
// string rattle loudly when anyone outside the setter's group walks through.
//////////////////////////////////////////////////////////////////////////////

/obj/item/weapon/tripwire_kit
	name = "tripwire alarm"
	desc = "A string with tin cans tied to it. Use it in hand to stretch it across the tile you stand on; it rattles when a stranger walks through."
	icon = 'icons/obj/cmss13_ports.dmi'
	icon_state = "tripwire_kit"
	w_class = ITEM_SIZE_SMALL

/obj/item/weapon/tripwire_kit/attack_self(mob/living/human/user)
	var/turf/T = get_turf(user)
	if (!istype(user) || !T)
		return
	if (locate(/obj/structure/tripwire_alarm) in T)
		to_chat(user, SPAN_WARNING("There is already a tripwire here."))
		return
	if (!do_after(user, 30, T))
		return
	var/obj/structure/tripwire_alarm/A = new(T)
	A.set_owner(user)
	user.visible_message(SPAN_NOTICE("[user] stretches a tripwire across the ground."), SPAN_NOTICE("You set the tripwire. Your own group can walk through it quietly."))
	qdel(src)

/obj/structure/tripwire_alarm
	name = "tripwire"
	desc = "A low string with tin cans tied to it. Walking through it would make a racket."
	icon = 'icons/obj/cmss13_ports.dmi'
	icon_state = "tripwire"
	anchored = TRUE
	density = FALSE
	layer = 2.6
	flammable = TRUE
	var/owner_civilization = null
	var/owner_faction = null
	var/owner_name = null
	var/tmp/next_rattle = 0

/obj/structure/tripwire_alarm/persistence_runtime_var(key)
	return key == "next_rattle" || ..()

/obj/structure/tripwire_alarm/proc/set_owner(mob/living/human/H)
	owner_name = H.real_name
	owner_civilization = H.civilization
	owner_faction = H.faction_text

/obj/structure/tripwire_alarm/proc/is_friend(mob/living/human/H)
	if (H.real_name == owner_name)
		return TRUE
	if (owner_civilization && owner_civilization != "none" && H.civilization == owner_civilization)
		return TRUE
	if (map && !map.civilizations && owner_faction && H.faction_text == owner_faction)
		return TRUE
	return FALSE

// Returns TRUE when the crossing set off the alarm.
/obj/structure/tripwire_alarm/proc/trip(mob/living/human/H)
	if (!istype(H) || H.stat == DEAD || is_friend(H) || world.time < next_rattle)
		return FALSE
	next_rattle = world.time + 30
	playsound(get_turf(src), 'sound/effects/clang.ogg', 100, TRUE, 10)
	visible_message(SPAN_DANGER("The tin cans on \the [src] rattle loudly!"))
	balloon_alert_to_viewers("*rattle*")
	return TRUE

/obj/structure/tripwire_alarm/Crossed(atom/movable/AM)
	..()
	if (ishuman(AM))
		trip(AM)

/obj/structure/tripwire_alarm/attack_hand(mob/living/human/user)
	if (!istype(user))
		return ..()
	user.visible_message(SPAN_NOTICE("[user] starts taking down \the [src]."))
	if (!do_after(user, 30, src))
		return
	new /obj/item/weapon/tripwire_kit(get_turf(src))
	qdel(src)
