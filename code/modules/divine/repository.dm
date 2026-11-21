// ============================================================
// Magic repositories (Val, 2026-11-19/21). Hidden mechanic: keep it out of
// changelog lines, the wiki, the Crafting Atlas and anything an ordinary
// player sees.
// ------------------------------------------------------------
// A god teaches a whitelisted follower the "repository" grant (Divine Patron >
// Teach an invocation). With it, the follower beseeches to turn one small thing
// of their own into a personal repository: the god approves the start like any
// invocation, then the maker channels into it (Channel) for
// MAGIC_REPO_MAKE_TIME in sittings, paying with hunger, thirst and energy, or
// with charge already stored in another repository they keep.
//
// A repository is an ordinary object with a few saved fields; nothing changes
// its name, sprite or examine text for anyone but its keepers. It holds
// charge up to a capacity set by its tier ceiling, its size and its maker's
// skill. Followers of its god tie themselves to it by readying a tie and
// touching it (Ready a tie, click.dm hook), and then feed it from altars.
//
// Interface for the other magic plans:
//   ward_charge(repo)                     charge held, or 0
//   ward_refill(repo, amount, source, by) adds charge under the daily caps,
//                                          returns what was added
//   ward_drain(repo, amount, attacker)    takes charge, returns what is left,
//                                          or FALSE once it is empty
//   magic_repo_find(id), H.magic_registered_repositories()
// ============================================================

#define MAGIC_REPO_MAKE_TIME 18000       // deciseconds of channelling for a personal repository (30 minutes)
#define MAGIC_REPO_SITTING 600           // deciseconds per channelling step (one minute)
#define MAGIC_REPO_PERSONAL_CEILING 100  // tier 1 capacity before size and skill
#define MAGIC_REPO_STORED_SEED 10        // charge a personal repository costs when paid from storage
#define MAGIC_REPO_BODY_SHARE 90         // each minute costs 1/90 of a full stomach and of full water
#define MAGIC_REPO_SKILL_FLOOR 5         // the grant lifts a follower's magic to at least this
#define MAGIC_REPO_DAY 864000            // deciseconds of real time in a day

// id -> repository object in this world. Rebuilt as repositories load.
var/global/list/magic_repo_index = list()

// Daily refill caps per source. A number is a flat cap per repository per real
// day; "capacity" sources take a fraction of the repository's capacity.
var/global/list/magic_repo_source_caps = list(
	"offering" = list("capacity" = 0.05),
	"devotion" = list("flat" = 150),
	"rite" = list("flat" = 400),
	"vigil" = list("flat" = 0),     // 0: no cap of its own (bounded by the rest slot)
	"residents" = list("flat" = 0),
	"favour" = list("flat" = 0),
)
var/global/list/magic_repo_follower_caps = list("devotion" = 30)

/obj
	var/magic_repo_id = null             // saved: set once this object is (being made into) a repository
	var/magic_repo_deity = null          // saved: the god it belongs to (divine_book_key form)
	var/magic_repo_tier = 0              // saved: 0 while still being made, then 1 to 5
	var/magic_repo_charge = 0            // saved
	var/magic_repo_capacity = 0          // saved
	var/magic_repo_maker = null          // saved: maker's ckey
	var/magic_repo_skill = 0             // saved: maker's magic skill when it was made
	var/magic_repo_progress = 0          // saved: deciseconds channelled so far while unfinished
	var/magic_repo_withdrawn = FALSE     // saved: the god took the grant back from its maker
	var/list/magic_repo_keepers = null   // saved: ckeys that may draw on it and see its charge
	var/list/magic_repo_registrants = null // saved: ckeys tied to it (may feed it)
	var/list/magic_repo_barred = null    // saved: ckeys a keeper has turned away
	var/magic_repo_day = 0               // saved: the real day the counters below belong to
	var/list/magic_repo_today = null     // saved: source (or "source:ckey") -> charge added today

/mob/living/human
	var/list/magic_kept_repos = null       // saved: ids of repositories this character keeps or is making
	var/list/magic_registered_repos = null // saved: ids this character is tied to
	var/tmp/magic_tie_ready = FALSE        // the next touch ties this character to the repository touched
	var/tmp/magic_channelling = FALSE

