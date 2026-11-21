// ============================================================
// Magic materials (magic materials and enchanting plan, PR 2). Hidden mechanic:
// keep it out of changelog lines, the wiki and the public Crafting Atlas.
// ------------------------------------------------------------
// A material is an ORDINARY item with a hidden virtue: an aspect (which kind
// of prayer it serves) and a strength from 1 to 3. Only a magic user gathering
// the item themselves, under the right condition, puts the virtue in; anyone
// else doing the same thing gets the plain item. Nothing here changes an
// item's type, name, sprite or description. A magic user who examines one sees
// a single plain line; nobody else sees anything.
//
// The virtue is plain saved fields on /obj/item. It fades 14 real days after
// gathering. Attuned stacks never merge with plain or differently attuned ones
// (stack_compatible), and splitting a stack keeps the virtue on both halves.
// A magic user can attune 3 materials per rest, separately from the day's
// invocation.
// ============================================================

#define ARCANE_FADE 12096000            // deciseconds of real time: 14 days
#define ARCANE_GATHERS_PER_REST 3
#define ARCANE_GATHER_REST_FALLBACK 36000 // real time after which the count resets without sleep
#define ARCANE_STORM_WINDOW 36000       // a strike site stays fresh for an hour of real time
#define ARCANE_STORM_RANGE 2            // tiles from the strike
#define ARCANE_STORM_MARKS 64           // strike sites remembered

// Aspect id -> how a magic user feels it on examine. Shown to magic users only.
var/global/list/arcane_aspect_lines = list(
	"storm" = "It still smells of the storm.",
	"mercy" = "It feels gentle in your hands.",
	"affliction" = "It feels cold and heavy in your hands.",
	"omen" = "It seems to catch the light oddly.",
	"ward" = "It feels steady and old in your hands.",
)

// Recent lightning strikes: list(x, y, world.realtime). Runtime only.
var/global/list/arcane_storm_marks = list()

/obj/item
	var/arcane_aspect = null      // saved: aspect id, or null for an ordinary item
	var/arcane_strength = 0       // saved: 1 to 3
	var/arcane_gathered_at = 0    // saved: world.realtime when it was gathered
	var/arcane_gatherer = null    // saved: ckey of the magic user who gathered it

/mob/living/human
	var/arcane_gathers_spent = 0  // saved: materials attuned since the last rest
	var/arcane_gathers_since = 0  // saved: world.realtime of the first of them

// The item's aspect, or null. A faded virtue is cleared here.
/obj/item/proc/arcane_virtue()
	if (!arcane_aspect)
		return null
	if (!isnum(arcane_gathered_at) || world.realtime < arcane_gathered_at || world.realtime > arcane_gathered_at + ARCANE_FADE)
		arcane_clear()
		return null
	return arcane_aspect

/obj/item/proc/arcane_clear()
	arcane_aspect = null
	arcane_strength = 0
	arcane_gathered_at = 0
	arcane_gatherer = null

// Two stacks may merge only when they carry the same virtue, or none.
/proc/arcane_same_virtue(obj/item/A, obj/item/B)
	if (!istype(A) || !istype(B))
		return TRUE
	var/a = A.arcane_virtue()
	var/b = B.arcane_virtue()
	if (a != b)
		return FALSE
	return !a || A.arcane_strength == B.arcane_strength

/proc/arcane_copy_virtue(obj/item/from, obj/item/to_item)
	if (!istype(from) || !istype(to_item) || !from.arcane_virtue())
		return
	to_item.arcane_aspect = from.arcane_aspect
	to_item.arcane_strength = from.arcane_strength
	to_item.arcane_gathered_at = from.arcane_gathered_at
	to_item.arcane_gatherer = from.arcane_gatherer

// One plain line for a magic user who examines an attuned item.
/obj/item/proc/arcane_examine(mob/user)
	var/mob/living/human/H = user
	if (!istype(H) || !H.arcane_magic_user())
		return
	arcane_enchant_examine(H) // arcane_enchant.dm
	var/aspect = arcane_virtue()
	if (!aspect)
		return
	var/line = arcane_aspect_lines[aspect]
	if (line)
		to_chat(H, SPAN_NOTICE("<i>[line]</i>"))

// A whitelisted, initiated character played by its own client.
/mob/living/human/proc/arcane_magic_user()
	return istext(divine_patron) && length(divine_patron) && client && client.mob == src && magic_allowed()

// A keeper of a finished repository may gather Ward materials.
/mob/living/human/proc/arcane_ward_keeper()
	for (var/obj/O in magic_repos_kept())
		if (O.magic_repo_finished())
			return TRUE
	return FALSE

