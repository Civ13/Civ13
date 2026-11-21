// ============================================================
// Enchantments (magic materials and enchanting plan, PR 4). Hidden mechanic:
// keep it out of changelog lines, the wiki and the public Crafting Atlas.
// ------------------------------------------------------------
// A magic user taught Imbue beseeches with an ordinary item in the hand that
// is not holding their stick and the needed attuned materials (and a gem, for
// a keepsake) in a worn pouch. The god sees a fixed, server-made scope line and
// grants or refuses it like any invocation. On Grant the materials are used up
// and the item gets hidden saved fields: the enchantment, its charges, its
// maker and when it was made. The item's type, name, sprite and description do
// not change. Charges never refill; imbuing again replaces the old enchantment.
// Destroying, melting or recrafting the item ends it with the item.
//
// The same invocation can unweave anyone's enchantment from the held item for
// one attuned material of any aspect. Each magic user keeps at most
// ARCANE_ENCHANT_CAP of their own enchantments in this world; a sixth asks
// which to let go. Staff list and strip enchantments in Divine Patron, and
// every imbue, use, unweave and strip goes to the admin log.
// ============================================================

#define ARCANE_ENCHANT_CAP 5

// Enchantment id -> what the god and the magic user see it called.
var/global/list/arcane_enchant_names = list(
	"keepsake" = "Keepsake",
	"cleansing" = "Cleansing",
)

// Enchantment id -> materials and charges by strength 1 / 2 / 3.
var/global/list/arcane_enchant_recipes = list(
	"keepsake" = list("aspect" = "mercy", "count" = 2, "gem" = 1, "charges" = list(1, 2, 3)),
	"cleansing" = list("aspect" = "mercy", "count" = 1, "gem" = 0, "charges" = list(3, 5, 8)),
)

// Enchantment id -> the one plain line a magic user sees on examine.
var/global/list/arcane_enchant_lines = list(
	"keepsake" = "Something about it feels watchful.",
	"cleansing" = "It seems cleaner than it ought to.",
)

// Enchanted items in this world. Runtime only: rebuilt as items load, and an
// item leaves it when it is destroyed or its enchantment ends.
var/global/list/arcane_enchanted = list()

/obj/item
	var/arcane_enchant = null       // saved: enchantment id, or null
	var/arcane_charges = 0          // saved: uses left
	var/arcane_enchanter = null     // saved: ckey of the magic user who made it
	var/arcane_enchanted_at = 0     // saved: world.realtime when it was made

/mob/living/human
	var/tmp/arcane_imbue_pick = null  // enchantment id (or "unweave") of the Imbue being asked for
	var/tmp/arcane_was_critical = FALSE

// ---- The enchantment on an item ------------------------------------------

/obj/item/proc/arcane_enchant_live()
	if (!arcane_enchant)
		return null
	if (!arcane_enchant_names[arcane_enchant] || arcane_charges < 1)
		arcane_enchant_end()
		return null
	return arcane_enchant

/obj/item/proc/arcane_enchant_end()
	arcane_enchant = null
	arcane_charges = 0
	arcane_enchanter = null
	arcane_enchanted_at = 0
	arcane_enchanted -= src

// Called from /obj/item/after_load (abandoned_items.dm).
/obj/item/proc/arcane_enchant_loaded()
	if (arcane_enchant_live())
		arcane_enchanted |= src

// Called from /obj/item/Destroy (items.dm).
/obj/item/proc/arcane_enchant_forget()
	if (arcane_enchant)
		arcane_enchanted -= src

// Uses one charge; the enchantment ends with the last one.
/obj/item/proc/arcane_enchant_spend(why)
	var/kind = arcane_enchant_live()
	if (!kind)
		return FALSE
	arcane_charges--
	log_admin("Enchantment used: [kind] on [src] ([type]) made by [arcane_enchanter], [arcane_charges] left ([why]).")
	if (arcane_charges < 1)
		arcane_enchant_end()
	return TRUE

/proc/arcane_enchantments_of(ckey)
	. = list()
	for (var/obj/item/I in arcane_enchanted)
		if (QDELETED(I) || !I.arcane_enchant_live())
			arcane_enchanted -= I
		else if (I.arcane_enchanter == ckey)
			. += I

/proc/arcane_enchant_place(obj/item/I)
	var/turf/T = get_turf(I)
	var/area/A = T ? T.loc : null
	return T ? "[A ? A.name : "somewhere"] ([T.x], [T.y], [T.z])" : "nowhere"

// ---- What can be imbued ---------------------------------------------------

/proc/arcane_is_trinket(obj/item/I)
	if (istype(I, /obj/item/clothing/gloves/rings) || istype(I, /obj/item/clothing/accessory/storage/lanyard))
		return TRUE
	return istype(I, /obj/item/clothing/accessory) && !istype(I, /obj/item/clothing/accessory/storage)