/obj/after_load()
	. = ..()
	if (magic_repo_id)
		magic_repo_index[magic_repo_id] = src

/proc/magic_repo_find(id)
	if (!istext(id))
		return null
	var/obj/O = magic_repo_index[id]
	if (!O || QDELETED(O) || O.magic_repo_id != id)
		magic_repo_index -= id
		return null
	return O

/proc/magic_repo_new_id()
	var/id
	do
		id = "[world.realtime]-[rand(100000, 999999)]"
	while (magic_repo_index[id])
	return id

// ---------- state ----------

/obj/proc/magic_repo_finished()
	return magic_repo_id && magic_repo_tier >= 1

// A dormant repository has no effects and takes no charge.
/obj/proc/magic_repo_dormant()
	if (!magic_repo_finished() || magic_repo_withdrawn)
		return TRUE
	if (!magic_whitelist_applies())
		return FALSE
	for (var/key in magic_repo_keepers)
		if (magic_whitelisted(key))
			return FALSE
	return TRUE

/obj/proc/magic_repo_is_keeper(mob/living/human/H)
	return istype(H) && islist(magic_repo_keepers) && (H.magic_key() in magic_repo_keepers)

/obj/proc/magic_repo_roll_day()
	var/day = round(world.realtime / MAGIC_REPO_DAY)
	if (day != magic_repo_day || !islist(magic_repo_today))
		magic_repo_day = day
		magic_repo_today = list()

/proc/ward_charge(obj/repo)
	if (!istype(repo) || !repo.magic_repo_finished())
		return 0
	return repo.magic_repo_charge

// Adds up to amount, within the source's daily caps. Returns what was added.
/proc/ward_refill(obj/repo, amount, source, mob/living/human/by = null)
	if (!istype(repo) || QDELETED(repo) || !isnum(amount) || amount <= 0 || !istext(source))
		return 0
	if (repo.magic_repo_dormant())
		return 0
	repo.magic_repo_roll_day()
	var/room = repo.magic_repo_capacity - repo.magic_repo_charge
	var/list/cap = magic_repo_source_caps[source]
	if (islist(cap))
		var/limit = cap["capacity"] ? round(repo.magic_repo_capacity * cap["capacity"], 1) : cap["flat"]
		if (limit)
			room = min(room, limit - (repo.magic_repo_today[source] || 0))
	var/follower_cap = magic_repo_follower_caps[source]
	var/follower_slot = null
	if (follower_cap && istype(by))
		follower_slot = "[source]:[by.magic_key()]"
		room = min(room, follower_cap - (repo.magic_repo_today[follower_slot] || 0))
	var/added = max(0, min(amount, room))
	if (!added)
		return 0
	repo.magic_repo_charge += added
	repo.magic_repo_today[source] = (repo.magic_repo_today[source] || 0) + added
	if (follower_slot)
		repo.magic_repo_today[follower_slot] = (repo.magic_repo_today[follower_slot] || 0) + added
	return added

// Takes amount. Returns the charge left, or FALSE once it is empty.
/proc/ward_drain(obj/repo, amount, attacker = null)
	if (!istype(repo) || QDELETED(repo) || !repo.magic_repo_finished() || repo.magic_repo_dormant())
		return FALSE
	if (isnum(amount) && amount > 0)
		repo.magic_repo_charge = max(0, repo.magic_repo_charge - amount)
	return repo.magic_repo_charge > 0 ? repo.magic_repo_charge : FALSE

// ---------- the maker's side ----------

/mob/living/human/proc/magic_skill()
	ensure_late_stats()
	var/list/S = stats["magic"]
	return islist(S) ? S[1] : 0

/mob/living/human/proc/magic_skill_floor(value)
	ensure_late_stats()
	var/list/S = stats["magic"]
	if (islist(S) && S[1] < value)
		stats["magic"] = list(value, max(S[2], value))

// Divine Patron: the god has just taught the repository grant.
/mob/living/human/proc/magic_grant_received()
	magic_skill_floor(MAGIC_REPO_SKILL_FLOOR)
	magic_repo_restore_all()
	divine_refresh_verbs()

/mob/living/human/proc/magic_has_grant()
	return islist(divine_known) && ("repository" in divine_known) && magic_allowed()