// Whether this magic user can put this aspect into what they gather.
/mob/living/human/proc/arcane_knows(aspect)
	switch (aspect)
		if ("storm")
			return TRUE
		if ("ward")
			return arcane_ward_keeper()
		if ("mercy")
			return islist(divine_known) && (("mercy" in divine_known) || ("vigil" in divine_known))
		if ("affliction", "omen")
			return islist(divine_known) && (aspect in divine_known)
	return FALSE

/mob/living/human/proc/arcane_gather_ready()
	if (arcane_gathers_spent < ARCANE_GATHERS_PER_REST)
		return TRUE
	if (world.realtime >= arcane_gathers_since + ARCANE_GATHER_REST_FALLBACK || world.realtime < arcane_gathers_since)
		arcane_gathers_spent = 0
		return TRUE
	return FALSE

// A night's rest lets a magic user gather again (called from divine_rested).
/mob/living/human/proc/arcane_rested()
	arcane_gathers_spent = 0

// Puts a virtue into an item this character just gathered, if they can.
// Says nothing when they can't: to everyone else it is simply the item.
/mob/living/human/proc/arcane_attune(obj/item/I, aspect, strength, why)
	if (!istype(I) || QDELETED(I) || I.arcane_virtue())
		return FALSE
	if (!arcane_magic_user() || !verified_discord_id(ckey) || !arcane_knows(aspect) || !arcane_gather_ready())
		return FALSE
	if (map && map.persistence && (!persistence_player_restore_ready || persistence_save_in_progress || persistence_active_operation))
		return FALSE
	if (!arcane_gathers_spent)
		arcane_gathers_since = world.realtime
	arcane_gathers_spent++
	I.arcane_aspect = aspect
	I.arcane_strength = clamp(round(strength), 1, 3)
	I.arcane_gathered_at = world.realtime
	I.arcane_gatherer = ckey
	var/line = arcane_aspect_lines[aspect]
	if (line)
		to_chat(src, SPAN_NOTICE("<i>[line]</i>"))
	log_admin("Arcane material: [key_name(src)] attuned [I] ([I.type]) as [aspect] [I.arcane_strength] ([why]).")
	return TRUE

// ---- Gathering conditions -------------------------------------------------

// Called by weather_lightning() for every strike.
/proc/arcane_note_strike(x, y)
	arcane_storm_marks += list(list(x, y, world.realtime))
	if (arcane_storm_marks.len > ARCANE_STORM_MARKS)
		arcane_storm_marks.Cut(1, arcane_storm_marks.len - ARCANE_STORM_MARKS + 1)

/proc/arcane_storm_near(turf/T)
	if (!T)
		return FALSE
	for (var/list/mark in arcane_storm_marks)
		if (world.realtime < mark[3] || world.realtime > mark[3] + ARCANE_STORM_WINDOW)
			continue
		if (abs(mark[1] - T.x) <= ARCANE_STORM_RANGE && abs(mark[2] - T.y) <= ARCANE_STORM_RANGE)
			return TRUE
	return FALSE

// Storm wood: a tree felled near a fresh lightning strike. Only the felled
// tree's own planks take the virtue, even when they fell onto an old pile.
/mob/living/human/proc/arcane_felled_tree(turf/T, planks = 4)
	if (!T || !arcane_storm_near(T))
		return FALSE
	var/obj/item/stack/material/wood/W = null
	for (var/obj/item/stack/material/wood/pile in T)
		if (!pile.arcane_virtue() && pile.amount >= planks)
			W = pile
			break
	if (!W || !arcane_magic_user() || !arcane_knows("storm") || !arcane_gather_ready())
		return FALSE
	if (W.amount > planks)
		W = W.split(planks)
		if (!istype(W))
			return FALSE
	. = arcane_attune(W, "storm", 2, "storm wood")
	W.update_strings()
	W.update_icon()

// Dawn water: water drawn from a river, lake or sea in the early morning.
/mob/living/human/proc/arcane_drew_water(obj/item/weapon/reagent_containers/RG)
	if (!istype(RG) || time_of_day != "Early Morning" || !RG.reagents || !RG.reagents.has_reagent("water"))
		return FALSE
	return arcane_attune(RG, "mercy", 1, "dawn water")

#undef ARCANE_FADE
#undef ARCANE_GATHERS_PER_REST
#undef ARCANE_GATHER_REST_FALLBACK
#undef ARCANE_STORM_WINDOW
#undef ARCANE_STORM_RANGE
#undef ARCANE_STORM_MARKS
