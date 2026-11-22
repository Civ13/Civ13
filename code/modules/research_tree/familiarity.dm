// ============================================================
// Research Tree - familiarity: learning from the things themselves
// (Val, 2026-11-19, reviewed 2026-11-21)
// ------------------------------------------------------------
// On book-research worlds a character slowly comes to understand a subject
// they do not know by living with its things: using them (holding one and
// working it, firing it, wearing it, working a structure or machine) and
// being around them. Where a thing came from does not matter.
//
// Familiarity adds to the same study progress reading, watching and guided
// work use (study_progress.dm), but it never finishes a subject on its own:
//  - its own share of a subject is capped, lower the later the subject's era
//    (FAMILIARITY_CAP_BASE down to FAMILIARITY_CAP_FLOOR), and
//  - it never takes the last step: a book, a teacher or a bench finishes.
// It also builds slowly, at most FAMILIARITY_DAILY of a subject per real day.
// ============================================================

// The first use of each kind of thing, then each later use (spaced out).
#define FAMILIARITY_FIRST_USE 0.05
#define FAMILIARITY_REPEAT_USE 0.01
#define FAMILIARITY_REPEAT_GAP (2 MINUTES)
// Each kind of thing noticed nearby, once.
#define FAMILIARITY_NEARBY 0.02
#define FAMILIARITY_NEARBY_RANGE 3
// Life ticks between looks at worn things and the surroundings.
#define FAMILIARITY_LOOK_EVERY 60
// Most of one subject familiarity can add in one real day.
#define FAMILIARITY_DAILY 0.1
// Familiarity's own share of a subject: half of a Stone Age subject, 5%
// less for each later era, never below the floor.
#define FAMILIARITY_CAP_BASE 0.5
#define FAMILIARITY_CAP_STEP 0.05
#define FAMILIARITY_CAP_FLOOR 0.05
// Clicks closer together than this are not looked at.
#define FAMILIARITY_CLICK_GAP 30
#define FAMILIARITY_RECORD_LIMIT 600
#define FAMILIARITY_DAY (24 * 60 * 60 * 10)

/mob/living/human
	// "<node>" => share of it learned through familiarity, "u:<type>" and
	// "n:<type>" => kinds used and noticed, "t:<node>" => today's share,
	// "day" => the real day those were counted on.
	var/list/familiarity = null
	var/tmp/list/familiar_last_use = null // node => world.time of the last repeat use
	var/tmp/next_familiar_click = 0

// type => node id it belongs to, or "" for none.
var/global/list/familiarity_node_cache = list()

/proc/familiarity_node_of(atom/movable/A)
	if (!isobj(A))
		return null
	var/node_id = familiarity_node_cache[A.type]
	if (isnull(node_id))
		node_id = research_sample_node(A)
		node_id = istext(node_id) ? node_id : ""
		familiarity_node_cache[A.type] = node_id
	return length(node_id) ? node_id : null

// Most of N that familiarity alone can teach.
/proc/familiarity_cap(datum/research_node/N)
	if (!N)
		return 0
	var/tier = isnum(N.era_tier) ? max(0, N.era_tier) : 0
	return max(FAMILIARITY_CAP_FLOOR, FAMILIARITY_CAP_BASE - tier * FAMILIARITY_CAP_STEP)

/proc/familiarity_today()
	return round(world.realtime / FAMILIARITY_DAY)

/mob/living/human/proc/familiarity_value(key)
	if (!islist(familiarity))
		return 0
	var/value = familiarity[key]
	return isnum(value) ? max(0, value) : 0

// Whether src can come to know more of node_id by familiarity now.
/mob/living/human/proc/can_grow_familiar(node_id)
	if (!map || !map.book_research_enabled() || stat != CONSCIOUS)
		return FALSE
	var/datum/research_node/N = get_research_node(node_id)
	if (!N || research_node_dormant(N) || N.mode == RESEARCH_MODE_BOOK)
		return FALSE
	if (knows_recipe_node(node_id) || recipe_knowledge_exempt())
		return FALSE
	return familiarity_value(node_id) < familiarity_cap(N) && study_fraction(node_id) < 0.99

/proc/clean_familiarity(value)
	var/list/result = list()
	if (!islist(value))
		return result
	var/today = familiarity_today()
	var/day = value["day"]
	var/same_day = isnum(day) && day == today
	result["day"] = today
	for (var/key in value)
		if (!istext(key) || key == "day" || !length(key) || length(key) > 200 || result.len >= FAMILIARITY_RECORD_LIMIT)
			continue
		var/amount = value[key]
		if (!isnum(amount) || amount <= 0)
			continue
		var/prefix = copytext(key, 1, 3)
		if (prefix == "t:")
			if (same_day && valid_recipe_node_id(copytext(key, 3)))
				result[key] = min(FAMILIARITY_DAILY, amount)
		else if (prefix == "u:" || prefix == "n:")
			result[key] = 1
		else if (valid_recipe_node_id(key))
			result[key] = min(1, round(amount, 0.001))
	return result

/mob/living/human/persistence_import_fields(list/saved_fields)
	. = ..()
	familiarity = clean_familiarity(familiarity)
	if (stat == DEAD)
		familiarity = list()

/mob/living/human/forget_recipe_knowledge()
	..()
	familiarity = list()