/proc/arcane_enchant_fits(kind, obj/item/I)
	if (!istype(I) || QDELETED(I) || I.magic_repo_id || istype(I, /obj/item/stack))
		return FALSE
	switch (kind)
		if ("keepsake")
			return arcane_is_trinket(I)
		if ("cleansing")
			var/obj/item/weapon/reagent_containers/RG = I
			return (istype(RG, /obj/item/weapon/reagent_containers/glass) || istype(RG, /obj/item/weapon/reagent_containers/food/drinks)) && RG.reagents && RG.reagents.has_reagent("water")
	return FALSE

/proc/arcane_is_gem(obj/item/I)
	return istype(I, /obj/item/stack/ore/gem) || istype(I, /obj/item/stack/gemstone)

// The item an Imbue works on: whatever is in the hand without the stick.
/mob/living/human/proc/arcane_imbue_item()
	var/obj/item/focus = divine_focus()
	if (!focus)
		return null
	var/obj/item/I = get_active_hand() == focus ? get_inactive_hand() : get_active_hand()
	return istype(I) && !QDELETED(I) ? I : null

// Everything kept in this character's worn belt pouches.
/mob/living/human/proc/arcane_pouch_items()
	. = list()
	for (var/obj/item/clothing/accessory/storage/belt_pouch/P in GetAllContents(4))
		if (!P.hold || QDELETED(P))
			continue
		for (var/obj/item/I in P.hold.contents)
			if (!QDELETED(I))
				. += I

// The pouch items an Imbue of this kind would use up, or null if any are
// missing. An attuned stack counts as one material and gives up one of itself.
/mob/living/human/proc/arcane_imbue_materials(kind)
	var/list/pouch = arcane_pouch_items()
	var/list/picked = list()
	if (kind == "unweave")
		for (var/obj/item/I in pouch)
			if (I.arcane_virtue())
				picked += I
				return picked
		return null
	var/list/recipe = arcane_enchant_recipes[kind]
	if (!recipe)
		return null
	var/needed = recipe["count"]
	for (var/obj/item/I in pouch)
		if (needed && I.arcane_virtue() == recipe["aspect"])
			picked += I
			needed--
	if (needed)
		return null
	var/gems = recipe["gem"]
	for (var/obj/item/I in pouch)
		if (gems && arcane_is_gem(I) && !(I in picked))
			picked += I
			gems--
	if (gems)
		return null
	return picked

/proc/arcane_imbue_strength(list/materials)
	var/total = 0
	var/count = 0
	for (var/obj/item/I in materials)
		if (I.arcane_virtue())
			total += I.arcane_strength
			count++
	return count ? clamp(round(total / count), 1, 3) : 1

/proc/arcane_imbue_charges(kind, list/materials)
	var/list/recipe = arcane_enchant_recipes[kind]
	if (!recipe)
		return 0
	var/list/charges = recipe["charges"]
	return charges[arcane_imbue_strength(materials)]

// Why the Imbue being asked for can't go ahead, or null. Called by divine_problem().
/mob/living/human/proc/arcane_imbue_problem(kind)
	var/obj/item/I = arcane_imbue_item()
	if (!I)
		return "Hold the thing in your other hand."
	if (!kind)
		return null
	if (kind == "unweave")
		if (!I.arcane_enchant_live())
			return "There is nothing woven into [I]."
	else if (!arcane_enchant_fits(kind, I))
		return "[I] can't hold that."
	if (!arcane_imbue_materials(kind))
		return "You don't have what that needs in your pouch."
	return null

/proc/arcane_imbue_scope(kind, obj/item/I, list/materials)
	var/list/names = list()
	for (var/obj/item/M in materials)
		names += M.arcane_virtue() ? "[M.name] ([M.arcane_virtue()] [M.arcane_strength])" : "[M.name]"
	if (kind == "unweave")
		return "unweave-v1: end the [I.arcane_enchant] enchantment ([I.arcane_charges] left, made by [I.arcane_enchanter]) on [I.name]; uses up [english_list(names)]; costs the slot"
	return "imbue-[kind]-v1: [arcane_enchant_names[kind]] on [I.name] with [arcane_imbue_charges(kind, materials)] charges; uses up [english_list(names)]; costs the slot"

