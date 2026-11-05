// Food toxin log. Every toxin a human swallows (food bites, drinks, utensils,
// smoke) and every raw-food poisoning roll is recorded with the source item,
// the amounts and the recorded cause. Lines go to the game log (FOOD), the
// eater's attack log (admin player panel) and a bounded ring that admins read
// with view variables and agents read with the logs action (kind "food").
// Only swallows that actually carry a toxin are logged, so clean meals add
// nothing.

#define FOOD_TOXIN_LOG_LIMIT 200
#define FOOD_TOXIN_ORIGIN_LIMIT 200

var/global/list/food_toxin_log = list()

// Why an object carries toxins, as short plain text. Food that spawns with a
// toxin sets it as a type default; contamination sites and transfers add to it.
// It only matters while the object actually holds a toxin.
/obj/var/food_toxin_origin = null

/obj/proc/note_food_toxin(cause)
	if (!cause)
		return
	if (!food_toxin_origin)
		food_toxin_origin = copytext("[cause]", 1, FOOD_TOXIN_ORIGIN_LIMIT)
	else if (!findtext(food_toxin_origin, cause))
		food_toxin_origin = copytext("[food_toxin_origin]; [cause]", 1, FOOD_TOXIN_ORIGIN_LIMIT)

/proc/food_toxin_amounts(datum/reagents/R)
	. = list()
	if (!R)
		return
	for (var/datum/reagent/toxin/T in R.reagent_list)
		if (T.volume > 0)
			.[T.id] = T.volume

// With known_only, returns null instead of a placeholder when nothing is recorded.
/proc/food_toxin_cause(atom/A, known_only = FALSE)
	if (!isobj(A))
		return known_only ? null : "origin not recorded"
	var/obj/O = A
	var/list/causes = list()
	if (O.food_toxin_origin)
		causes += O.food_toxin_origin
	if (istype(O, /obj/item/weapon/reagent_containers/food))
		var/obj/item/weapon/reagent_containers/food/F = O
		if (F.rotten && !findtext("[O.food_toxin_origin]", "rot"))
			causes += "rotten"
		if (F.raw && !findtext("[O.food_toxin_origin]", "raw"))
			causes += "raw"
	if (!causes.len)
		if (known_only)
			return null
		return "origin not recorded (mixed in from another container or ingredient)"
	return jointext(causes, "; ")

/proc/food_toxin_text(list/amounts)
	var/list/parts = list()
	for (var/id in amounts)
		parts += "[id] [round(amounts[id], 0.01)]u"
	return jointext(parts, ", ")

/proc/log_food_toxin(mob/living/M, atom/source, list/amounts, cause, via)
	if (!istype(M) || !length(amounts))
		return
	var/source_text = source ? "[source.name] ([source.type])" : "unknown source"
	var/turf/T = get_turf(M)
	var/where = T ? " at ([T.x],[T.y],[T.z])" : ""
	var/list/held = food_toxin_amounts(M.reagents)
	if (ishuman(M))
		var/mob/living/human/H = M
		var/list/stomach = food_toxin_amounts(H.ingested)
		for (var/id in stomach)
			held[id] = (held[id] || 0) + stomach[id]
	var/line = "[key_name(M)] swallowed [food_toxin_text(amounts)] from [source_text] via [via][where]. Cause: [cause]. Now holds [held.len ? food_toxin_text(held) : "no toxins"], toxin damage [round(M.getToxLoss(), 0.1)]."
	game_log("FOOD", line)
	M.append_attack_log("\[[time_stamp()]\] <font color='orange'>Food toxin: [food_toxin_text(amounts)] from [source_text] via [via]. Cause: [cause].</font>")
	food_toxin_log += "\[[time_stamp()]\] [line]"
	if (food_toxin_log.len > FOOD_TOXIN_LOG_LIMIT)
		food_toxin_log.Cut(1, food_toxin_log.len - FOOD_TOXIN_LOG_LIMIT + 1)

#undef FOOD_TOXIN_LOG_LIMIT
#undef FOOD_TOXIN_ORIGIN_LIMIT
