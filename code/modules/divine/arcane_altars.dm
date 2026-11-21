// ============================================================
// Altars and materials in casting (magic materials and enchanting plan, PR 3).
// Hidden mechanic: keep it out of changelog lines, the wiki and the public
// Crafting Atlas.
// ------------------------------------------------------------
// A magic user dedicates an ordinary table to their god with a short prayer
// (Tend an Altar). Nothing about the table changes: the dedication is a few
// hidden saved fields. Each magic user keeps up to ARCANE_ALTARS_EACH altars.
// Moving or breaking the table ends it; a magic user of another god may
// re-dedicate it, which starts it over.
//
// An altar grows with use. Each real day on which someone worships there
// counts, as do the different worshippers; the standing (New, Kept,
// Established, Hallowed) scales what is done there, and drops a step after
// every 14 real days of neglect. Other plans record worship through
// arcane_altar_worship() and read arcane_altar_percent().
//
// Worship here: an attuned material offered at an altar feeds one of the
// worshipper's tied repositories of the altar's god through ward_refill(),
// 25 per strength (doubled for Ward), scaled by the altar's standing.
//
// Materials in casting: a pouch component whose aspect matches the invocation
// strengthens it by a quarter per strength, and an attuned stick of storm
// wood held as the focus lets the invocation come back after 45 real minutes
// instead of an hour.
// ============================================================

#define ARCANE_ALTARS_EACH 3
#define ARCANE_ALTAR_DAY 864000          // deciseconds of real time in a day
#define ARCANE_ALTAR_NEGLECT 12096000    // 14 real days
#define ARCANE_ALTAR_DEDICATE_TIME 50
#define ARCANE_OFFERING_PER_STRENGTH 25

// Standing 0 to 3 -> what a magic user of the altar's god sees on examine.
var/global/list/arcane_altar_lines = list(
	"Someone has prayed here.",
	"Offerings have been left here before.",
	"Old offerings have worn the wood smooth.",
	"The place feels hallowed.",
)
var/global/list/arcane_altar_percents = list(25, 50, 75, 100)
// Standing -> list(days of worship, different worshippers) needed.
var/global/list/arcane_altar_thresholds = list(list(0, 0), list(5, 0), list(15, 3), list(40, 5))

/obj
	var/arcane_altar_deity = null       // saved: the god it serves (divine_book_key form)
	var/arcane_altar_by = null          // saved: ckey of the magic user who dedicated it
	var/arcane_altar_spot = null        // saved: "x,y,z" where it was dedicated
	var/arcane_altar_since = 0          // saved: world.realtime of dedication
	var/arcane_altar_days = 0           // saved: real days on which someone worshipped here
	var/arcane_altar_day = 0            // saved: the real day last counted
	var/arcane_altar_last = 0           // saved: world.realtime of the last worship
	var/list/arcane_altar_worshippers = null // saved: ckeys who have worshipped here
	var/list/arcane_altar_feeds = null  // saved: ckey -> repository id they last fed from here

/mob/living/human
	var/list/arcane_altar_spots = null  // saved: "x,y,z" of the altars this character dedicated

// ---- The altar -------------------------------------------------------------

/proc/arcane_altar_surface(obj/O)
	return istype(O, /obj/structure/table) && !QDELETED(O) && isturf(O.loc)

/obj/proc/arcane_spot_key()
	return isturf(loc) ? "[x],[y],[z]" : null

// The altar's god, or null. A moved table loses its dedication here.
/obj/proc/arcane_altar_live()
	if (!arcane_altar_deity)
		return null
	if (!arcane_altar_surface(src) || arcane_spot_key() != arcane_altar_spot)
		arcane_altar_end()
		return null
	return arcane_altar_deity

/obj/proc/arcane_altar_end()
	arcane_altar_deity = null
	arcane_altar_by = null
	arcane_altar_spot = null
	arcane_altar_since = 0
	arcane_altar_days = 0
	arcane_altar_day = 0
	arcane_altar_last = 0
	arcane_altar_worshippers = null
	arcane_altar_feeds = null

// Standing 0 (New) to 3 (Hallowed) after neglect, or -1 for no altar.
/obj/proc/arcane_altar_standing()
	if (!arcane_altar_live())
		return -1
	var/count = islist(arcane_altar_worshippers) ? arcane_altar_worshippers.len : 0
	var/standing = 0
	for (var/step in 1 to 3)
		var/list/need = arcane_altar_thresholds[step + 1]
		if (arcane_altar_days >= need[1] && count >= need[2])
			standing = step
	var/since = max(arcane_altar_last, arcane_altar_since)
	if (world.realtime > since)
		standing -= round((world.realtime - since) / ARCANE_ALTAR_NEGLECT)
	return max(0, standing)

/obj/proc/arcane_altar_percent()
	var/standing = arcane_altar_standing()
	return standing < 0 ? 0 : arcane_altar_percents[standing + 1]

