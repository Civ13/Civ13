// Fitted locks (Val, 2026-11-16; plan https://claude.ai/artifact/76THBToa5HeVbgJRRNVnyU).
// One lock part for doors and storage. A lock is crafted as an item, comes with
// its key (take it out by using the lock in hand), and is fitted to any door,
// chest, crate, closet or storage container that has none. Some locks take no
// key at all: combination locks, knot seals, clay seals and hidden catches.
// Keys belong to a family (wood, warded, tumbler) and only fit locks of their
// own family; a key used on an unfitted lock re-cuts it to that key (keyed
// alike), and a key used on a blank of its family cuts a copy.
// Doors have sides: a lock is keyed on the side its fitter stood, and from the
// other side a bare hand works the thumb-turn. Containers have only an outside;
// whoever is shut inside a closet can always get out.
// The lock is a datum held by its host (door_lock / fitted_lock) and saved with it.

#define LOCK_PIN "pin"
#define LOCK_WARDED "warded"
#define LOCK_TUMBLER "tumbler"
#define LOCK_LATCH "latch"
#define LOCK_COMBINATION "combination"
#define LOCK_PADLOCK "padlock"
#define LOCK_COMBO_PADLOCK "combo_padlock"
#define LOCK_KNOT "knot"
#define LOCK_SEAL "seal"
#define LOCK_CATCH "catch"

#define LOCK_FIT_TIME 100
#define LOCK_SEARCH_TIME 60
#define LOCK_UNTIE_TIME 50
#define LOCK_CRACK_TIME 200
#define LOCK_COPY_TIME 100
#define LOCK_FORCE_TIME 80

/datum/lock
	var/kind = LOCK_WARDED
	var/family = "warded"		// key family, null for keyless locks
	var/code = 0				// keyed locks: the cut a key must match
	var/combo = null			// combination locks: the code as text
	var/locked = FALSE
	var/side = 0				// doors: the keyed (outer) side, 0 on containers
	var/owner_name = null		// who fitted it (seals, knots, catches)
	var/tied_by = null			// knots: who tied it last
	var/list/known_by = null	// hidden catches: who has found it
	var/item_type = null		// the item it comes off as
	// Ways of defeating it that this lock refuses, for locks set up for an event
	// or a map: any of LOCK_DEFEAT_METHODS, or "all".
	var/list/refuses = null

// Every way a lock can be beaten without its key, code or maker.
var/global/list/LOCK_DEFEAT_METHODS = list("pick", "skeleton", "shim", "crack", "cut", "force", "untie", "search")

/datum/lock/proc/refuses_method(method)
	return refuses && (("all" in refuses) || (method in refuses))

// Tells the user the lock won't give to this method; TRUE when it refused.
/datum/lock/proc/refuse(method, mob/user)
	if (!refuses_method(method))
		return FALSE
	if (user)
		to_chat(user, SPAN_WARNING("This [name()] is too well made: [lock_defeat_refusal(method)]."))
	return TRUE

/proc/lock_defeat_refusal(method)
	switch (method)
		if ("pick", "skeleton")
			return "nothing you slip into it will move it"
		if ("shim")
			return "there is no gap to slip a blade into"
		if ("crack")
			return "its dial gives nothing away"
		if ("cut")
			return "nothing you have will cut it"
		if ("force")
			return "it won't be forced"
		if ("untie")
			return "the knot can't be worked loose"
		if ("search")
			return "there is no catch you can find"
	return "it won't give"

/datum/lock/proc/name()
	switch (kind)
		if (LOCK_PIN)
			return "wooden pin lock"
		if (LOCK_WARDED)
			return "warded lock"
		if (LOCK_TUMBLER)
			return "tumbler lock"
		if (LOCK_LATCH)
			return "spring latch"
		if (LOCK_COMBINATION)
			return "combination lock"
		if (LOCK_PADLOCK)
			return "padlock"
		if (LOCK_COMBO_PADLOCK)
			return "combination padlock"
		if (LOCK_KNOT)
			return "knot seal"
		if (LOCK_SEAL)
			return "clay seal"
		if (LOCK_CATCH)
			return "hidden catch"
	return "lock"

/datum/lock/proc/keyed()
	return !!family

/datum/lock/proc/is_combination()
	return kind == LOCK_COMBINATION || kind == LOCK_COMBO_PADLOCK

// A hand on the inner side of a door works the lock without a key. Padlocks,
// knots and seals hang outside: the inside has nothing to turn.
/datum/lock/proc/has_thumb_turn()
	return kind in list(LOCK_PIN, LOCK_WARDED, LOCK_TUMBLER, LOCK_LATCH, LOCK_COMBINATION)

/datum/lock/proc/overlay_state(container = FALSE)
	if (container)
		switch (kind)
			if (LOCK_PADLOCK)
				return "box_padlock"
			if (LOCK_COMBO_PADLOCK, LOCK_COMBINATION)
				return "box_combination"
			if (LOCK_KNOT)
				return "box_knot"
			if (LOCK_SEAL)
				return locked ? "box_seal" : "box_seal_broken"
			if (LOCK_CATCH)
				return null
		return "box_lock"
	switch (kind)
		if (LOCK_PADLOCK)
			return "door_padlock"
		if (LOCK_COMBO_PADLOCK)
			return "door_padlock_combination"
		if (LOCK_SEAL)
			return locked ? "door_seal" : "door_seal_broken"
		if (LOCK_KNOT)
			return "door_knot"
	return "door_lock_[kind]"

// Whether the lock stops this user getting in. Seals never stop anyone; a
// hidden catch stops whoever hasn't found it.
/datum/lock/proc/blocks()
	if (kind == LOCK_SEAL)
		return FALSE
	if (kind == LOCK_CATCH)
		return TRUE
	return locked

