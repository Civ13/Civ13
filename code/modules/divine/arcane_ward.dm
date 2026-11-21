// ============================================================
// Warding and Paired stones (magic materials and enchanting plan, PR 5).
// Hidden mechanic: keep it out of changelog lines, the wiki and the public
// Crafting Atlas.
// ------------------------------------------------------------
// Warding: a magic user with both hands free but for their stick beseeches
// Imbue beside an ordinary chest, crate, closet or door, with 2 Ward materials
// in a worn pouch and a vigil of 3 or more kept around them. They name its
// owners. From then on it will not open for anyone else: each refused attempt
// spends one charge (10 / 20 / 30). Breaking it by force still works, and its
// look never changes.
//
// Paired stones: Imbue on a single ordinary gem held in hand, with a second
// single gem and 2 Omen materials in the pouch. Both gems take the pairing.
// A magic user holding one can whisper through it; whoever carries the other
// in this world hears the line as a private thought. Each line spends one
// charge of the stone it was spoken through (5 / 10 / 15).
// ============================================================

#define ARCANE_WARD_OWNERS 4
#define ARCANE_WARD_REFUSE_GAP 20   // deciseconds: one refused attempt per person counts this often
#define ARCANE_VIGIL_RANGE 3

// Warded chests, crates, closets and doors in this world. Runtime only:
// rebuilt as they load (repository.dm /obj/after_load).
var/global/list/arcane_warded = list()

/obj
	var/arcane_ward_charges = 0         // saved on structures: refusals left
	var/list/arcane_ward_owners = null  // saved on structures: owner ckey -> name at imbuing
	var/arcane_ward_by = null           // saved on structures: ckey of the magic user who warded it
	var/arcane_ward_at = 0              // saved on structures: world.realtime when it was warded
	var/tmp/list/arcane_ward_refused = null // mob -> world.time of the last counted refusal

/obj/item
	var/arcane_pair = null              // saved: id shared by two paired stones

/mob/living/human
	var/tmp/obj/arcane_imbue_structure = null // the chest, crate, closet or door an Imbue works on
	var/tmp/list/arcane_imbue_vigil = null    // who keeps the vigil for this Imbue

// ---- What can be warded ------------------------------------------------------

/proc/arcane_wardable(obj/O)
	if (!O || QDELETED(O) || O.magic_repo_id)
		return FALSE
	return istype(O, /obj/structure/closet) || istype(O, /obj/structure/simple_door)

/obj/proc/arcane_ward_live()
	if (!arcane_ward_charges)
		return FALSE
	if (arcane_ward_charges < 1 || !islist(arcane_ward_owners) || !arcane_wardable(src))
		arcane_ward_end()
		return FALSE
	return TRUE

/obj/proc/arcane_ward_end()
	arcane_ward_charges = 0
	arcane_ward_owners = null
	arcane_ward_by = null
	arcane_ward_at = 0
	arcane_ward_refused = null
	arcane_warded -= src

// Called from /obj/after_load (repository.dm).
/obj/proc/arcane_ward_loaded()
	if (arcane_ward_charges && arcane_ward_live())
		arcane_warded |= src

/proc/arcane_wards_of(ckey)
	. = list()
	for (var/obj/O in arcane_warded)
		if (QDELETED(O) || !O.arcane_ward_live())
			arcane_warded -= O
		else if (O.arcane_ward_by == ckey)
			. += O

// Called when someone tries to open it (closets.dm toggle, door.dm canOpen).
// TRUE when the ward keeps it shut for this person.
/obj/proc/arcane_ward_refuses(mob/user)
	if (!arcane_ward_charges || !arcane_ward_live() || !ismob(user))
		return FALSE
	if (user.ckey && (user.ckey in arcane_ward_owners))
		return FALSE
	if (!islist(arcane_ward_refused))
		arcane_ward_refused = list()
	var/last = arcane_ward_refused[user]
	if (!isnum(last) || world.time >= last + ARCANE_WARD_REFUSE_GAP || world.time < last)
		arcane_ward_refused[user] = world.time
		arcane_ward_charges--
		log_admin("Ward held: [src] ([type]) at [arcane_enchant_place(src)] warded by [arcane_ward_by] refused [key_name(user)], [arcane_ward_charges] left.")
		if (arcane_ward_charges < 1)
			arcane_ward_end()
	to_chat(user, SPAN_WARNING("[src] won't budge."))
	return TRUE

/obj/proc/arcane_ward_examine(mob/user)
	var/mob/living/human/H = user
	if (arcane_ward_charges && istype(H) && H.arcane_magic_user() && arcane_ward_live())
		to_chat(H, SPAN_NOTICE("<i>It feels guarded.</i>"))

// ---- Imbuing a ward ------------------------------------------------------------

// What an Imbue works on: the item in the hand without the stick, or with
// that hand empty, the chest, crate, closet or door chosen beside them.
/mob/living/human/proc/arcane_imbue_target()
	var/obj/item/I = arcane_imbue_item()
	if (I)
		return I
	if (!divine_focus())
		return null
	var/obj/O = arcane_imbue_structure
	if (O && !QDELETED(O) && O.Adjacent(src) && arcane_wardable(O))
		return O
	return null

/mob/living/human/proc/arcane_wardables_beside()
	. = list()
	for (var/obj/structure/S in orange(1, src))
		if (arcane_wardable(S))
			. += S

