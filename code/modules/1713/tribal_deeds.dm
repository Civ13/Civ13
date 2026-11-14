// Tribal deeds: great deeds a character has done wait to be carved into one of
// their tribe's wooden totem poles with a knife. See docs/tribal-deeds.md.
//
// A deed is remembered on the character (once per kind) until carved. The pole
// belongs to the tribe of whoever carves it first; only that tribe carves more.

#define DEED_POLE_CAP 40
#define DEED_CARVE_TIME 60

/mob/living/human/var/list/pending_deeds // kind = text
/mob/living/human/var/list/carved_deeds // kinds already carved somewhere

/obj/structure/religious/totem_pole/var/tribe
/obj/structure/religious/totem_pole/var/list/deeds // "text|name|date"

// Remembers a deed for the character to carve. A kind is remembered once.
/proc/record_deed(mob/living/human/H, kind, text)
	if (!istype(H) || !kind || !text || H.stat == DEAD || !H.civilization || H.civilization == "none")
		return FALSE
	if (islist(H.carved_deeds) && (kind in H.carved_deeds))
		return FALSE
	if (islist(H.pending_deeds) && H.pending_deeds[kind])
		return FALSE
	if (!islist(H.pending_deeds))
		H.pending_deeds = list()
	H.pending_deeds[kind] = text
	to_chat(H, SPAN_NOTICE("<b>A deed worth remembering:</b> [text]. Carve it into one of your tribe's totem poles with a knife."))
	return TRUE

/obj/structure/religious/totem_pole/examine(mob/user, distance = -1, infix = "", suffix = "")
	. = ..()
	if (tribe)
		to_chat(user, "It is carved with the deeds of the [tribe].")
	if (!length(deeds))
		if (ishuman(user))
			to_chat(user, "Carve your deeds into it with a knife.")
		return
	for (var/line in deeds)
		var/list/parts = splittext(line, "|")
		if (parts.len >= 3)
			to_chat(user, "- [html_encode(parts[2])]: [html_encode(parts[1])] ([parts[3]])")

/obj/structure/religious/totem_pole/attackby(obj/item/I, mob/user)
	if (!is_tool(I, TOOL_KNIFE) || !ishuman(user))
		return ..()
	carve_deeds(user)
	return TRUE

/obj/structure/religious/totem_pole/proc/carve_deeds(mob/living/human/H)
	if (!H.civilization || H.civilization == "none")
		to_chat(H, SPAN_WARNING("You belong to no tribe whose deeds this pole could tell."))
		return FALSE
	if (tribe && tribe != H.civilization)
		to_chat(H, SPAN_WARNING("This pole tells the deeds of the [tribe], not your tribe."))
		return FALSE
	if (!length(H.pending_deeds))
		to_chat(H, SPAN_NOTICE("You have no new deeds to carve."))
		return FALSE
	if (length(deeds) >= DEED_POLE_CAP)
		to_chat(H, SPAN_WARNING("There is no room left on this pole. Raise another."))
		return FALSE
	H.visible_message(SPAN_NOTICE("[H] starts carving into \the [src]."), SPAN_NOTICE("You start carving your deeds into \the [src]."))
	if (!do_after(H, DEED_CARVE_TIME, src))
		return FALSE
	return add_deeds(H)

/obj/structure/religious/totem_pole/proc/add_deeds(mob/living/human/H)
	if (!length(H.pending_deeds) || (tribe && tribe != H.civilization))
		return 0
	tribe = H.civilization
	if (!islist(deeds))
		deeds = list()
	if (!islist(H.carved_deeds))
		H.carved_deeds = list()
	var/date = time2text(world.realtime, "YYYY-MM-DD")
	var/carved = 0
	for (var/kind in H.pending_deeds.Copy())
		if (deeds.len >= DEED_POLE_CAP)
			break
		var/text = replacetext(H.pending_deeds[kind], "|", "/")
		deeds += "[text]|[replacetext(H.real_name, "|", "/")]|[date]"
		H.carved_deeds |= kind
		H.pending_deeds -= kind
		carved++
	if (carved)
		H.visible_message(SPAN_NOTICE("[H] carves [carved == 1 ? "a deed" : "[carved] deeds"] into \the [src]."))
	return carved

// Bringing down a big or dangerous beast.
/proc/deed_big_game(mob/living/simple_animal/A)
	if (!istype(A) || A.maxHealth < 100 || istype(A, /mob/living/simple_animal/wizard) || istype(A, /mob/living/simple_animal/hostile/wizard))
		return FALSE
	return A.mob_size >= MOB_LARGE || istype(A, /mob/living/simple_animal/hostile)

/mob/living/simple_animal/death(gibbed, deathmessage = "dies!")
	if (stat != DEAD && ishuman(lastattacker) && deed_big_game(src))
		record_deed(lastattacker, "big_game_[type]", "Brought down \a [initial(name)]")
	return ..()

// Hollowing out a dugout canoe.
/obj/structure/dugout_log/finish(mob/user)
	record_deed(user, "dugout_canoe", "Hollowed a dugout canoe from a log")
	return ..()

// Taming a wild animal, once for each kind of herd.
/mob/living/simple_animal/tame_feeding(mob/user, now = trap_now_minutes())
	. = ..()
	if (. && !wild && ishuman(user))
		var/family = domestic_family()
		var/kind = "beast"
		if (family == /mob/living/simple_animal/cattle)
			kind = "cow"
		else if (family == /mob/living/simple_animal/goat)
			kind = "goat"
		else if (family == /mob/living/simple_animal/sheep)
			kind = "sheep"
		else if (family == /mob/living/simple_animal/pig_gilt)
			kind = "pig"
		record_deed(user, "tame_[family || type]", "Tamed a wild [kind]")

// Finishing a painting on the rock.
/obj/item/canvas/rock/accept_painting(mob/user, packed, palette_text, finish, new_title)
	var/was_finished = finished
	. = ..()
	if (finish && !was_finished && finished && ishuman(user))
		record_deed(user, "rock_art", "Painted \"[title]\" on the rock")