// Adds up to share of node_id by familiarity. Returns the share added.
/mob/living/human/proc/add_familiarity(node_id, share, atom/movable/thing, used = TRUE)
	if (share <= 0 || !can_grow_familiar(node_id))
		return 0
	var/datum/research_node/N = get_research_node(node_id)
	var/today = familiarity_today()
	if (!islist(familiarity) || familiarity["day"] != today)
		familiarity = clean_familiarity(familiarity)
	if (familiarity.len + 2 > FAMILIARITY_RECORD_LIMIT)
		return 0
	var/own = familiarity_value(node_id)
	var/day_key = "t:[node_id]"
	var/room = min(familiarity_cap(N) - own, FAMILIARITY_DAILY - familiarity_value(day_key))
	var/before = study_fraction(node_id)
	share = min(share, room, 0.99 - before)
	if (share <= 0)
		return 0
	familiarity[node_id] = round(own + share, 0.001)
	familiarity[day_key] = round(familiarity_value(day_key) + share, 0.001)
	note_study_progress(node_id, before + share)
	var/after = study_fraction(node_id)
	var/what = thing ? "[thing.name]" : "it"
	if (!own)
		to_chat(src, SPAN_NOTICE("[used ? "Working with" : "Living around"] [what], you start to get a feel for <b>[N.name]</b>."))
	else if (familiarity_value(node_id) >= familiarity_cap(N))
		to_chat(src, SPAN_NOTICE("You have picked up all you can of <b>[N.name]</b> from its things alone ([round(after * 100)]%). The rest takes a book, a teacher or a bench."))
	else if (round(after * 4) > round(before * 4))
		to_chat(src, SPAN_NOTICE("You understand more of <b>[N.name]</b> ([round(after * 100)]%)."))
	return share

// src used thing: the first use of a kind teaches more, later ones a little,
// spaced out.
/mob/living/human/proc/note_familiar_use(atom/movable/thing)
	var/node_id = familiarity_node_of(thing)
	if (!node_id || !can_grow_familiar(node_id))
		return 0
	var/kind = "u:[thing.type]"
	if (!familiarity_value(kind))
		if (!islist(familiarity))
			familiarity = list("day" = familiarity_today())
		if (familiarity.len + 3 > FAMILIARITY_RECORD_LIMIT)
			return 0
		familiarity[kind] = 1
		return add_familiarity(node_id, FAMILIARITY_FIRST_USE, thing, TRUE)
	if (!islist(familiar_last_use))
		familiar_last_use = list()
	var/last = familiar_last_use[node_id]
	if (isnum(last) && world.time < last + FAMILIARITY_REPEAT_GAP)
		return 0
	familiar_last_use[node_id] = world.time
	return add_familiarity(node_id, FAMILIARITY_REPEAT_USE, thing, TRUE)

// src noticed thing nearby: once per kind.
/mob/living/human/proc/note_familiar_sight(atom/movable/thing)
	var/node_id = familiarity_node_of(thing)
	if (!node_id)
		return 0
	var/kind = "n:[thing.type]"
	if (familiarity_value(kind) || !can_grow_familiar(node_id))
		return 0
	if (!islist(familiarity))
		familiarity = list("day" = familiarity_today())
	if (familiarity.len + 3 > FAMILIARITY_RECORD_LIMIT)
		return 0
	familiarity[kind] = 1
	return add_familiarity(node_id, FAMILIARITY_NEARBY, thing, FALSE)

// Called from ClickOn: using the thing in hand, or working an object by hand.
/proc/note_familiar_click(mob/user, obj/item/held, atom/target)
	if (!ishuman(user) || !map || !map.book_research_enabled())
		return 0
	var/mob/living/human/H = user
	if (!H.client || world.time < H.next_familiar_click)
		return 0
	H.next_familiar_click = world.time + FAMILIARITY_CLICK_GAP
	if (held)
		return H.note_familiar_use(held)
	if (isobj(target) && isturf(target.loc) && target.Adjacent(H))
		return H.note_familiar_use(target)
	return 0

// Called from Life: what src wears counts as use; one new kind of thing
// nearby is noticed.
/mob/living/human/proc/handle_familiarity()
	if ((life_tick % FAMILIARITY_LOOK_EVERY) || !client || stat != CONSCIOUS || !isturf(loc) || !map || !map.book_research_enabled())
		return
	for (var/obj/item/clothing/C in get_equipped_items())
		if (note_familiar_use(C))
			break
	for (var/obj/O in range(FAMILIARITY_NEARBY_RANGE, src))
		if (O.invisibility || !O.icon)
			continue
		if (note_familiar_sight(O))
			return

#undef FAMILIARITY_FIRST_USE
#undef FAMILIARITY_REPEAT_USE
#undef FAMILIARITY_REPEAT_GAP
#undef FAMILIARITY_NEARBY
#undef FAMILIARITY_NEARBY_RANGE
#undef FAMILIARITY_LOOK_EVERY
#undef FAMILIARITY_DAILY
#undef FAMILIARITY_CAP_BASE
#undef FAMILIARITY_CAP_STEP
#undef FAMILIARITY_CAP_FLOOR
#undef FAMILIARITY_CLICK_GAP
#undef FAMILIARITY_RECORD_LIMIT
#undef FAMILIARITY_DAY