// Counts a day of worship by this worshipper. Neglect already suffered is kept:
// the day count falls back to what the dropped standing needs.
/obj/proc/arcane_altar_worship(mob/living/human/H)
	if (!arcane_altar_live() || !istype(H) || !H.ckey)
		return FALSE
	var/standing = arcane_altar_standing()
	var/list/need = arcane_altar_thresholds[standing + 1]
	var/list/next = standing < 3 ? arcane_altar_thresholds[standing + 2] : null
	if (next && arcane_altar_days >= next[1])
		arcane_altar_days = need[1]
	var/today = round(world.realtime / ARCANE_ALTAR_DAY)
	if (today != arcane_altar_day)
		arcane_altar_day = today
		arcane_altar_days++
	arcane_altar_last = world.realtime
	if (!islist(arcane_altar_worshippers))
		arcane_altar_worshippers = list()
	arcane_altar_worshippers |= H.ckey
	return TRUE

// One plain line for a magic user of the altar's god; called from /obj/examine.
/obj/proc/arcane_altar_examine(mob/user)
	var/mob/living/human/H = user
	if (!istype(H) || !H.arcane_magic_user() || divine_book_key(H.divine_patron) != arcane_altar_live())
		return
	to_chat(H, SPAN_NOTICE("<i>[arcane_altar_lines[arcane_altar_standing() + 1]]</i>"))

// The altars this character dedicated that still stand, pruning the rest.
/mob/living/human/proc/arcane_my_altars()
	. = list()
	var/restored = !map || !map.persistence || persistence_player_restore_ready
	for (var/spot in arcane_altar_spots)
		var/list/xyz = splittext(spot, ",")
		var/turf/T = xyz.len == 3 ? locate(text2num(xyz[1]), text2num(xyz[2]), text2num(xyz[3])) : null
		var/obj/found = null
		for (var/obj/structure/table/O in T)
			if (O.arcane_altar_by == ckey && O.arcane_altar_live())
				found = O
				break
		if (found)
			. += found
		else if (restored)
			arcane_altar_spots -= spot

/mob/living/human/proc/arcane_altar_beside()
	. = list()
	for (var/obj/structure/table/O in orange(1, src))
		if (arcane_altar_surface(O))
			. += O

// ---- Tending altars --------------------------------------------------------

/mob/living/human/proc/arcane_refresh_verbs()
	if (istext(divine_patron) && length(divine_patron) && magic_allowed())
		verbs |= list(/mob/living/human/proc/arcane_tend_altar, /mob/living/human/proc/arcane_commune) // commune: arcane_spirits.dm
	else
		verbs -= list(/mob/living/human/proc/arcane_tend_altar, /mob/living/human/proc/arcane_commune)

/mob/living/human/proc/arcane_tend_altar()
	set name = "Tend an Altar"
	set category = "IC"
	set desc = "Dedicate a table beside you to your god, let one go, or make an offering at one."
	if (usr != src || !client || client.mob != src)
		return
	if (!arcane_magic_user() || stat != CONSCIOUS || incapacitated())
		return
	var/god = divine_book_key(divine_patron)
	var/list/tables = arcane_altar_beside()
	if (!tables.len)
		to_chat(src, SPAN_WARNING("Stand beside a table."))
		return
	var/obj/O = tables[1]
	if (tables.len > 1)
		var/list/named = list()
		for (var/obj/T in tables)
			named["[T.name] ([dir2text(get_dir(src, T))])"] = T
		O = named[player_input(src, "Which one?", "Altar", null, "anything", named, TRUE)]
		if (!O)
			return
	var/list/options = list()
	if (O.arcane_altar_live() == god)
		options += "Make an offering"
		if (O.arcane_altar_by == ckey)
			options += "Let this altar go"
	else
		options += "Dedicate it to [divine_label_for(divine_patron)]"
	var/pick = player_input(src, "What do you do?", "Altar", null, "anything", options, TRUE)
	if (!pick || QDELETED(O) || !O.Adjacent(src) || !arcane_magic_user())
		return
	if (pick == "Make an offering")
		arcane_offer_at(O)
	else if (pick == "Let this altar go")
		if (O.arcane_altar_by == ckey)
			arcane_altar_spots -= O.arcane_altar_spot
			log_game("[key_name(src)] let go of an altar at [O.arcane_altar_spot].")
			O.arcane_altar_end()
			to_chat(src, SPAN_NOTICE("You quietly take your leave of [O]."))
	else
		arcane_dedicate(O)