/datum/lock/proc/catch_known(mob/user)
	return user && (user.answers_to_name(owner_name) || (known_by && user.any_name_in(known_by)))

/datum/lock/proc/learn_catch(mob/user)
	if (!user)
		return
	if (!known_by)
		known_by = list()
	known_by |= user.real_name

// The cut on a key or a keychain that fits this lock, or null.
/datum/lock/proc/matching_key(obj/item/W)
	if (!keyed())
		return null
	var/list/keys = list()
	if (istype(W, /obj/item/weapon/key))
		keys += W
	else if (istype(W, /obj/item/weapon/storage/belt/keychain))
		for (var/obj/item/weapon/key/K in W.contents)
			keys += K
	for (var/obj/item/weapon/key/K in keys)
		if (K.key_family == family && K.code && K.code == code)
			return K
	return null

/datum/lock/proc/skeleton_key(obj/item/W)
	var/obj/item/weapon/key/K = W
	return istype(K) && K.skeleton && K.key_family == family && family == "warded"

/datum/lock/proc/set_combination(mob/user)
	var/value = player_input(user, "Set the combination (3 or 4 symbols):", name(), combo, "text", null, TRUE)
	if (isnull(value))
		return FALSE
	value = uppertext(sanitizeName("[value]", 4, TRUE))
	if (length(value) < 3)
		to_chat(user, SPAN_WARNING("The combination needs 3 or 4 symbols."))
		return FALSE
	combo = value
	to_chat(user, SPAN_NOTICE("You set the combination to <b>[combo]</b>."))
	return TRUE

/datum/lock/proc/new_code()
	if (!code)
		code = rand(100000, 999999)
	return code

// ---- hosts ----------------------------------------------------------------------

/obj/structure/simple_door
	var/datum/lock/door_lock = null

/obj/structure/closet
	var/datum/lock/fitted_lock = null

/obj/structure/storage_container
	var/datum/lock/fitted_lock = null

/proc/host_lock(atom/host)
	if (istype(host, /obj/structure/simple_door))
		var/obj/structure/simple_door/D = host
		return D.door_lock
	if (istype(host, /obj/structure/closet))
		var/obj/structure/closet/C = host
		return C.fitted_lock
	if (istype(host, /obj/structure/storage_container))
		var/obj/structure/storage_container/S = host
		return S.fitted_lock
	return null

/proc/host_set_lock(atom/host, datum/lock/L)
	if (istype(host, /obj/structure/simple_door))
		var/obj/structure/simple_door/D = host
		D.door_lock = L
		D.update_fitting_overlays()
	else if (istype(host, /obj/structure/closet))
		var/obj/structure/closet/C = host
		C.fitted_lock = L
		host_lock_overlay(C)
	else if (istype(host, /obj/structure/storage_container))
		var/obj/structure/storage_container/S = host
		S.fitted_lock = L
		host_lock_overlay(S)

/proc/host_is_door(atom/host)
	return istype(host, /obj/structure/simple_door)

/proc/host_is_shut(atom/host)
	if (istype(host, /obj/structure/simple_door))
		var/obj/structure/simple_door/D = host
		return !D.state
	if (istype(host, /obj/structure/closet))
		var/obj/structure/closet/C = host
		return !C.opened
	return TRUE

// Which side of a door's lock the user is on: "key", "thumb" or "both" (in
// the doorway). Containers are always worked from outside.
/proc/host_lock_side(atom/host, datum/lock/L, mob/user)
	if (!host_is_door(host) || !L || !L.side)
		return "key"
	var/obj/structure/simple_door/D = host
	var/S = D.door_side_of(user)
	if (!S)
		return "both"
	return S == L.side ? "key" : "thumb"

// Whether M walking into this door now gets through by hand, with no key,
// tool or wait: route planners (click_route.dm, pathfinding.dm) and agents
// use it, so a walk is never planned through a barred, braced or locked door
// or a window. For a shut trapdoor (walked across like floor) it says whether
// a hand opens it. A thumb-turn or latch on M's side and a hidden catch M knows
// let them through; a seal is broken in passing.
/obj/structure/simple_door/proc/door_route_passable(mob/M)
	if (state || (!density && !is_trapdoor()))
		return TRUE
	if (is_window_door())
		return FALSE
	if (door_barred() || door_braced_against(M) || cell_sentence_left > 0)
		return FALSE
	if (door_lock && door_lock.blocks())
		if (door_lock.kind == LOCK_CATCH)
			if (!door_lock.catch_known(M) && host_lock_side(src, door_lock, M) == "key")
				return FALSE
		else if (host_lock_side(src, door_lock, M) == "key" || !door_lock.has_thumb_turn())
			return FALSE
	return !door_locked_against(M)

// The door's own older locks (keypads, keyslots, faction membership), with no side effects.
/obj/structure/simple_door/proc/door_locked_against(mob/M)
	return locked

/obj/structure/simple_door/key_door/door_locked_against(mob/M)
	if (istype(src, /obj/structure/simple_door/key_door/custom))
		return locked
	if (istype(src, /obj/structure/simple_door/key_door/anyone))
		return FALSE
	return keyslot && keyslot.locked

/obj/structure/simple_door/key_door/faction_door/door_locked_against(mob/M)
	return !faction_door_admits(M)

// A host that already has a lock of another system takes no fitted lock.
/proc/host_has_other_lock(atom/host)
	if (istype(host, /obj/structure/simple_door))
		var/obj/structure/simple_door/D = host
		if (D.haslock || D.smart_lock_fitted || istype(D, /obj/structure/simple_door/party_train) || istype(D, /obj/structure/simple_door/blast))
			return TRUE
		if (istype(D, /obj/structure/simple_door/key_door/custom/jail) && !D.custom_code)
			return FALSE
		if (istype(D, /obj/structure/simple_door/key_door) && !istype(D, /obj/structure/simple_door/key_door/anyone))
			return TRUE
		return FALSE
	if (istype(host, /obj/structure/closet))
		var/obj/structure/closet/C = host
		return C.custom_code != 0 || istype(C, /obj/structure/closet/coffin) || istype(C, /obj/structure/closet/old_coffin) || istype(C, /obj/structure/closet/hideout)
	return FALSE

