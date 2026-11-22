// ============================================================
// Blessings (magic materials and enchanting plan, PR 7). Hidden mechanic:
// keep it out of changelog lines, the wiki and the public Crafting Atlas.
// ------------------------------------------------------------
// A magic user taught Bless stands at an altar of their god holding an
// ordinary item in the hand without their stick, with a sacrifice of goods
// laid on the altar, and beseeches. The god sees the item, the number to
// raise, the next tier and the sacrifice, and grants or refuses it. On Grant
// the sacrifice is destroyed and the item goes up one tier (one per rest, up
// to 3, and no higher than the altar's standing allows). A blessing raises a
// number the item already has, works for whoever uses it, has no charges and
// lasts until the item is destroyed or recrafted, or someone unweaves it
// (Imbue). Its name, sprite and description never change.
// ============================================================

#define ARCANE_BLESS_MAX 3
#define ARCANE_ARMOR_CAP 90

// Stat id -> what the god and the magic user see it called.
var/global/list/arcane_bless_names = list(
	"force" = "damage",
	"armor" = "protection",
	"durability" = "durability",
	"speed" = "work speed",
)
// Sacrifice value needed for each tier, on top of the last.
var/global/list/arcane_bless_costs = list(50, 150, 400)

/obj/item
	var/arcane_bless_stat = null     // saved: the stat a blessing raises, or null
	var/arcane_bless_tier = 0        // saved: 1 to 3
	var/arcane_bless_base = null     // saved: the unblessed force (number) or armor (list)
	var/arcane_blesser = null        // saved: ckey of the magic user who last raised it

/mob/living/human
	var/tmp/arcane_bless_pick = null // the stat of the Bless being asked for

// ---- What a blessing can raise --------------------------------------------

/proc/arcane_bless_stats(obj/item/I)
	. = list()
	if (!istype(I) || QDELETED(I) || istype(I, /obj/item/stack) || I.magic_repo_id)
		return
	if (I.arcane_bless_stat)
		. += I.arcane_bless_stat
		return
	if (istype(I, /obj/item/weapon) && !istype(I, /obj/item/weapon/gun) && I.force > 0)
		. += "force"
	if (islist(I.armor))
		for (var/key in I.armor)
			if (isnum(I.armor[key]) && I.armor[key] > 0)
				. += "armor"
				break
	if (isnum(I.maxhealth) && I.maxhealth > 0)
		. += "durability"
	var/obj/item/weapon/material/M = I
	if ((istype(M) && M.chopping_speed > 0) || (("usespeed" in I.vars) && isnum(I.vars["usespeed"]) && I.vars["usespeed"] > 0))
		. += "speed"

// Work goes this much faster with a tool blessed for speed (work_speed.dm).
/proc/arcane_bless_speed(obj/item/tool)
	if (!isitem(tool) || tool.arcane_bless_stat != "speed")
		return 1
	return 1 + 0.08 * clamp(tool.arcane_bless_tier, 0, ARCANE_BLESS_MAX)

/obj/item/proc/arcane_bless_raise(stat, tier)
	switch (stat)
		if ("force")
			if (!isnum(arcane_bless_base))
				arcane_bless_base = force
			force = round(arcane_bless_base * (1 + 0.05 * tier), 0.1)
		if ("armor")
			if (!islist(arcane_bless_base))
				arcane_bless_base = armor.Copy()
			var/list/base = arcane_bless_base
			var/list/raised = base.Copy()
			for (var/key in base)
				if (isnum(base[key]) && base[key] > 0)
					raised[key] = max(base[key], min(ARCANE_ARMOR_CAP, base[key] + 3 * tier))
			armor = raised
		if ("durability")
			var/step = (1 + 0.2 * tier) / (1 + 0.2 * (tier - 1))
			maxhealth = round(maxhealth * step, 1)
			if (isnum(health))
				health = round(health * step, 1)
	arcane_bless_stat = stat
	arcane_bless_tier = tier

/obj/item/proc/arcane_bless_end()
	switch (arcane_bless_stat)
		if ("force")
			if (isnum(arcane_bless_base))
				force = arcane_bless_base
		if ("armor")
			if (islist(arcane_bless_base))
				var/list/base = arcane_bless_base
				armor = base.Copy()
		if ("durability")
			var/step = 1 + 0.2 * arcane_bless_tier
			maxhealth = max(1, round(maxhealth / step, 1))
			if (isnum(health))
				health = min(maxhealth, round(health / step, 1))
	arcane_bless_stat = null
	arcane_bless_tier = 0
	arcane_bless_base = null
	arcane_blesser = null

// One plain line for a magic user; called from arcane_examine().
/obj/item/proc/arcane_bless_examine(mob/living/human/H)
	if (arcane_bless_tier > 0)
		to_chat(H, SPAN_NOTICE("<i>It feels favoured.</i>"))

// ---- The sacrifice ---------------------------------------------------------

