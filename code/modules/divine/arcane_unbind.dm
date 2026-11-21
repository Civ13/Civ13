// ============================================================
// Unbinding (magic materials and enchanting plan, PR 6). Hidden mechanic: keep
// it out of changelog lines, the wiki and the public Crafting Atlas.
// ------------------------------------------------------------
// A magic user with both hands free but for their stick beseeches Imbue beside
// an ordinary lit fire that stands inside another god's ward, with 3 or more
// Affliction materials in a worn pouch and a vigil of 3 or more kept around
// them. They choose which ward to work against. The god sees a fixed scope line
// and grants or refuses it like any invocation. On Grant the materials burn
// away and that repository loses 50 charge per strength of each one, through
// ward_drain() (6 materials at most). Every Unbinding goes to the admin log
// against the magic user who led it.
//
// The law plan's action registry is not built yet; once it is, register
// "work an Unbinding against the ward" there so magical laws can forbid it.
// ============================================================

#define ARCANE_UNBIND_MIN 3
#define ARCANE_UNBIND_MAX 6
#define ARCANE_UNBIND_PER_STRENGTH 50

/mob/living/human
	var/tmp/obj/arcane_unbind_repo = null // the repository an Unbinding is asked against

/proc/arcane_unbind_fire(obj/O)
	var/obj/structure/oven/F = O
	return istype(F) && !QDELETED(F) && F.on && F.open_flame

/mob/living/human/proc/arcane_fires_beside()
	. = list()
	for (var/obj/structure/oven/F in orange(1, src))
		if (arcane_unbind_fire(F))
			. += F

// Wards over the fire that belong to a god other than this magic user's.
/mob/living/human/proc/arcane_unbind_wards(obj/fire)
	. = list()
	if (!arcane_unbind_fire(fire))
		return
	var/god = divine_book_key(divine_patron)
	for (var/obj/repo in wards_at(get_turf(fire))) // repository_wards.dm
		if (repo.magic_repo_deity != god)
			. += repo

/mob/living/human/proc/arcane_unbind_materials()
	var/list/picked = list()
	for (var/obj/item/I in arcane_pouch_items())
		if (picked.len < ARCANE_UNBIND_MAX && I.arcane_virtue() == "affliction" && !I.arcane_enchant)
			picked += I
	return picked.len >= ARCANE_UNBIND_MIN ? picked : null

/proc/arcane_unbind_amount(list/materials)
	var/total = 0
	for (var/obj/item/I in materials)
		if (I.arcane_virtue())
			total += clamp(I.arcane_strength, 1, 3) * ARCANE_UNBIND_PER_STRENGTH
	return total

/mob/living/human/proc/arcane_unbind_pick(obj/fire)
	arcane_unbind_repo = null
	var/list/wards = list()
	for (var/obj/repo in arcane_unbind_wards(fire))
		wards["The [magic_repo_tier_name(repo.magic_repo_tier)] ward of [divine_label_for(repo.magic_repo_deity)]"] = repo
	if (!wards.len)
		to_chat(src, SPAN_WARNING("No other god's ward lies over this fire."))
		return FALSE
	var/obj/repo = wards.len == 1 ? wards[wards[1]] : wards[player_input(src, "Which ward do you work against?", "Unbinding", null, "anything", wards, TRUE)]
	if (!repo || QDELETED(repo))
		return FALSE
	arcane_unbind_repo = repo
	return TRUE

// Why the Unbinding asked for can't go ahead, or null.
/mob/living/human/proc/arcane_unbind_problem(obj/fire)
	if (!arcane_unbind_fire(fire))
		return "The fire has gone out."
	if (!arcane_unbind_repo || !(arcane_unbind_repo in arcane_unbind_wards(fire)))
		return "Nothing holds over this place any more."
	if (!arcane_unbind_materials())
		return "You need at least [ARCANE_UNBIND_MIN] of the right things in your pouch."
	if (!arcane_vigil_holds()) // arcane_ward.dm
		return "The vigil has broken."
	return null

/mob/living/human/proc/arcane_unbind_scope(obj/fire, list/materials, vigil)
	var/obj/repo = arcane_unbind_repo
	var/list/names = list()
	for (var/obj/item/M in materials)
		names += "[M.name] ([M.arcane_virtue()] [M.arcane_strength])"
	return "unbinding-v1: drain [arcane_unbind_amount(materials)] charge from the [magic_repo_tier_name(repo.magic_repo_tier)] repository [repo.magic_repo_id] of [repo.magic_repo_deity] at [arcane_enchant_place(repo)], burning [english_list(names)] in [fire.name]; vigil of [vigil]; costs the slot"

// On Grant, from arcane_imbue_apply() once the materials are burnt.
/mob/living/human/proc/arcane_unbind_apply(obj/fire, obj/repo, amount, list/names)
	if (!istype(repo) || QDELETED(repo) || amount <= 0)
		return FALSE
	var/before = repo.magic_repo_charge
	ward_drain(repo, amount, src)
	var/drained = max(0, before - repo.magic_repo_charge)
	log_admin("Unbinding: [key_name(src)] burned [english_list(names)] in [fire] at [arcane_enchant_place(fire)] against [repo.magic_repo_id] of [repo.magic_repo_deity]: [drained] charge drained, [repo.magic_repo_charge] left.")
	log_game("[key_name(src)] worked an Unbinding against [repo.magic_repo_id] of [repo.magic_repo_deity]: [drained] charge drained.")
	to_chat(src, SPAN_NOTICE("<i>The smoke goes up thin and bitter. Something gives way.</i>"))
	return TRUE

#undef ARCANE_UNBIND_MIN
#undef ARCANE_UNBIND_MAX
#undef ARCANE_UNBIND_PER_STRENGTH
