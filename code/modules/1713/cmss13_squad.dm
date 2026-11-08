// Squad leader tracker, squad colours, medic health icons, a mine detector
// and high fives. Ideas from CM-SS13 (cmss13-devs/cmss13, AGPL-3.0): the
// squad leader locator, squad colours, the medical HUD, the mine detector and
// the high five emote. Reimplemented for Civ13.

//////////////////////////////////////////////////////////////////////////////
// SQUAD COLOURS
//////////////////////////////////////////////////////////////////////////////

/proc/squad_colour_names()
	return list("red", "yellow", "purple", "blue", "orange", "green", "white")

/proc/squad_colour_hex(squad)
	var/list/hex = list("#e03c3c", "#e8c43a", "#a64ad9", "#3a7ee8", "#e8893a", "#3ac84a", "#e8e8e8")
	if (!isnum(squad) || squad < 1 || squad > hex.len)
		return null
	return hex[squad]

/proc/squad_colour_name(squad)
	var/list/names = squad_colour_names()
	if (!isnum(squad) || squad < 1 || squad > names.len)
		return null
	return names[squad]

/mob/living/human/proc/in_squad()
	return squad > 0 && original_job && original_job.uses_squads

/mob/living/human/examine(mob/user)
	. = ..()
	if (in_squad() && squad_colour_name(squad))
		to_chat(user, "<span class='notice'>[src] is in <font color='[squad_colour_hex(squad)]'><b>Squad [squad] ([squad_colour_name(squad)])</b></font>.</span>")

//////////////////////////////////////////////////////////////////////////////
// WHO THE TRACKER POINTS AT: soldiers to their squad leader; squad leaders,
// and soldiers whose leader is gone, to their commander.
//////////////////////////////////////////////////////////////////////////////

/proc/faction_squad_leader(faction, squad)
	if (!map || !isnum(squad) || squad < 1)
		return null
	var/list/leaders = null
	if (faction == map.faction1)
		leaders = map.faction1_squad_leaders
	else if (faction == map.faction2)
		leaders = map.faction2_squad_leaders
	if (!leaders || squad > leaders.len)
		return null
	var/mob/living/human/L = leaders[squad]
	if (!istype(L) || QDELETED(L) || L.stat == DEAD || L.faction_text != faction)
		return null
	return L

/proc/faction_commander(faction, mob/living/human/except)
	for (var/mob/living/human/H in human_clients_mob_list)
		if (H != except && H.stat != DEAD && H.faction_text == faction && H.original_job && H.original_job.is_commander)
			return H
	return null

/mob/living/human/proc/tracker_target()
	if (!team_round_active() || !faction_text || !original_job || original_job.is_commander)
		return null
	if (in_squad() && !original_job.is_squad_leader)
		var/mob/living/human/L = faction_squad_leader(faction_text, squad)
		if (L && L != src)
			return L
	if (in_squad() || original_job.is_squad_leader || original_job.is_officer)
		return faction_commander(faction_text, src)
	return null

// Clockwise degrees from north, the way turn() rotates an arrow drawn north.
/proc/tracker_bearing(atom/from, atom/target)
	var/dx = target.x - from.x
	var/dy = target.y - from.y
	if (!dx && !dy)
		return 0
	var/angle = 90 - arctan(dx, dy)
	while (angle < 0)
		angle += 360
	while (angle >= 360)
		angle -= 360
	return angle

//////////////////////////////////////////////////////////////////////////////
// MEDIC HEALTH ICONS
//////////////////////////////////////////////////////////////////////////////

// null for the healthy, else the icon state a medic sees over this person.
/mob/living/human/proc/medic_health_state()
	if (stat == DEAD)
		return "health_dead"
	if (stat == UNCONSCIOUS || health <= config.health_threshold_crit)
		return "health_critical"
	if (is_bleeding_out())
		return "health_bleeding"
	if (health < maxHealth * 0.8)
		return "health_hurt"
	return null

/proc/medic_sees_patient(mob/living/human/medic, mob/living/human/P)
	if (P == medic)
		return FALSE
	if (team_round_active())
		return P.faction_text && P.faction_text == medic.faction_text
	return TRUE

//////////////////////////////////////////////////////////////////////////////
// FIELD HUD: one per player in a human body. Every tick it rebuilds the images
// only its owner sees: the tracker arrow, squadmate chevrons and, for medics,
// health icons.
//////////////////////////////////////////////////////////////////////////////

#define FIELD_HUD_RANGE 7
#define TRACKER_HIDE_RANGE 2

/obj/field_hud
	name = "field HUD"
	invisibility = 101
	anchored = TRUE
	var/tmp/mob/living/human/owner
	var/tmp/client/shown_to
	var/tmp/list/shown