/proc/host_lock_overlay(obj/O)
	var/datum/lock/L = host_lock(O)
	if (O.vars["lock_image"])
		O.overlays -= O.vars["lock_image"]
		O.vars["lock_image"] = null
	if (!L)
		return
	var/state = L.overlay_state(TRUE)
	if (!state)
		return
	var/image/I = image('icons/obj/doors/locks_fitted.dmi', state)
	I.appearance_flags = RESET_COLOR
	O.vars["lock_image"] = I
	O.overlays += I

/obj/structure/closet
	var/tmp/image/lock_image = null

/obj/structure/storage_container
	var/tmp/image/lock_image = null

// ---- getting past a lock ----------------------------------------------------------

// The single check every host asks before letting someone open it by hand.
// Works the thumb-turn, asks for a combination, unties a knot or searches for
// a catch as needed. Returns TRUE when the user may open it now.
/proc/lock_hand_access(atom/host, mob/living/human/user, silent = FALSE)
	var/datum/lock/L = host_lock(host)
	if (!L)
		return TRUE
	if (L.kind == LOCK_SEAL)
		if (L.locked)
			L.locked = FALSE
			if (user)
				user.visible_message(SPAN_WARNING("[user] breaks the seal on \the [host]."), SPAN_WARNING("You break the seal on \the [host]."))
			host_set_lock(host, L)
		return TRUE
	if (L.kind == LOCK_CATCH)
		if (L.catch_known(user) || host_lock_side(host, L, user) != "key")
			return TRUE
		if (silent || !user)
			return FALSE
		if (L.refuse("search", user))
			return FALSE
		to_chat(user, SPAN_WARNING("\The [host] won't open. Something is holding it shut; you feel around for a catch."))
		if (!do_after(user, LOCK_SEARCH_TIME, host))
			return FALSE
		if (QDELETED(host) || host_lock(host) != L)
			return FALSE
		if (!prob(50))
			to_chat(user, SPAN_WARNING("You can't find how it opens."))
			return FALSE
		L.learn_catch(user)
		to_chat(user, SPAN_NOTICE("You find the hidden catch and slip it."))
		return TRUE
	if (!L.locked)
		return TRUE
	var/where = host_lock_side(host, L, user)
	if (where != "key" && L.has_thumb_turn())
		L.locked = FALSE
		if (user && !silent)
			user.visible_message(SPAN_NOTICE("[user] turns the lock of \the [host] from inside."), SPAN_NOTICE("You turn the lock and open it."))
			playsound(get_turf(host), 'sound/effects/door_lock_unlock.ogg', 60)
		return TRUE
	if (silent || !user)
		return FALSE
	if (L.kind == LOCK_KNOT)
		if (where == "thumb")
			to_chat(user, SPAN_WARNING("\The [host] is tied shut from the other side."))
			return FALSE
		if (L.tied_by != user.real_name && L.refuse("untie", user))
			return FALSE
		user.visible_message(SPAN_NOTICE("[user] starts working at the knot on \the [host]."), SPAN_NOTICE("You start untying the knot."))
		if (!do_after(user, LOCK_UNTIE_TIME, host) || QDELETED(host) || host_lock(host) != L)
			return FALSE
		L.locked = FALSE
		to_chat(user, SPAN_NOTICE("You untie the knot."))
		return TRUE
	if (L.is_combination())
		var/guess = player_input(user, "Enter the combination:", L.name(), null, "text", null, TRUE)
		if (isnull(guess) || QDELETED(host) || host_lock(host) != L || get_dist(user, host) > 1)
			return FALSE
		if (uppertext("[guess]") != L.combo)
			to_chat(user, SPAN_WARNING("The [L.name()] doesn't open."))
			playsound(get_turf(host), 'sound/machines/door_locked.ogg', 40, TRUE)
			return FALSE
		L.locked = FALSE
		user.visible_message(SPAN_NOTICE("[user] dials \the [host] open."), SPAN_NOTICE("You dial the combination and it opens."))
		return TRUE
	return FALSE

// Locking without a key: thumb-turns from inside, combination dials and knots.
/proc/lock_hand_lock(atom/host, mob/living/human/user)
	var/datum/lock/L = host_lock(host)
	if (!L || !user)
		return FALSE
	if (!host_is_shut(host))
		to_chat(user, SPAN_WARNING("Shut \the [host] first."))
		return FALSE
	var/where = host_lock_side(host, L, user)
	if (L.kind == LOCK_SEAL || L.kind == LOCK_CATCH)
		to_chat(user, SPAN_NOTICE("\The [L.name()] has nothing to lock."))
		return FALSE
	if (L.kind == LOCK_KNOT)
		if (where == "thumb")
			to_chat(user, SPAN_WARNING("The knot is on the other side."))
			return FALSE
		if (L.locked)
			return lock_hand_access(host, user)
		user.visible_message(SPAN_NOTICE("[user] ties \the [host] shut."), SPAN_NOTICE("You tie it shut with your own knot."))
		L.locked = TRUE
		L.tied_by = user.real_name
		return TRUE
	if (L.is_combination() && !L.locked)
		L.locked = TRUE
		user.visible_message(SPAN_NOTICE("[user] spins the dial of \the [host]."), SPAN_NOTICE("You lock it and spin the dial."))
		playsound(get_turf(host), 'sound/effects/door_lock_unlock.ogg', 50)
		return TRUE
	if (where != "key" && L.has_thumb_turn())
		L.locked = !L.locked
		user.visible_message(SPAN_NOTICE("[user] turns the lock of \the [host]."), SPAN_NOTICE("You turn the lock: it is now [L.locked ? "locked" : "unlocked"]."))
		playsound(get_turf(host), 'sound/effects/door_lock_unlock.ogg', 60)
		return TRUE
	if (L.is_combination() && L.locked)
		return lock_hand_access(host, user)
	to_chat(user, SPAN_WARNING("You need its key[host_is_door(host) && L.has_thumb_turn() ? ", or turn it from the other side" : ""]."))
	return FALSE