// How many repositories this character may keep: one, and one more per 25 magic, up to 5.
/mob/living/human/proc/magic_repo_allowance()
	return min(5, 1 + round(magic_skill() / 25))

/mob/living/human/proc/magic_repos_kept()
	. = list()
	var/restored = !map || !map.persistence || persistence_player_restore_ready
	for (var/id in magic_kept_repos)
		var/obj/O = magic_repo_find(id)
		if (O)
			. += O
		else if (restored)
			// Gone from this world after a full load: it no longer counts.
			magic_kept_repos -= id

/mob/living/human/proc/magic_registered_repositories()
	. = list()
	for (var/id in magic_registered_repos)
		var/obj/O = magic_repo_find(id)
		if (O && !O.magic_repo_dormant())
			. += O

// Small things a personal repository can be made from: worn or carried trinkets.
/proc/magic_repo_personal_form(obj/item/I)
	if (!istype(I) || QDELETED(I) || I.magic_repo_id)
		return FALSE
	if (I.w_class > ITEM_SIZE_SMALL)
		return FALSE
	if (istype(I, /obj/item/weapon/branch) || istype(I, /obj/item/stack) || istype(I, /obj/item/weapon/storage) || istype(I, /obj/item/weapon/reagent_containers) || istype(I, /obj/item/weapon/book))
		return FALSE
	return TRUE

// Size factor within the personal form: things made to be worn hold more.
/proc/magic_repo_size_factor(obj/O)
	if (istype(O, /obj/item/clothing/accessory) || istype(O, /obj/item/clothing/mask/necklace))
		return 1
	return 0.75

// The small thing held in the hand that is not the stick.
/mob/living/human/proc/magic_repo_held_form()
	for (var/obj/item/I in list(get_active_hand(), get_inactive_hand()))
		if (!istype(I, /obj/item/weapon/branch) && magic_repo_personal_form(I))
			return I
	return null

// Why this follower can't ask to make a repository now, or null.
/mob/living/human/proc/magic_repo_begin_problem()
	if (!magic_has_grant())
		return "You don't know that prayer."
	if (!magic_repo_held_form())
		return "Hold something small of your own in your other hand."
	if (magic_repos_kept().len >= magic_repo_allowance())
		return "You can't keep another one yet."
	return null

// Called from divine_dispatch() once the god grants the start.
/mob/living/human/proc/magic_repo_begin()
	var/obj/item/I = magic_repo_held_form()
	if (!I)
		return FALSE
	I.magic_repo_id = magic_repo_new_id()
	I.magic_repo_deity = divine_book_key(divine_patron)
	I.magic_repo_tier = 0
	I.magic_repo_progress = 0
	I.magic_repo_maker = magic_key()
	magic_repo_index[I.magic_repo_id] = I
	if (!islist(magic_kept_repos))
		magic_kept_repos = list()
	magic_kept_repos |= I.magic_repo_id
	to_chat(src, CHAT_TYPED(CHAT_PRAYER, SPAN_NOTICE("\The [I] feels warm in your hand. Now you must pour yourself into it, a little at a time.")))
	log_game("[key_name(src)] began a repository ([I.type], [I.magic_repo_id]) for [I.magic_repo_deity].")
	return TRUE

/mob/living/human/proc/magic_repo_unfinished_held()
	for (var/obj/item/I in list(get_active_hand(), get_inactive_hand()))
		if (I.magic_repo_id && !I.magic_repo_tier && I.magic_repo_maker == magic_key())
			return I
	return null

// A kept, finished repository on this character or beside them that can pay
// seed charge in place of the body.
/mob/living/human/proc/magic_repo_seed_source(obj/except, amount)
	for (var/obj/O in magic_repos_kept())
		if (O == except || O.magic_repo_dormant() || O.magic_repo_charge < amount)
			continue
		if (O in GetAllContents(4))
			return O
		if (get_turf(O) && get_dist(get_turf(O), get_turf(src)) <= 1)
			return O
	return null

