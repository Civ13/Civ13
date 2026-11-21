// ============================================================
// Ties to targets (Val, 2026-11-19/21). Hidden mechanic: keep it out of
// changelog lines, the wiki and anything an ordinary player sees.
// ------------------------------------------------------------
// A magic user readies a tie the way they would ready a throw (Ready a tie),
// picking one of their repositories, and the next thing they touch with any
// intent - a person, an animal, an object or the ground itself - is tied to
// that repository. The touch still does what it would have done. The target
// is never told. Tying another magic user tells the one tying only that.
//
// A tie lasts until its target dies or is destroyed, or until someone
// discovers and severs it (Sense ties / Sever live in the magic materials
// plan; they use magic_ties_on() and magic_tie_sever() below). Only the
// magic user who made a tie can move it to another repository of the same
// god, at the repository that holds it; keepers see and prune every tie,
// everyone else only their own.
//
// Saved form: repository.magic_repo_targets is tie key -> "by|at|name".
// A movable's key is "m:<magic_tie_id>" (a saved id given on its first tie);
// a place is "t:x,y,z".
// ============================================================

#define MAGIC_TIE_SEP "|"

/atom/movable
	var/magic_tie_id = null // saved: given on the first tie, so ties survive saves

/obj
	var/list/magic_repo_targets = null // saved: tie key -> "by|at|name"

/mob/living/human
	var/tmp/magic_tie_mode = null     // "self" or "target"
	var/tmp/magic_tie_repo = null     // repository id a readied target tie goes to

// tie id -> movable in this world.
var/global/list/magic_tie_index = list()

/proc/magic_tie_key(atom/A)
	if (isturf(A))
		return "t:[A.x],[A.y],[A.z]"
	var/atom/movable/M = A
	if (!istype(M))
		return null
	if (!M.magic_tie_id)
		var/id
		do
			id = "[world.realtime]-[rand(100000, 999999)]"
		while (magic_tie_index[id])
		M.magic_tie_id = id
	magic_tie_index[M.magic_tie_id] = M
	return "m:[M.magic_tie_id]"

// The live target of a tie key, or null when it is gone (or not loaded here).
/proc/magic_tie_resolve(key)
	if (!istext(key) || length(key) < 3)
		return null
	var/kind = copytext(key, 1, 3)
	var/rest = copytext(key, 3)
	if (kind == "t:")
		var/list/xyz = splittext(rest, ",")
		if (xyz.len != 3)
			return null
		return locate(text2num(xyz[1]), text2num(xyz[2]), text2num(xyz[3]))
	if (kind != "m:")
		return null
	var/atom/movable/M = magic_tie_index[rest]
	if (M && !QDELETED(M) && M.magic_tie_id == rest)
		return M
	magic_tie_index -= rest
	// Mobs are not indexed on load; find one by its saved id.
	for (var/mob/living/L in mob_list)
		if (L.magic_tie_id == rest && !QDELETED(L))
			magic_tie_index[rest] = L
			return L
	return null

/proc/magic_tie_entry(entry, field)
	var/list/parts = splittext(entry, MAGIC_TIE_SEP)
	switch (field)
		if ("by")
			return parts.len >= 1 ? parts[1] : null
		if ("at")
			return parts.len >= 2 ? text2num(parts[2]) : 0
		if ("name")
			return parts.len >= 3 ? jointext(parts.Copy(3), MAGIC_TIE_SEP) : "something"
	return null

// A tie whose target has died or been destroyed is gone for good. Missing
// targets are only judged once the world has fully loaded.
/obj/proc/magic_repo_prune_ties()
	if (!islist(magic_repo_targets))
		return
	var/restored = !map || !map.persistence || persistence_player_restore_ready
	for (var/key in magic_repo_targets.Copy())
		if (copytext(key, 1, 3) == "t:")
			continue
		var/atom/A = magic_tie_resolve(key)
		if (!A)
			if (restored)
				magic_repo_targets -= key
			continue
		var/mob/living/L = A
		if (istype(L) && L.stat == DEAD)
			magic_repo_targets -= key

// Live targets tied to this repository: tie key -> atom.
/obj/proc/magic_repo_live_targets()
	. = list()
	magic_repo_prune_ties()
	for (var/key in magic_repo_targets)
		var/atom/A = magic_tie_resolve(key)
		if (A)
			.[key] = A

// The key A is tied under, without giving an untied movable an id.
/proc/magic_tie_existing_key(atom/A)
	if (isturf(A))
		return magic_tie_key(A)
	var/atom/movable/M = A
	if (istype(M) && M.magic_tie_id)
		return "m:[M.magic_tie_id]"
	return null

/proc/ward_target_registered(obj/repo, atom/A)
	if (!istype(repo) || !islist(repo.magic_repo_targets) || !A)
		return FALSE
	var/key = magic_tie_existing_key(A)
	return key && (key in repo.magic_repo_targets)