// The vigil still keeping this Imbue: the magic user and helpers close by.
/mob/living/human/proc/arcane_vigil_holds()
	if (!islist(arcane_imbue_vigil))
		return FALSE
	var/kept = 0
	for (var/mob/living/human/H in arcane_imbue_vigil)
		if (!QDELETED(H) && H.stat == CONSCIOUS && get_dist(H, src) <= ARCANE_VIGIL_RANGE && H.z == z)
			kept++
	return kept >= 3

/mob/living/human/proc/arcane_ward_pick_owners()
	var/list/owners = list()
	owners[ckey] = real_name
	var/list/people = list()
	for (var/mob/living/human/H in view(ARCANE_VIGIL_RANGE, src))
		if (H != src && H.ckey && H.stat != DEAD)
			people["[H.real_name]"] = H
	while (people.len && owners.len < ARCANE_WARD_OWNERS)
		var/list/menu = people.Copy()
		menu["No one else"] = null
		var/pick = player_input(src, "Who else may open it? ([owners.len] named)", "Warding", null, "anything", menu, TRUE)
		var/mob/living/human/H = people[pick]
		if (!H)
			break
		owners[H.ckey] = H.real_name
		people -= pick
	return owners

/mob/living/human/proc/arcane_ward_apply(obj/O, list/materials, list/owners)
	var/charges = arcane_imbue_charges("warding", materials)
	O.arcane_ward_end()
	O.arcane_ward_charges = charges
	O.arcane_ward_owners = owners.Copy()
	O.arcane_ward_by = ckey
	O.arcane_ward_at = world.realtime
	arcane_warded |= O
	var/list/names = list()
	for (var/key in owners)
		names += "[owners[key]] ([key])"
	log_admin("Ward made: [key_name(src)] warded [O] ([O.type]) at [arcane_enchant_place(O)] with [charges] charges for [english_list(names)].")
	to_chat(src, SPAN_NOTICE("<i>[O] feels guarded.</i>"))

// ---- Paired stones ---------------------------------------------------------------

/proc/arcane_single_gem(obj/item/I)
	var/obj/item/stack/S = I
	return arcane_is_gem(I) && istype(S) && S.amount == 1 && !I.arcane_virtue() && !I.arcane_enchant

// The second gem in the pouch for a pairing, never one of the materials.
/mob/living/human/proc/arcane_pair_partner(list/materials)
	var/obj/item/held = arcane_imbue_item()
	for (var/obj/item/I in arcane_pouch_items())
		if (I != held && !(I in materials) && arcane_single_gem(I))
			return I
	return null

/mob/living/human/proc/arcane_pair_apply(obj/item/I, obj/item/partner, charges)
	var/id = "[world.realtime]-[rand(100000, 999999)]-[ckey]"
	for (var/obj/item/S in list(I, partner))
		S.arcane_enchant_end()
		S.arcane_enchant = "paired"
		S.arcane_charges = charges
		S.arcane_enchanter = ckey
		S.arcane_enchanted_at = world.realtime
		S.arcane_pair = id
		arcane_enchanted |= S
	log_admin("Enchantment made: [key_name(src)] paired [I] ([I.type]) with [partner] ([partner.type]), [charges] charges each.")

/obj/item/proc/arcane_pair_other()
	if (arcane_enchant != "paired" || !arcane_pair)
		return null
	for (var/obj/item/I in arcane_enchanted)
		if (I != src && !QDELETED(I) && I.arcane_pair == arcane_pair && I.arcane_enchant_live())
			return I
	return null

/proc/arcane_carrier_of(atom/movable/A)
	for (var/atom/L = A.loc, L, L = L.loc)
		if (ismob(L))
			return L
		if (isturf(L))
			return null
	return null

/mob/living/human/proc/arcane_whisper_stone()
	set name = "Whisper Through a Stone"
	set category = "IC"
	set desc = "Speak through a stone you hold to whoever carries its twin."
	if (usr != src || !client || !arcane_magic_user() || stat != CONSCIOUS)
		return
	var/obj/item/stone = null
	for (var/obj/item/I in list(get_active_hand(), get_inactive_hand()))
		if (I.arcane_enchant == "paired" && I.arcane_enchant_live())
			stone = I
			break
	if (!stone)
		to_chat(src, SPAN_WARNING("You hold nothing that answers."))
		return
	var/raw = player_input(src, "What do you say through it?", "Stone", null, "text", null, TRUE)
	var/words = raw ? sanitize(raw, MAX_MESSAGE_LEN) : null
	if (!words || QDELETED(stone) || !(stone in list(get_active_hand(), get_inactive_hand())) || !stone.arcane_enchant_live())
		return
	var/obj/item/other = stone.arcane_pair_other()
	var/mob/hearer = other ? arcane_carrier_of(other) : null
	stone.arcane_enchant_spend("[key_name(src)] whispered to [hearer ? key_name(hearer) : "no one"]: [words]")
	if (!hearer || !hearer.client)
		to_chat(src, SPAN_NOTICE("<i>Nothing answers.</i>"))
		return
	to_chat(hearer, CHAT_TYPED(CHAT_PRAYER, "<span class='notice'><i>A thought that is not yours: \"[words]\"</i></span>"))
	to_chat(src, SPAN_NOTICE("<i>You feel the words go.</i>"))

#undef ARCANE_WARD_OWNERS
#undef ARCANE_WARD_REFUSE_GAP
#undef ARCANE_VIGIL_RANGE