/mob/living/human/proc/magic_channel()
	set name = "Channel"
	set category = "IC"
	set desc = "Pour yourself into the thing you are making."
	if (usr != src || !client || client.mob != src || magic_channelling)
		return
	if (!magic_has_grant())
		to_chat(src, SPAN_WARNING("Nothing happens."))
		return
	var/obj/item/I = magic_repo_unfinished_held()
	if (!I)
		to_chat(src, SPAN_WARNING("Hold the thing you are making."))
		return
	if (map && map.persistence && (!persistence_player_restore_ready || persistence_save_in_progress || persistence_active_operation))
		to_chat(src, SPAN_WARNING("Wait for the world save or load to finish."))
		return
	magic_channelling = TRUE
	to_chat(src, SPAN_NOTICE("You close your eyes and pour yourself into \the [I]."))
	var/per_minute_seed = MAGIC_REPO_STORED_SEED * MAGIC_REPO_SITTING / MAGIC_REPO_MAKE_TIME
	while (I && !QDELETED(I) && I.magic_repo_id && !I.magic_repo_tier)
		if (!(I in list(get_active_hand(), get_inactive_hand())) || !magic_has_grant())
			break
		if (!do_after(src, MAGIC_REPO_SITTING, I, needhand = TRUE))
			break
		if (QDELETED(I) || !(I in list(get_active_hand(), get_inactive_hand())))
			break
		var/obj/source = magic_repo_seed_source(I, per_minute_seed)
		if (source)
			source.magic_repo_charge = max(0, source.magic_repo_charge - per_minute_seed)
		else
			if (nutrition < max_nutrition * 0.15 || water < max_water * 0.15)
				to_chat(src, SPAN_WARNING("You are too hungry and thirsty to go on."))
				break
			nutrition = max(0, nutrition - max_nutrition / MAGIC_REPO_BODY_SHARE)
			water = max(0, water - max_water / MAGIC_REPO_BODY_SHARE)
			divine_drain(src, 0.03)
		I.magic_repo_progress += MAGIC_REPO_SITTING
		adaptStat("magic", 1, "repository_channel")
		if (I.magic_repo_progress >= MAGIC_REPO_MAKE_TIME)
			magic_repo_finish(I)
			break
	magic_channelling = FALSE

/mob/living/human/proc/magic_repo_finish(obj/item/I)
	var/skill = max(0.05, magic_skill() / 100)
	I.magic_repo_tier = 1
	I.magic_repo_skill = magic_skill()
	I.magic_repo_capacity = max(1, round(MAGIC_REPO_PERSONAL_CEILING * magic_repo_size_factor(I) * skill))
	I.magic_repo_charge = 0
	I.magic_repo_keepers = list(magic_key())
	I.magic_repo_registrants = list(magic_key())
	if (!islist(magic_registered_repos))
		magic_registered_repos = list()
	magic_registered_repos |= I.magic_repo_id
	adaptStat("magic", 5, "repository_made")
	to_chat(src, CHAT_TYPED(CHAT_PRAYER, SPAN_NOTICE("\The [I] settles in your hand, quiet and full of waiting. It is yours to fill.")))
	log_game("[key_name(src)] finished a repository ([I.type], [I.magic_repo_id], capacity [I.magic_repo_capacity]).")

// ---------- ties ----------

/mob/living/human/proc/magic_ready_tie()
	set name = "Ready a tie"
	set category = "IC"
	set desc = "Tie yourself to the next thing you touch, or loosen a tie."
	if (usr != src || !client || client.mob != src)
		return
	if (!magic_allowed() || !istext(divine_patron))
		return
	var/list/options = list(magic_tie_ready ? "Stop readying a tie" : "Tie myself to the next thing I touch")
	var/list/held = list()
	for (var/id in magic_registered_repos)
		var/obj/O = magic_repo_find(id)
		held["[O ? O.name : "something far away"] ([id])"] = id
	if (held.len)
		options += "Loosen a tie"
	var/pick = player_input(src, "What do you do?", "Ties", null, "anything", options, TRUE)
	switch (pick)
		if ("Tie myself to the next thing I touch")
			magic_tie_ready = TRUE
			to_chat(src, SPAN_NOTICE("You ready yourself. The next thing you touch, you will hold onto."))
		if ("Stop readying a tie")
			magic_tie_ready = FALSE
			to_chat(src, SPAN_NOTICE("You let the thought go."))
		if ("Loosen a tie")
			var/which = player_input(src, "Loosen which tie?", "Ties", null, "anything", held, TRUE)
			var/id = held[which]
			if (!id || !(id in magic_registered_repos))
				return
			magic_registered_repos -= id
			var/obj/O = magic_repo_find(id)
			if (O && islist(O.magic_repo_registrants))
				O.magic_repo_registrants -= magic_key()
			to_chat(src, SPAN_NOTICE("You let that tie go."))