// What a sacrifice is worth: 1 to 25 for ordinary goods by their value,
// 25 per strength for an attuned material, doubled for the same kind of thing.
/proc/arcane_sacrifice_value(obj/item/S, obj/item/blessed, stat)
	var/worth = S.arcane_virtue() ? 25 * S.arcane_strength : clamp(round(S.value / 4), 1, 25)
	var/same = FALSE
	switch (stat)
		if ("force")
			same = istype(S, /obj/item/weapon) && S.force > 0
		if ("armor")
			same = "armor" in arcane_bless_stats(S)
		else
			same = S.type == blessed.type
	return same ? worth * 2 : worth

// The altar of this character's god beside them with the best standing.
/mob/living/human/proc/arcane_bless_altar()
	var/god = divine_book_key(divine_patron)
	var/obj/best = null
	for (var/obj/O in arcane_altar_beside())
		if (O.arcane_altar_live() == god && (!best || O.arcane_altar_standing() > best.arcane_altar_standing()))
			best = O
	return best

// Highest blessing tier an altar of this standing allows (New and Kept: 1).
/proc/arcane_bless_ceiling(obj/altar)
	var/standing = altar ? altar.arcane_altar_standing() : -1
	if (standing < 0)
		return 0
	return max(1, standing)

// The goods on the altar a Bless would use up, or null if they are not enough.
/mob/living/human/proc/arcane_bless_sacrifice(obj/item/I, stat)
	var/obj/altar = arcane_bless_altar()
	if (!altar || !istype(I))
		return null
	var/needed = arcane_bless_costs[clamp(I.arcane_bless_tier + 1, 1, ARCANE_BLESS_MAX)]
	var/list/picked = list()
	for (var/obj/item/S in altar.loc)
		if (needed <= 0)
			break
		if (S == I || S.anchored || QDELETED(S) || S.magic_repo_id)
			continue
		picked += S
		needed -= arcane_sacrifice_value(S, I, stat)
	return needed <= 0 ? picked : null

/mob/living/human/proc/arcane_bless_problem(stat)
	var/obj/item/I = arcane_imbue_item()
	if (!I)
		return "Hold the thing in your other hand."
	var/obj/altar = arcane_bless_altar()
	if (!altar)
		return "Stand at an altar of your god."
	if (!stat)
		return null
	if (!(stat in arcane_bless_stats(I)))
		return "[I] can't be favoured like that."
	if (I.arcane_bless_tier >= min(ARCANE_BLESS_MAX, arcane_bless_ceiling(altar)))
		return "This altar can do no more for [I]."
	if (!arcane_bless_sacrifice(I, stat))
		return "What lies on the altar is not enough."
	return null

/proc/arcane_bless_scope(obj/item/I, stat, list/sacrifice)
	var/list/names = list()
	var/worth = 0
	for (var/obj/item/S in sacrifice)
		names += S.name
		worth += arcane_sacrifice_value(S, I, stat)
	return "bless-v1: raise the [arcane_bless_names[stat]] of [I.name] to tier [I.arcane_bless_tier + 1]; sacrifices [english_list(names)] (worth [worth] of [arcane_bless_costs[I.arcane_bless_tier + 1]]); costs the slot"

// Asked in Beseech before the prayer goes up. Returns the scope, or null.
/mob/living/human/proc/arcane_bless_choose()
	arcane_bless_pick = null
	var/problem = arcane_bless_problem(null)
	if (problem)
		to_chat(src, SPAN_WARNING(problem))
		return null
	var/obj/item/I = arcane_imbue_item()
	var/list/choices = list()
	for (var/stat in arcane_bless_stats(I))
		choices[arcane_bless_names[stat]] = stat
	if (!choices.len)
		to_chat(src, SPAN_WARNING("[I] has nothing to favour."))
		return null
	var/stat = choices[1]
	if (choices.len > 1)
		stat = choices[player_input(src, "What do you ask to favour in [I]?", "Bless", null, "anything", choices, TRUE)]
	else
		stat = choices[stat]
	if (!stat || QDELETED(I) || I != arcane_imbue_item())
		return null
	problem = arcane_bless_problem(stat)
	if (problem)
		to_chat(src, SPAN_WARNING(problem))
		return null
	arcane_bless_pick = stat
	return arcane_bless_scope(I, stat, arcane_bless_sacrifice(I, stat))

// On Grant, from divine_dispatch() after every recheck, with no yield.
/mob/living/human/proc/arcane_bless_apply(obj/item/I)
	var/stat = arcane_bless_pick
	arcane_bless_pick = null
	var/obj/altar = arcane_bless_altar()
	var/list/sacrifice = arcane_bless_sacrifice(I, stat)
	if (!istype(I) || !altar || !sacrifice)
		return FALSE
	var/list/names = list()
	for (var/obj/item/S in sacrifice)
		names += "[S] ([S.type])"
		qdel(S)
	var/tier = I.arcane_bless_tier + 1
	I.arcane_bless_raise(stat, tier)
	I.arcane_blesser = ckey
	altar.arcane_altar_worship(src)
	log_admin("Blessing: [key_name(src)] raised the [stat] of [I] ([I.type]) to tier [tier], sacrificing [english_list(names)].")
	to_chat(src, SPAN_NOTICE("<i>What you laid down is gone. [I] feels favoured.</i>"))
	return TRUE

#undef ARCANE_BLESS_MAX
#undef ARCANE_ARMOR_CAP