// ---- items on a lockable ----------------------------------------------------------

// Every host's attackby runs this first; TRUE means the item was handled.
/proc/lock_attackby(atom/host, obj/item/W, mob/living/human/user)
	if (!istype(user) || !W)
		return FALSE
	var/datum/lock/L = host_lock(host)
	if (istype(W, /obj/item/fitted_lock))
		var/obj/item/fitted_lock/F = W
		if (L && !(L.kind == LOCK_SEAL && F.lock_kind == LOCK_SEAL))
			to_chat(user, SPAN_WARNING("\The [host] already has \a [L.name()]."))
			return TRUE
		fit_lock(host, F, user)
		return TRUE
	if (!L)
		return FALSE
	if (istype(W, /obj/item/weapon/key) || istype(W, /obj/item/weapon/storage/belt/keychain))
		if (!L.keyed())
			to_chat(user, SPAN_WARNING("\The [L.name()] takes no key."))
			return TRUE
		var/obj/item/weapon/key/K = L.matching_key(W)
		if (!K && L.skeleton_key(W))
			if (L.refuse("skeleton", user))
				return TRUE
			if (!prob(75))
				to_chat(user, SPAN_WARNING("The skeleton key won't turn in this lock."))
				return TRUE
			K = W
		if (!K)
			to_chat(user, SPAN_WARNING("[istype(W, /obj/item/weapon/key) ? "This key doesn't" : "None of these keys"] fit \the [L.name()]."))
			return TRUE
		if (!L.locked && !host_is_shut(host))
			to_chat(user, SPAN_WARNING("Shut \the [host] first."))
			return TRUE
		L.locked = !L.locked
		user.visible_message(SPAN_NOTICE("[user] [L.locked ? "locks" : "unlocks"] \the [host]."), SPAN_NOTICE("You [L.locked ? "lock" : "unlock"] \the [host]."))
		playsound(get_turf(host), 'sound/effects/door_lock_unlock.ogg', 80)
		return TRUE
	if (istype(W, /obj/item/weapon/lockpick))
		pick_lock(host, L, W, user)
		return TRUE
	if (user.a_intent == I_HARM && (L.kind in list(LOCK_PADLOCK, LOCK_COMBO_PADLOCK, LOCK_KNOT)))
		if ((L.kind == LOCK_KNOT && is_tool(W, TOOL_KNIFE)) || (L.kind != LOCK_KNOT && is_tool(W, TOOL_WIRECUTTER)))
			cut_lock(host, L, W, user)
			return TRUE
	if (user.a_intent == I_HARM && is_tool(W, TOOL_CROWBAR) && L.blocks() && (!host_is_door(host) || L.kind == LOCK_PADLOCK || L.kind == LOCK_COMBO_PADLOCK))
		force_lock(host, L, W, user)
		return TRUE
	if (user.a_intent != I_HARM && L.kind == LOCK_LATCH && L.locked && host_is_door(host) && host_is_shut(host) && is_tool(W, TOOL_KNIFE))
		shim_latch(host, L, W, user)
		return TRUE
	return FALSE

/proc/lock_fit_tool(kind)
	switch (kind)
		if (LOCK_PIN, LOCK_CATCH)
			return TOOL_HAMMER
		if (LOCK_WARDED, LOCK_TUMBLER, LOCK_LATCH, LOCK_COMBINATION)
			return TOOL_SCREWDRIVER
	return 0

/proc/lock_tool_name(quality)
	switch (quality)
		if (TOOL_HAMMER)
			return "hammer"
		if (TOOL_SCREWDRIVER)
			return "screwdriver"
	return "tool"

// A jail door keyed when it was built still has room for a padlock on a hasp.
/proc/host_takes_hasp_lock(atom/host, kind)
	return istype(host, /obj/structure/simple_door/key_door/custom/jail) && (kind == LOCK_PADLOCK || kind == LOCK_COMBO_PADLOCK)

/proc/fit_lock(atom/host, obj/item/fitted_lock/F, mob/living/human/user)
	if (host_has_other_lock(host) && !host_takes_hasp_lock(host, F.lock_kind))
		to_chat(user, SPAN_WARNING("\The [host] already has a lock of its own[istype(host, /obj/structure/simple_door/key_door/custom/jail) ? "; only a padlock fits beside it" : ""]."))
		return FALSE
	if (!host_is_shut(host))
		to_chat(user, SPAN_WARNING("Shut \the [host] first."))
		return FALSE
	var/tool = lock_fit_tool(F.lock_kind)
	if (tool && !door_tool_in_hands(user, tool))
		to_chat(user, SPAN_WARNING("Hold a [lock_tool_name(tool)] in your other hand to fit \the [F]."))
		return FALSE
	if (F.combination_lock() && !F.combo)
		var/datum/lock/probe = new
		probe.kind = F.lock_kind
		if (!probe.set_combination(user))
			return FALSE
		F.combo = probe.combo
	user.visible_message(SPAN_NOTICE("[user] starts fitting \the [F] to \the [host]."), SPAN_NOTICE("You start fitting \the [F]."))
	if (!do_after(user, tool ? LOCK_FIT_TIME : LOCK_FIT_TIME / 4, host))
		return FALSE
	var/datum/lock/old = host_lock(host)
	if (QDELETED(host) || QDELETED(F) || user.get_active_hand() != F || !host_is_shut(host) || (old && old.kind != LOCK_SEAL))
		return FALSE
	var/datum/lock/L = F.make_lock(user)
	if (host_is_door(host))
		var/obj/structure/simple_door/D = host
		L.side = D.door_side_of(user)
		if (!L.side)
			L.side = D.door_passage_axis()
	user.drop_from_inventory(F)
	qdel(F)
	host_set_lock(host, L)
	playsound(get_turf(host), 'sound/items/Screwdriver.ogg', 50, TRUE)
	user.visible_message(SPAN_NOTICE("[user] fits \a [L.name()] to \the [host]."), SPAN_NOTICE("You fit the [L.name()][host_is_door(host) && L.has_thumb_turn() ? ". Its keyhole faces your side; the other side has a thumb-turn" : ""]."))
	return TRUE

/proc/pick_lock(atom/host, datum/lock/L, obj/item/weapon/lockpick/P, mob/living/human/user)
	if (!L.keyed() || !L.locked)
		to_chat(user, SPAN_WARNING("There is nothing here to pick."))
		return FALSE
	if (L.refuse("pick", user))
		return FALSE
	var/need = 1.7
	var/chance_scale = 35
	switch (L.kind)
		if (LOCK_PIN)
			need = 1.2
			chance_scale = 50
		if (LOCK_TUMBLER)
			need = 2.2
			chance_scale = 20
	var/dex = user.getStatCoeff("dexterity")
	if (dex < need)
		to_chat(user, SPAN_WARNING("You don't have the skill to pick \a [L.name()]."))
		return FALSE
	user.visible_message(SPAN_DANGER("[user] starts picking the lock of \the [host]!"), SPAN_DANGER("You start picking the [L.name()]."))
	if (!do_after(user, 35 * dex, host) || QDELETED(host) || host_lock(host) != L)
		return FALSE
	if (prob(dex * chance_scale))
		L.locked = FALSE
		to_chat(user, SPAN_NOTICE("You pick the lock."))
		return TRUE
	if (prob(60))
		qdel(P)
		to_chat(user, SPAN_WARNING("Your lockpick breaks!"))
	else
		to_chat(user, SPAN_WARNING("You fail to pick the lock."))
	return FALSE

// Cracking a combination by listening to the dial.
/proc/crack_combination(atom/host, mob/living/human/user)
	var/datum/lock/L = host_lock(host)
	if (!L || !L.is_combination() || !L.locked)
		return FALSE
	if (L.refuse("crack", user))
		return FALSE
	user.visible_message(SPAN_WARNING("[user] presses an ear to \the [host] and starts turning the dial."), SPAN_NOTICE("You listen to the dial as you turn it."))
	if (!do_after(user, LOCK_CRACK_TIME, host) || QDELETED(host) || host_lock(host) != L)
		return FALSE
	if (prob(clamp(15 * user.getStatCoeff("dexterity"), 5, 60)))
		L.locked = FALSE
		to_chat(user, SPAN_NOTICE("The last wheel clicks into place and the lock opens."))
		return TRUE
	to_chat(user, SPAN_WARNING("You lose count of the clicks."))
	return FALSE

/proc/cut_lock(atom/host, datum/lock/L, obj/item/W, mob/living/human/user)
	if (L.refuse("cut", user))
		return FALSE
	user.visible_message(SPAN_DANGER("[user] starts cutting \the [L.name()] off \the [host]!"), SPAN_DANGER("You start cutting the [L.name()] off."))
	if (!do_after(user, LOCK_FORCE_TIME, host) || QDELETED(host) || host_lock(host) != L)
		return FALSE
	host_set_lock(host, null)
	user.visible_message(SPAN_DANGER("[user] cuts \the [L.name()] off \the [host]."))
	return TRUE

// Prising a locked container open breaks the lock and dents the container.
/proc/force_lock(atom/host, datum/lock/L, obj/item/W, mob/living/human/user)
	if (L.refuse("force", user))
		return FALSE
	user.visible_message(SPAN_DANGER("[user] starts prising \the [host] open!"), SPAN_DANGER("You start forcing the lid."))
	playsound(get_turf(host), 'sound/effects/wooddoorhit.ogg', 60)
	if (!do_after(user, LOCK_FORCE_TIME, host) || QDELETED(host) || host_lock(host) != L)
		return FALSE
	host_set_lock(host, null)
	if (istype(host, /obj/structure/closet))
		var/obj/structure/closet/C = host
		C.damage(20)
	user.visible_message(SPAN_DANGER("[user] breaks the lock of \the [host]!"))
	return TRUE

// Slipping a thin blade between door and frame to push a spring latch back.
// It only works on a latch: a deadbolt can't be pushed.
/proc/shim_latch(atom/host, datum/lock/L, obj/item/W, mob/living/human/user)
	if (host_lock_side(host, L, user) != "key")
		return lock_hand_access(host, user)
	if (L.refuse("shim", user))
		return FALSE
	user.visible_message(SPAN_WARNING("[user] slides \the [W] into the gap of \the [host]."), SPAN_NOTICE("You work \the [W] into the gap to push the latch back."))
	if (!do_after(user, LOCK_SEARCH_TIME, host) || QDELETED(host) || host_lock(host) != L || !L.locked)
		return FALSE
	if (prob(clamp(30 * user.getStatCoeff("dexterity"), 10, 80)))
		L.locked = FALSE
		to_chat(user, SPAN_NOTICE("The latch slips back."))
		return TRUE
	to_chat(user, SPAN_WARNING("The latch won't slip."))
	return FALSE

// Taking a lock off: from inside, or while it is open, with its tool.
/proc/remove_lock(atom/host, mob/living/human/user)
	var/datum/lock/L = host_lock(host)
	if (!L)
		to_chat(user, SPAN_WARNING("\The [host] has no lock."))
		return FALSE
	var/where = host_lock_side(host, L, user)
	if (L.blocks() && where == "key" && !(L.kind == LOCK_CATCH && L.catch_known(user)))
		to_chat(user, SPAN_WARNING("Unlock \the [L.name()] first."))
		return FALSE
	var/tool = lock_fit_tool(L.kind)
	if (tool && !door_tool_in_hands(user, tool))
		to_chat(user, SPAN_WARNING("You need a [lock_tool_name(tool)] in hand to take \the [L.name()] off."))
		return FALSE
	user.visible_message(SPAN_NOTICE("[user] starts taking \the [L.name()] off \the [host]."), SPAN_NOTICE("You start taking the [L.name()] off."))
	if (!do_after(user, tool ? LOCK_FIT_TIME / 2 : LOCK_FIT_TIME / 4, host) || QDELETED(host) || host_lock(host) != L)
		return FALSE
	host_set_lock(host, null)
	var/obj/item/fitted_lock/F = lock_to_item(L, get_turf(user))
	if (F)
		user.put_in_hands(F)
	to_chat(user, SPAN_NOTICE("You take the [L.name()] off."))
	return TRUE

// A broken seal leaves nothing worth keeping; everything else comes off whole.
/proc/lock_to_item(datum/lock/L, turf/T)
	if (!L || !L.item_type || (L.kind == LOCK_SEAL && !L.locked) || !T)
		return null
	var/obj/item/fitted_lock/F = new L.item_type(T)
	F.code = L.code
	F.combo = L.combo
	F.key_taken = TRUE
	if (L.refuses)
		F.refuses = L.refuses.Copy()
	return F

/proc/lock_examine(atom/host, mob/user)
	var/datum/lock/L = host_lock(host)
	if (!L || !user || get_dist(user, host) > 2)
		return
	if (L.kind == LOCK_CATCH)
		if (L.catch_known(user))
			to_chat(user, SPAN_NOTICE("You know where its hidden catch is."))
		return
	if (L.kind == LOCK_SEAL)
		to_chat(user, L.locked ? SPAN_NOTICE("It is sealed with clay[L.owner_name ? ", stamped with [L.owner_name]'s mark" : ""].") : SPAN_WARNING("Its clay seal has been broken."))
		return
	if (L.kind == LOCK_KNOT)
		if (!L.locked)
			to_chat(user, SPAN_NOTICE("A cord hangs from it, untied."))
		else if (L.tied_by && L.tied_by != L.owner_name)
			to_chat(user, SPAN_WARNING("It is tied shut, but not with [L.owner_name ? "[L.owner_name]'s" : "its owner's"] knot: someone has retied it."))
		else
			to_chat(user, SPAN_NOTICE("It is tied shut with [L.owner_name ? "[L.owner_name]'s" : "a"] knot."))
		return
	var/side_text = ""
	if (host_is_door(host) && L.has_thumb_turn())
		var/where = host_lock_side(host, L, user)
		side_text = where == "thumb" ? " Its thumb-turn is on your side." : (where == "key" ? " Its keyhole faces you." : "")
	to_chat(user, SPAN_NOTICE("It has \a [L.name()], [L.locked ? "locked" : "unlocked"].[side_text]"))
	if (L.refuses && L.refuses.len)
		to_chat(user, SPAN_NOTICE("It looks unusually well made."))

// ---- the verbs every lockable shares ------------------------------------------------

/obj/structure/simple_door/verb/work_lock()
	set name = "Lock or Unlock"
	set category = null
	set src in view(1)
	lock_verb_use(src, usr)

/obj/structure/simple_door/verb/take_off_lock()
	set name = "Remove Lock"
	set category = null
	set src in view(1)
	if (ishuman(usr) && !usr.incapacitated() && usr.Adjacent(src))
		remove_lock(src, usr)

/obj/structure/closet/verb/work_lock()
	set name = "Lock or Unlock"
	set category = null
	set src in view(1)
	lock_verb_use(src, usr)

/obj/structure/closet/verb/take_off_lock()
	set name = "Remove Lock"
	set category = null
	set src in view(1)
	if (ishuman(usr) && !usr.incapacitated() && usr.Adjacent(src))
		remove_lock(src, usr)

/obj/structure/storage_container/verb/work_lock()
	set name = "Lock or Unlock"
	set category = null
	set src in view(1)
	lock_verb_use(src, usr)

/obj/structure/storage_container/verb/take_off_lock()
	set name = "Remove Lock"
	set category = null
	set src in view(1)
	if (ishuman(usr) && !usr.incapacitated() && usr.Adjacent(src))
		remove_lock(src, usr)

/proc/lock_verb_use(atom/host, mob/user)
	var/mob/living/human/H = user
	if (!istype(H) || H.incapacitated() || !H.Adjacent(host))
		return FALSE
	var/datum/lock/L = host_lock(host)
	if (!L)
		to_chat(H, SPAN_WARNING("\The [host] has no lock."))
		return FALSE
	if (L.is_combination() && L.locked && H.a_intent == I_DISARM)
		return crack_combination(host, H)
	if (L.locked && (L.kind == LOCK_KNOT || L.is_combination() || host_lock_side(host, L, H) != "key"))
		return lock_hand_access(host, H)
	return lock_hand_lock(host, H)

// ---- lock items ---------------------------------------------------------------------

/obj/item/fitted_lock
	name = "lock"
	desc = "A lock. Use it in hand to take out its key, use a key of its kind on it to re-cut it to that key, then use it on a shut door, chest or crate to fit it."
	icon = 'icons/obj/doors/locks_fitted.dmi'
	icon_state = "item_lock_warded"
	w_class = ITEM_SIZE_SMALL
	var/lock_kind = LOCK_WARDED
	var/family = "warded"
	var/combo = null
	var/key_taken = FALSE
	var/key_type = /obj/item/weapon/key/warded
	var/list/refuses = null		// see /datum/lock: methods this lock refuses, for events

/obj/item/fitted_lock/proc/combination_lock()
	return lock_kind == LOCK_COMBINATION || lock_kind == LOCK_COMBO_PADLOCK

/obj/item/fitted_lock/proc/make_lock(mob/user)
	var/datum/lock/L = new
	L.kind = lock_kind
	L.family = family
	L.item_type = type
	L.owner_name = user ? user.real_name : null
	if (family)
		if (!code)
			code = rand(100000, 999999)
		L.code = code
	L.combo = combo
	L.locked = lock_kind == LOCK_SEAL
	if (refuses)
		L.refuses = refuses.Copy()
	return L

/obj/item/fitted_lock/attack_self(mob/user)
	if (!family)
		if (combination_lock())
			var/datum/lock/probe = new
			probe.kind = lock_kind
			probe.combo = combo
			if (probe.set_combination(user))
				combo = probe.combo
		return
	if (key_taken)
		to_chat(user, SPAN_NOTICE("Its key has already been taken out."))
		return
	if (!code)
		code = rand(100000, 999999)
	key_taken = TRUE
	var/obj/item/weapon/key/K = new key_type(get_turf(user))
	K.code = code
	K.name = "[initial(K.name)] ([name])"
	user.put_in_hands(K)
	to_chat(user, SPAN_NOTICE("You take the key out of \the [src]."))

/obj/item/fitted_lock/attackby(obj/item/W, mob/user)
	var/obj/item/weapon/key/K = W
	if (istype(K) && family && !K.blank)
		if (K.key_family != family)
			to_chat(user, SPAN_WARNING("\The [K] is the wrong kind of key for \the [src]."))
			return TRUE
		if (!K.code)
			return TRUE
		to_chat(user, SPAN_NOTICE("You start re-cutting \the [src] to fit \the [K]."))
		if (!do_after(user, 50, src))
			return TRUE
		code = K.code
		key_taken = TRUE
		to_chat(user, SPAN_NOTICE("\The [src] now opens with \the [K]."))
		return TRUE
	return ..()

/obj/item/fitted_lock/examine(mob/user, distance = -1)
	. = ..()
	if (family)
		to_chat(user, SPAN_NOTICE(key_taken ? "Its key is out." : "Its key is still inside: use it in hand to take it out."))
	else if (combination_lock())
		to_chat(user, SPAN_NOTICE(combo ? "Its combination is set." : "Use it in hand to set its combination."))

/obj/item/fitted_lock/pin
	name = "wooden pin lock"
	icon_state = "item_lock_pin"
	lock_kind = LOCK_PIN
	family = "wood"
	key_type = /obj/item/weapon/key/wooden

/obj/item/fitted_lock/warded
	name = "warded lock"

/obj/item/fitted_lock/tumbler
	name = "tumbler lock"
	icon_state = "item_lock_tumbler"
	lock_kind = LOCK_TUMBLER
	family = "tumbler"
	key_type = /obj/item/weapon/key/tumbler

/obj/item/fitted_lock/latch
	name = "spring latch"
	desc = "A night latch: it locks itself whenever the door it is on shuts. Its key opens it from outside; inside it has a thumb-turn."
	icon_state = "item_lock_latch"
	lock_kind = LOCK_LATCH

/obj/item/fitted_lock/combination
	name = "combination lock"
	desc = "A dial lock that takes no key. Set its combination by using it in hand."
	icon_state = "item_lock_combination"
	lock_kind = LOCK_COMBINATION
	family = null

/obj/item/fitted_lock/padlock
	name = "padlock"
	desc = "A padlock with its hasp. It clips onto any door, chest or crate without tools and moves to anything else just as easily once unlocked. Wirecutters cut it off."
	icon_state = "item_padlock"
	lock_kind = LOCK_PADLOCK

/obj/item/fitted_lock/padlock/combination
	name = "combination padlock"
	icon_state = "item_padlock_combination"
	lock_kind = LOCK_COMBO_PADLOCK
	family = null

/obj/item/fitted_lock/knot
	name = "knot seal"
	desc = "A length of cord for tying a door or lid shut with your own knot. Anyone can untie it, but a retied knot shows."
	icon_state = "item_knot_seal"
	lock_kind = LOCK_KNOT
	family = null
	w_class = ITEM_SIZE_TINY

/obj/item/fitted_lock/seal
	name = "clay seal"
	desc = "A lump of clay pressed over a cord across a door or lid. It stops nobody, but anyone can see when it has been broken."
	icon_state = "item_clay_seal"
	lock_kind = LOCK_SEAL
	family = null
	w_class = ITEM_SIZE_TINY

/obj/item/fitted_lock/hidden_catch
	name = "hidden catch"
	desc = "A concealed latch. Whoever fitted it, and anyone who has found it, opens it without thinking; everyone else has to search for it."
	icon_state = "item_hidden_catch"
	lock_kind = LOCK_CATCH
	family = null

// ---- keys -----------------------------------------------------------------------------

/obj/item/weapon/key
	var/key_family = "warded"
	var/skeleton = FALSE
	var/blank = FALSE

/obj/item/weapon/key/warded
	name = "iron key"
	icon = 'icons/obj/doors/locks_fitted.dmi'
	icon_state = "key_warded"
	code = 0

/obj/item/weapon/key/wooden
	name = "wooden key"
	icon = 'icons/obj/doors/locks_fitted.dmi'
	icon_state = "key_wood"
	key_family = "wood"
	code = 0

/obj/item/weapon/key/tumbler
	name = "tumbler key"
	icon = 'icons/obj/doors/locks_fitted.dmi'
	icon_state = "key_tumbler"
	key_family = "tumbler"
	code = 0

/obj/item/weapon/key/skeleton
	name = "skeleton key"
	desc = "A key filed down to its bare shaft. It turns most warded locks, but nothing finer."
	icon = 'icons/obj/doors/locks_fitted.dmi'
	icon_state = "key_skeleton"
	skeleton = TRUE
	code = 0

/obj/item/weapon/key/blank
	name = "iron key blank"
	desc = "An uncut key. Use a key of the same kind on it to cut a copy."
	icon = 'icons/obj/doors/locks_fitted.dmi'
	icon_state = "blank_warded"
	blank = TRUE
	code = 0
	var/cut_type = /obj/item/weapon/key/warded

/obj/item/weapon/key/blank/wooden
	name = "wooden key blank"
	icon_state = "blank_wood"
	key_family = "wood"
	cut_type = /obj/item/weapon/key/wooden

/obj/item/weapon/key/blank/tumbler
	name = "tumbler key blank"
	icon_state = "blank_tumbler"
	key_family = "tumbler"
	cut_type = /obj/item/weapon/key/tumbler

/obj/item/weapon/key/blank/attackby(obj/item/W, mob/user)
	var/obj/item/weapon/key/K = W
	if (!istype(K) || K.blank)
		return ..()
	if (K.key_family != key_family || K.skeleton || !K.code)
		to_chat(user, SPAN_WARNING("\The [K] can't be copied onto \the [src]."))
		return TRUE
	to_chat(user, SPAN_NOTICE("You start filing \the [src] to match \the [K]."))
	if (!do_after(user, LOCK_COPY_TIME, src))
		return TRUE
	if (QDELETED(src) || QDELETED(K))
		return TRUE
	var/turf/T = get_turf(src)
	var/obj/item/weapon/key/copy = new cut_type(T)
	copy.code = K.code
	copy.name = K.name
	user.drop_from_inventory(src)
	qdel(src)
	user.put_in_hands(copy)
	to_chat(user, SPAN_NOTICE("You cut a copy of \the [K]."))
	return TRUE

// ---- doors ---------------------------------------------------------------------------

/obj/structure/simple_door/proc/door_lock_opened()
	if (door_lock && door_lock.kind == LOCK_SEAL && door_lock.locked)
		door_lock.locked = FALSE
		visible_message(SPAN_WARNING("The seal on \the [src] breaks."))

/obj/structure/simple_door/proc/door_lock_closed()
	if (door_lock && door_lock.kind == LOCK_LATCH && !door_lock.locked)
		door_lock.locked = TRUE
		playsound(get_turf(src), 'sound/effects/door_lock_unlock.ogg', 40)

/obj/structure/simple_door/proc/door_lock_overlay_state()
	if (!door_lock || state)
		return null
	if (door_lock.kind == LOCK_CATCH)
		return "door_lock_catch"
	return door_lock.overlay_state(FALSE)

#undef LOCK_FIT_TIME
#undef LOCK_SEARCH_TIME
#undef LOCK_UNTIE_TIME
#undef LOCK_CRACK_TIME
#undef LOCK_COPY_TIME
#undef LOCK_FORCE_TIME

// ---- locks placed by mappers and event admins -----------------------------------

// A mapped door, closet or storage can start with a lock: set mapped_lock to a
// lock item path, and optionally its code, combination, whether it starts
// locked and which defeat methods it refuses ("all" for every one). Keys for a
// mapped keyed lock are mapped keys with the same code. A saved lock wins.
/obj/structure/simple_door
	var/mapped_lock = null
	var/mapped_lock_code = 0
	var/mapped_lock_combo = null
	var/mapped_lock_locked = TRUE
	var/list/mapped_lock_refuses = null

/obj/structure/closet
	var/mapped_lock = null
	var/mapped_lock_code = 0
	var/mapped_lock_combo = null
	var/mapped_lock_locked = TRUE
	var/list/mapped_lock_refuses = null

/obj/structure/storage_container
	var/mapped_lock = null
	var/mapped_lock_code = 0
	var/mapped_lock_combo = null
	var/mapped_lock_locked = TRUE
	var/list/mapped_lock_refuses = null

/proc/host_apply_mapped_lock(obj/O)
	var/path = O.vars["mapped_lock"]
	if (!path || host_lock(O) || !ispath(path, /obj/item/fitted_lock))
		return null
	var/obj/item/fitted_lock/F = new path
	if (O.vars["mapped_lock_code"])
		F.code = O.vars["mapped_lock_code"]
	if (O.vars["mapped_lock_combo"])
		F.combo = uppertext("[O.vars["mapped_lock_combo"]]")
	var/list/refuses = O.vars["mapped_lock_refuses"]
	if (islist(refuses))
		F.refuses = refuses.Copy()
	var/datum/lock/L = F.make_lock(null)
	qdel(F)
	if (host_is_door(O))
		var/obj/structure/simple_door/D = O
		L.side = D.inner_dir > 0 ? D.door_opposite_side(D.inner_dir) : D.door_passage_axis()
	if (L.kind != LOCK_SEAL && L.kind != LOCK_CATCH)
		L.locked = O.vars["mapped_lock_locked"] ? TRUE : FALSE
	host_set_lock(O, L)
	O.vars["mapped_lock"] = null
	return L

/obj/structure/closet/New()
	..()
	if (mapped_lock)
		host_apply_mapped_lock(src)