// Asked in Beseech before the prayer goes up: which enchantment, and which
// old one to let go when this would be a sixth. Returns the scope, or null.
/mob/living/human/proc/arcane_imbue_choose()
	arcane_imbue_pick = null
	var/obj/item/I = arcane_imbue_item()
	if (!I)
		to_chat(src, SPAN_WARNING("Hold the thing in your other hand."))
		return null
	var/list/choices = list()
	for (var/kind in arcane_enchant_names)
		if (arcane_enchant_fits(kind, I))
			choices[arcane_enchant_names[kind]] = kind
	if (I.arcane_enchant_live())
		choices["Unweave what is in it"] = "unweave"
	if (!choices.len)
		to_chat(src, SPAN_WARNING("Nothing you know can be woven into [I]."))
		return null
	var/picked = player_input(src, "What do you ask to weave into [I]?", "Imbue", null, "anything", choices, TRUE)
	var/kind = choices[picked]
	if (!kind || QDELETED(I) || I != arcane_imbue_item())
		return null
	if (kind != "unweave")
		var/list/own = arcane_enchantments_of(ckey)
		own -= I // re-imbuing replaces, so it does not count twice
		if (own.len >= ARCANE_ENCHANT_CAP)
			var/list/release = list()
			for (var/obj/item/O in own)
				release["[O.name] ([arcane_enchant_names[O.arcane_enchant]], [arcane_enchant_place(O)])"] = O
			var/gone = player_input(src, "You can't hold more than [ARCANE_ENCHANT_CAP] in the world. Which do you let go?", "Imbue", null, "anything", release, TRUE)
			var/obj/item/O = release[gone]
			if (!O || QDELETED(O) || O.arcane_enchanter != ckey)
				return null
			log_admin("Enchantment let go: [key_name(src)] let go of [O.arcane_enchant] on [O] ([O.type]) to make room.")
			O.arcane_enchant_end()
	var/problem = arcane_imbue_problem(kind)
	if (problem)
		to_chat(src, SPAN_WARNING(problem))
		return null
	arcane_imbue_pick = kind
	return arcane_imbue_scope(kind, I, arcane_imbue_materials(kind))

// On Grant, from divine_dispatch() after every recheck: use up the materials
// and weave the enchantment in, with no yield.
/mob/living/human/proc/arcane_imbue_apply(obj/item/I)
	var/kind = arcane_imbue_pick
	arcane_imbue_pick = null
	var/list/materials = arcane_imbue_materials(kind)
	if (!istype(I) || !materials)
		return FALSE
	var/charges = kind == "unweave" ? 0 : arcane_imbue_charges(kind, materials)
	for (var/obj/item/M in materials)
		if (istype(M, /obj/item/stack))
			var/obj/item/stack/S = M
			if (S.amount > 1)
				S.use(1)
				continue
		var/obj/item/weapon/storage/holder = M.loc
		if (istype(holder))
			holder.remove_from_storage(M, get_turf(src))
		qdel(M)
	if (kind == "unweave")
		log_admin("Enchantment unwoven: [key_name(src)] unwove [I.arcane_enchant] made by [I.arcane_enchanter] from [I] ([I.type]).")
		I.arcane_enchant_end()
		to_chat(src, SPAN_NOTICE("<i>Something leaves [I].</i>"))
		return TRUE
	I.arcane_enchant_end()
	I.arcane_enchant = kind
	I.arcane_charges = charges
	I.arcane_enchanter = ckey
	I.arcane_enchanted_at = world.realtime
	arcane_enchanted |= I
	log_admin("Enchantment made: [key_name(src)] wove [kind] ([charges] charges) into [I] ([I.type]).")
	to_chat(src, SPAN_NOTICE("<i>[arcane_enchant_lines[kind]]</i>"))
	return TRUE

// One plain line for a magic user; called from arcane_examine().
/obj/item/proc/arcane_enchant_examine(mob/living/human/H)
	var/kind = arcane_enchant_live()
	if (kind && arcane_enchant_lines[kind])
		to_chat(H, SPAN_NOTICE("<i>[arcane_enchant_lines[kind]]</i>"))

// ---- What enchantments do -------------------------------------------------

// Keepsake: the first time the wearer drops into critical condition, it eases
// pain and stops their bleeding. Called every Life tick while alive.
/mob/living/human/proc/arcane_critical_check(critical)
	if (!critical)
		arcane_was_critical = FALSE
		return
	if (arcane_was_critical)
		return
	arcane_was_critical = TRUE
	var/obj/item/keepsake = arcane_worn_keepsake()
	if (!keepsake)
		return
	adjustHalLoss(-40)
	for (var/obj/item/organ/external/E in organs)
		E.bandage()
	keepsake.arcane_enchant_spend("kept [key_name(src)] from bleeding out")

/mob/living/human/proc/arcane_worn_keepsake()
	for (var/obj/item/I in get_equipped_items())
		if (I.arcane_enchant == "keepsake" && I.arcane_enchant_live())
			return I
		var/obj/item/clothing/C = I
		if (istype(C) && islist(C.accessories))
			for (var/obj/item/A in C.accessories)
				if (A.arcane_enchant == "keepsake" && A.arcane_enchant_live())
					return A
	return null

// Cleansing: pouring from the bottle into water rids that water of sickness.
// Called from standard_pour_into() after a pour.
/obj/item/proc/arcane_cleansing_pour(atom/target)
	if (arcane_enchant != "cleansing" || !arcane_enchant_live() || !target || !target.reagents || !target.reagents.has_reagent("water"))
		return FALSE
	target.reagents.del_reagent("cholera")
	return arcane_enchant_spend("cleansed [target] ([target.type])")

#undef ARCANE_ENCHANT_CAP