/mob/living/human/proc/arcane_dedicate(obj/O)
	if (!verified_discord_id(ckey))
		to_chat(src, SPAN_WARNING("No answer comes."))
		return FALSE
	if (map && map.persistence && (!persistence_player_restore_ready || persistence_save_in_progress || persistence_active_operation))
		to_chat(src, SPAN_WARNING("Wait for the world save or load to finish."))
		return FALSE
	if (arcane_my_altars().len >= ARCANE_ALTARS_EACH)
		to_chat(src, SPAN_WARNING("You already keep [ARCANE_ALTARS_EACH] altars. Let one go first."))
		return FALSE
	to_chat(src, SPAN_NOTICE("You lay your hands on [O] and pray quietly."))
	if (!do_after(src, ARCANE_ALTAR_DEDICATE_TIME, O))
		return FALSE
	var/god = divine_book_key(divine_patron)
	if (QDELETED(O) || !arcane_altar_surface(O) || !O.Adjacent(src) || !arcane_magic_user() || O.arcane_altar_live() == god || arcane_my_altars().len >= ARCANE_ALTARS_EACH)
		return FALSE
	if (O.arcane_altar_deity)
		log_game("[key_name(src)] re-dedicated an altar of [O.arcane_altar_deity] at [O.arcane_altar_spot].")
	O.arcane_altar_end()
	O.arcane_altar_deity = god
	O.arcane_altar_by = ckey
	O.arcane_altar_spot = O.arcane_spot_key()
	O.arcane_altar_since = world.realtime
	if (!islist(arcane_altar_spots))
		arcane_altar_spots = list()
	arcane_altar_spots |= O.arcane_altar_spot
	to_chat(src, SPAN_NOTICE("<i>[arcane_altar_lines[1]]</i>"))
	log_game("[key_name(src)] dedicated [O] ([O.type]) at [O.arcane_altar_spot] to [god].")
	return TRUE

// An attuned material in hand, offered at an altar of this character's god,
// feeds one of their tied repositories of that god.
/mob/living/human/proc/arcane_offer_at(obj/O)
	var/god = O.arcane_altar_live()
	var/obj/item/I = get_active_hand()
	if (!istype(I) || !I.arcane_virtue())
		to_chat(src, SPAN_WARNING("Nothing in your hand would do."))
		return FALSE
	var/list/repos = list()
	for (var/obj/R in magic_registered_repositories())
		if (R.magic_repo_deity == god)
			repos["[R.name] ([R.magic_repo_id])"] = R
	if (!repos.len)
		to_chat(src, SPAN_WARNING("You are tied to nothing it could reach."))
		return FALSE
	var/default_id = islist(O.arcane_altar_feeds) ? O.arcane_altar_feeds[ckey] : null
	var/obj/target = null
	for (var/label in repos)
		var/obj/R = repos[label]
		if (R.magic_repo_id == default_id)
			target = R
	if (repos.len > 1 || !target)
		target = repos[player_input(src, "Feed which?", "Offering", null, "anything", repos, TRUE)]
	if (!target || QDELETED(O) || QDELETED(I) || I != get_active_hand() || !O.Adjacent(src) || O.arcane_altar_live() != god || !I.arcane_virtue())
		return FALSE
	var/amount = ARCANE_OFFERING_PER_STRENGTH * I.arcane_strength * (I.arcane_virtue() == "ward" ? 2 : 1)
	amount = round(amount * O.arcane_altar_percent() / 100)
	var/added = ward_refill(target, amount, "offering", src)
	if (!added)
		to_chat(src, SPAN_NOTICE("Nothing takes it today."))
		return FALSE
	if (!islist(O.arcane_altar_feeds))
		O.arcane_altar_feeds = list()
	O.arcane_altar_feeds[ckey] = target.magic_repo_id
	O.arcane_altar_worship(src)
	log_game("[key_name(src)] offered [I] ([I.arcane_virtue()] [I.arcane_strength]) at an altar of [god]: [added] charge to [target.magic_repo_id].")
	var/obj/item/stack/S = I
	if (istype(S) && S.amount > 1)
		S.use(1)
	else
		qdel(I)
	to_chat(src, SPAN_NOTICE("You leave it on [O]. <i>It is taken.</i>"))
	return TRUE

// ---- Materials in casting --------------------------------------------------

// A pouch component of the invocation's own aspect strengthens it: x1.25 per strength.
/proc/arcane_component_bonus(obj/item/component, spell)
	if (!istype(component))
		return 1
	var/aspect = component.arcane_virtue()
	if (!aspect)
		return 1
	if (aspect == spell || (aspect == "mercy" && spell == "vigil"))
		return 1 + 0.25 * component.arcane_strength
	return 1

/proc/arcane_storm_focus(obj/item/I)
	return istype(I, /obj/item/stack/material/wood) && I.arcane_virtue() == "storm"

#undef ARCANE_ALTARS_EACH
#undef ARCANE_ALTAR_DAY
#undef ARCANE_ALTAR_NEGLECT
#undef ARCANE_ALTAR_DEDICATE_TIME
#undef ARCANE_OFFERING_PER_STRENGTH