// click.dm: a readied tie catches the next touch, whatever its intent, and the
// touch still does what it would have done.
/proc/magic_touch_hook(mob/user, atom/A)
	var/mob/living/human/H = user
	if (!istype(H) || !H.magic_tie_ready || !istype(A, /obj))
		return
	var/obj/O = A
	if (!O.magic_repo_id)
		return
	if (!O.Adjacent(H) && !(O in H.GetAllContents(4)))
		return
	H.magic_tie_ready = FALSE
	H.magic_tie_to(O)

/mob/living/human/proc/magic_tie_to(obj/O)
	var/key = magic_key()
	if (!magic_allowed() || !O.magic_repo_finished() || divine_book_key(divine_patron) != O.magic_repo_deity || (islist(O.magic_repo_barred) && (key in O.magic_repo_barred)))
		to_chat(src, SPAN_NOTICE("Nothing takes hold."))
		return FALSE
	if (!islist(O.magic_repo_registrants))
		O.magic_repo_registrants = list()
	O.magic_repo_registrants |= key
	if (!islist(magic_registered_repos))
		magic_registered_repos = list()
	magic_registered_repos |= O.magic_repo_id
	to_chat(src, SPAN_NOTICE("You feel a faint thread between you and \the [O]."))
	log_game("[key_name(src)] tied themself to repository [O.magic_repo_id].")
	return TRUE

// ---------- what keepers see ----------

// objs.dm /obj/examine(): only a keeper learns anything.
/obj/proc/magic_repo_examine(mob/living/human/user)
	if (!magic_repo_id || !istype(user) || !user.magic_allowed())
		return
	if (!magic_repo_tier)
		if (magic_repo_maker == user.magic_key())
			to_chat(user, SPAN_NOTICE("You have poured about [round(100 * magic_repo_progress / MAGIC_REPO_MAKE_TIME)]% of what it needs into it."))
		return
	if (!magic_repo_is_keeper(user))
		return
	if (magic_repo_dormant())
		to_chat(user, SPAN_NOTICE("It feels cold and still."))
		return
	to_chat(user, SPAN_NOTICE("You sense it holds about [round(magic_repo_charge)] of [magic_repo_capacity]. [length(magic_repo_registrants)] [length(magic_repo_registrants) == 1 ? "thread runs" : "threads run"] to it."))

// The god took the grant back: everything this character keeps goes still.
/mob/living/human/proc/magic_repo_withdraw_all()
	for (var/obj/O in magic_repos_kept())
		if (O.magic_repo_maker == magic_key())
			O.magic_repo_withdrawn = TRUE

/mob/living/human/proc/magic_repo_restore_all()
	for (var/obj/O in magic_repos_kept())
		if (O.magic_repo_maker == magic_key())
			O.magic_repo_withdrawn = FALSE

// Verbs only magic users ever see (called from divine_refresh_verbs()).
/mob/living/human/proc/magic_repo_refresh_verbs()
	if (magic_allowed() && istext(divine_patron) && length(divine_patron))
		verbs |= /mob/living/human/proc/magic_ready_tie
	else
		verbs -= /mob/living/human/proc/magic_ready_tie
		magic_tie_ready = FALSE
	if (magic_has_grant())
		verbs |= /mob/living/human/proc/magic_channel
	else
		verbs -= /mob/living/human/proc/magic_channel

#undef MAGIC_REPO_MAKE_TIME
#undef MAGIC_REPO_SITTING
#undef MAGIC_REPO_PERSONAL_CEILING
#undef MAGIC_REPO_STORED_SEED
#undef MAGIC_REPO_BODY_SHARE
#undef MAGIC_REPO_SKILL_FLOOR
#undef MAGIC_REPO_DAY