/obj/field_hud/persistence_runtime_var(key)
	return (key in list("owner", "shown_to", "shown")) || ..()

/obj/field_hud/New(newloc, mob/living/human/H)
	..(null)
	owner = H
	processing_objects |= src

/obj/field_hud/Destroy()
	clear()
	processing_objects -= src
	if (owner && owner.field_hud == src)
		owner.field_hud = null
	owner = null
	return ..()

/obj/field_hud/proc/clear()
	if (shown_to && shown)
		shown_to.images -= shown
	shown = null
	shown_to = null

/obj/field_hud/proc/hud_image(atom/where, state, colour)
	var/image/I = image('icons/obj/cmss13_ports.dmi', where, state, FLY_LAYER)
	I.appearance_flags = RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM | KEEP_APART
	if (colour)
		I.color = colour
	return I

/obj/field_hud/proc/tracker_image()
	var/mob/living/human/T = owner.tracker_target()
	if (!T || T.z != owner.z || get_dist(owner, T) <= TRACKER_HIDE_RANGE)
		return null
	var/is_leader = T.original_job && T.original_job.is_squad_leader && !T.original_job.is_commander
	var/image/I = hud_image(owner, "tracker_arrow", is_leader ? squad_colour_hex(owner.squad) : "#ffffff")
	var/angle = tracker_bearing(owner, T)
	I.transform = turn(matrix(), angle)
	I.pixel_x = round(sin(angle) * 20)
	I.pixel_y = round(cos(angle) * 20)
	return I

// Everything the owner should see right now.
/obj/field_hud/proc/build()
	var/list/L = list()
	if (!owner || owner.stat == DEAD)
		return L
	var/image/arrow = tracker_image()
	if (arrow)
		L += arrow
	var/squad_on = team_round_active() && owner.in_squad()
	var/medic_on = can_triage(owner)
	if (!squad_on && !medic_on)
		return L
	for (var/mob/living/human/H in view(FIELD_HUD_RANGE, owner))
		if (H == owner)
			continue
		if (squad_on && H.squad == owner.squad && H.faction_text == owner.faction_text && H.stat != DEAD && H.in_squad())
			L += hud_image(H, "squad_chevron", squad_colour_hex(H.squad))
		if (medic_on && medic_sees_patient(owner, H))
			var/state = H.medic_health_state()
			if (state)
				L += hud_image(H, state)
	return L

/obj/field_hud/process_interval(seconds)
	if (!owner || QDELETED(owner) || !owner.client)
		qdel(src)
		return PROCESS_KILL
	clear()
	var/list/L = build()
	if (!L.len)
		return
	shown = L
	shown_to = owner.client
	shown_to.images += shown

/mob/living/human/var/tmp/obj/field_hud/field_hud = null

/mob/living/human/persistence_runtime_var(key)
	return key == "field_hud" || ..()

/mob/living/human/proc/ensure_field_hud()
	if (!field_hud || QDELETED(field_hud))
		field_hud = new /obj/field_hud(null, src)
	return field_hud

/mob/living/human/Login()
	. = ..()
	if (client)
		ensure_field_hud()

#undef FIELD_HUD_RANGE
#undef TRACKER_HIDE_RANGE

//////////////////////////////////////////////////////////////////////////////
// MINE DETECTOR: switch it on and hold it; it beeps faster the closer an
// armed mine is, and marks mines within three tiles for its holder.
//////////////////////////////////////////////////////////////////////////////

#define MINE_DETECTOR_RANGE 5
#define MINE_DETECTOR_MARK_RANGE 3

/obj/item/weapon/mine_detector
	name = "mine detector"
	desc = "A handheld metal detector. Switch it on and hold it: it beeps when an armed mine is within five tiles, faster as you get closer, and marks mines within three tiles."
	icon = 'icons/obj/cmss13_ports.dmi'
	icon_state = "mine_detector"
	w_class = ITEM_SIZE_NORMAL
	weight = 1.2
	value = 40
	var/on = FALSE
	var/tmp/list/marks
	var/tmp/client/mark_client

/obj/item/weapon/mine_detector/persistence_runtime_var(key)
	return (key in list("marks", "mark_client")) || ..()

/obj/item/weapon/mine_detector/after_load()
	..()
	if (on)
		processing_objects |= src

/obj/item/weapon/mine_detector/Destroy()
	clear_marks()
	processing_objects -= src
	return ..()

/obj/item/weapon/mine_detector/update_icon()
	icon_state = on ? "mine_detector_on" : "mine_detector"

/obj/item/weapon/mine_detector/attack_self(mob/user)
	on = !on
	update_icon()
	if (on)
		processing_objects |= src
	else
		processing_objects -= src
		clear_marks()
	playsound(get_turf(src), 'sound/machines/computer/beep.ogg', 30, TRUE)
	to_chat(user, "<span class='notice'>You switch \the [src] [on ? "on" : "off"].</span>")