// Every repository in this world holding a tie on A (for Sense ties / Sever).
/proc/magic_ties_on(atom/A)
	. = list()
	var/key = magic_tie_existing_key(A)
	if (!key)
		return
	for (var/id in magic_repo_index)
		var/obj/O = magic_repo_find(id)
		if (O && islist(O.magic_repo_targets) && (key in O.magic_repo_targets))
			. += O

/proc/magic_tie_sever(obj/repo, atom/A)
	if (!istype(repo) || !islist(repo.magic_repo_targets))
		return FALSE
	var/key = magic_tie_existing_key(A)
	if (!key || !(key in repo.magic_repo_targets))
		return FALSE
	repo.magic_repo_targets -= key
	return TRUE

/mob/living/human/proc/magic_is_magic_user()
	return magic_allowed() && istext(divine_patron) && length(divine_patron)

/mob/living/human/proc/magic_tie_target(atom/A)
	var/obj/repo = magic_repo_find(magic_tie_repo)
	magic_tie_repo = null
	if (!repo || repo.magic_repo_dormant() || !(repo.magic_repo_id in magic_registered_repos) || repo.magic_repo_deity != divine_book_key(divine_patron))
		to_chat(src, SPAN_NOTICE("Nothing takes hold."))
		return FALSE
	if (A == src || (istype(A, /obj) && A:magic_repo_id))
		to_chat(src, SPAN_NOTICE("Nothing takes hold."))
		return FALSE
	var/key = magic_tie_key(A)
	if (!key)
		return FALSE
	if (!islist(repo.magic_repo_targets))
		repo.magic_repo_targets = list()
	repo.magic_repo_targets[key] = "[magic_key()][MAGIC_TIE_SEP][world.realtime][MAGIC_TIE_SEP][isturf(A) ? "a place" : A.name]"
	to_chat(src, SPAN_NOTICE("A thread slips from you to [isturf(A) ? "this place" : "\the [A]"]."))
	var/mob/living/human/H = A
	if (istype(H) && H.magic_is_magic_user())
		to_chat(src, SPAN_NOTICE("The thread hums back at you: this one prays as you do."))
	log_game("[key_name(src)] tied [isturf(A) ? "[A.x],[A.y],[A.z]" : key_name(A)] to repository [repo.magic_repo_id].")
	return TRUE

// Moves a tie this character made to another repository of the same god they
// are tied to. Done at the repository that holds it. The date carries over.
/mob/living/human/proc/magic_tie_move(obj/from)
	var/me = magic_key()
	var/list/mine = list()
	for (var/key in from.magic_repo_targets)
		if (magic_tie_entry(from.magic_repo_targets[key], "by") == me)
			mine["[magic_tie_entry(from.magic_repo_targets[key], "name")] ([key])"] = key
	if (!mine.len)
		to_chat(src, SPAN_NOTICE("None of the threads here are yours."))
		return
	var/list/dests = list()
	for (var/obj/O in magic_registered_repositories())
		if (O != from && O.magic_repo_deity == from.magic_repo_deity)
			dests["[O.name] ([O.magic_repo_id])"] = O
	if (!dests.len)
		to_chat(src, SPAN_NOTICE("You hold no other place to move a thread to."))
		return
	var/key = mine[player_input(src, "Move which thread?", "Ties", null, "anything", mine, TRUE)]
	var/obj/to_repo = dests[player_input(src, "Move it to?", "Ties", null, "anything", dests, TRUE)]
	if (!key || !to_repo || !(key in from.magic_repo_targets) || magic_tie_entry(from.magic_repo_targets[key], "by") != me)
		return
	if (!from.Adjacent(src) && !(from in GetAllContents(4)))
		return
	if (!islist(to_repo.magic_repo_targets))
		to_repo.magic_repo_targets = list()
	to_repo.magic_repo_targets[key] = from.magic_repo_targets[key]
	from.magic_repo_targets -= key
	to_chat(src, SPAN_NOTICE("You draw the thread across."))
	log_game("[key_name(src)] moved tie [key] from repository [from.magic_repo_id] to [to_repo.magic_repo_id].")

// Keepers see every thread and can cut any; others see and cut only their own.
/mob/living/human/proc/magic_tie_review(obj/repo)
	repo.magic_repo_prune_ties()
	var/keeper = repo.magic_repo_is_keeper(src)
	var/me = magic_key()
	var/list/shown = list()
	for (var/key in repo.magic_repo_targets)
		var/entry = repo.magic_repo_targets[key]
		if (keeper || magic_tie_entry(entry, "by") == me)
			shown["[magic_tie_entry(entry, "name")][keeper ? ", tied by [magic_tie_entry(entry, "by")]" : ""] ([key])"] = key
	if (!shown.len)
		to_chat(src, SPAN_NOTICE("You find no threads of yours here."))
		return
	var/key = shown[player_input(src, "Cut which thread? (Close to leave them all.)", "Ties", null, "anything", shown, TRUE)]
	if (!key || !(key in repo.magic_repo_targets))
		return
	if (!keeper && magic_tie_entry(repo.magic_repo_targets[key], "by") != me)
		return
	repo.magic_repo_targets -= key
	to_chat(src, SPAN_NOTICE("You cut the thread."))

#undef MAGIC_TIE_SEP