/obj/item/weapon/mine_detector/examine(mob/user)
	..()
	to_chat(user, "It is [on ? "on" : "off"].")

/obj/item/weapon/mine_detector/proc/holder()
	var/mob/living/human/H = loc
	if (istype(H) && (H.l_hand == src || H.r_hand == src) && H.stat == CONSCIOUS)
		return H
	return null

/obj/item/weapon/mine_detector/proc/clear_marks()
	if (mark_client && marks)
		mark_client.images -= marks
	marks = null
	mark_client = null

// Armed mines in range, nearest first.
/obj/item/weapon/mine_detector/proc/armed_mines_near(turf/T)
	var/list/found = list()
	if (!T)
		return found
	for (var/dist = 0 to MINE_DETECTOR_RANGE)
		for (var/obj/item/mine/M in range(dist, T))
			if (M.anchored && !M.triggered && get_dist(T, M) == dist)
				found += M
	return found

/obj/item/weapon/mine_detector/process_interval(seconds)
	if (!on)
		clear_marks()
		return PROCESS_KILL
	clear_marks()
	var/mob/living/human/H = holder()
	if (!H)
		return
	var/turf/T = get_turf(H)
	var/list/mines = armed_mines_near(T)
	if (!mines.len)
		return
	var/nearest = get_dist(T, mines[1])
	// One beep far away, up to three when right next to one.
	var/beeps = nearest <= 1 ? 3 : (nearest <= MINE_DETECTOR_MARK_RANGE ? 2 : 1)
	for (var/i = 1 to beeps)
		playsound(T, 'sound/machines/computer/beep.ogg', 20 + 10 * beeps, TRUE, -4)
	if (!H.client)
		return
	marks = list()
	for (var/obj/item/mine/M in mines)
		if (get_dist(T, M) > MINE_DETECTOR_MARK_RANGE)
			break
		var/image/I = image('icons/obj/cmss13_ports.dmi', get_turf(M), "mine_ping", FLY_LAYER)
		I.appearance_flags = RESET_COLOR | RESET_ALPHA | KEEP_APART
		marks += I
	if (marks.len)
		mark_client = H.client
		mark_client.images += marks

#undef MINE_DETECTOR_RANGE
#undef MINE_DETECTOR_MARK_RANGE

//////////////////////////////////////////////////////////////////////////////
// HIGH FIVE AND FIST BUMP: offer one, and the other player answers within
// five seconds by choosing the same thing on you.
//////////////////////////////////////////////////////////////////////////////

#define GESTURE_WINDOW 50

/mob/living/human/var/tmp/gesture_kind = null
/mob/living/human/var/tmp/mob/living/human/gesture_target = null
/mob/living/human/var/tmp/gesture_time = 0

/mob/living/human/persistence_runtime_var(key)
	return (key in list("gesture_kind", "gesture_target", "gesture_time")) || ..()

/proc/gesture_lines(kind, mob/living/human/A, mob/living/human/B)
	if (kind == "fist bump")
		return list("[A] offers [B] a fist to bump.", "[A] and [B] bump fists.")
	return list("[A] raises a hand for a high five from [B].", "[A] and [B] high five!")

// Returns "offered", "done" or null when nothing happened.
/mob/living/human/proc/gesture_with(mob/living/human/other, kind)
	if (!istype(other) || other == src || stat != CONSCIOUS || other.stat == DEAD || !Adjacent(other))
		return null
	var/list/lines = gesture_lines(kind, src, other)
	if (other.gesture_kind == kind && other.gesture_target == src && world.time - other.gesture_time <= GESTURE_WINDOW)
		other.gesture_kind = null
		other.gesture_target = null
		if (gesture_kind == kind)
			gesture_kind = null
			gesture_target = null
		visible_message("<span class='notice'><b>[lines[2]]</b></span>")
		if (kind == "high five")
			playsound(get_turf(src), "sound/effects/emotes/clap.ogg", 50)
		return "done"
	gesture_kind = kind
	gesture_target = other
	gesture_time = world.time
	visible_message("<span class='notice'>[lines[1]]</span>")
	to_chat(other, "<span class='notice'>Right-click [src] and choose <b>[capitalize(kind)]</b> within five seconds to answer.</span>")
	return "offered"

/mob/living/human/verb/high_five()
	set name = "High Five"
	set category = null
	set src in view(1)
	var/mob/living/human/H = usr
	if (istype(H))
		H.gesture_with(src, "high five")

/mob/living/human/verb/fist_bump()
	set name = "Fist Bump"
	set category = null
	set src in view(1)
	var/mob/living/human/H = usr
	if (istype(H))
		H.gesture_with(src, "fist bump")

#undef GESTURE_WINDOW
