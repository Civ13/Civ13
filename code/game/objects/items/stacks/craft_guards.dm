// Build guards for stack recipes.
//
// A feature that limits who may craft one of its products, or where, declares
// a /datum/craft_guard subtype next to its own code instead of adding another
// check to produce_recipe(). Guards run in `order`, lowest first, and the first
// refusal stops the build.
//
// Phases (code/__defines/craft.dm):
// - CRAFT_GUARD_START: the build is about to start (before payment or the wait).
// - CRAFT_GUARD_FINISH: the build wait is over; guards with after_wait recheck
//   because the builder may have moved, turned or lost a skill meanwhile.
// - CRAFT_GUARD_MENU: recipe_makeable_now() hides recipes whose hides_recipe
//   guard refuses. Where the player stands is never judged in the menu.
//
// refusal() returns null to allow. To refuse it returns the message to show, or
// "" to refuse silently.

/datum/craft_guard
	var/order = 100
	var/after_wait = FALSE
	var/hides_recipe = FALSE

/datum/craft_guard/proc/refusal(mob/living/human/H, datum/stack_recipe/R, phase)
	return null

var/global/list/craft_guards = null

/proc/craft_guard_list()
	if (!craft_guards)
		var/list/guards = list()
		for (var/path in subtypesof(/datum/craft_guard))
			var/datum/craft_guard/G = new path
			var/at = guards.len + 1
			for (var/i = 1, i <= guards.len, i++)
				var/datum/craft_guard/other = guards[i]
				if (G.order < other.order)
					at = i
					break
			guards.Insert(at, G)
		craft_guards = guards
	return craft_guards

// The first refusal for this recipe and phase, or null when every guard allows it.
/proc/craft_guard_refusal(mob/living/human/H, datum/stack_recipe/R, phase)
	if (!R)
		return null
	for (var/datum/craft_guard/G in craft_guard_list())
		if (phase == CRAFT_GUARD_FINISH && !G.after_wait)
			continue
		if (phase == CRAFT_GUARD_MENU && !G.hides_recipe)
			continue
		var/message = G.refusal(H, R, phase)
		if (!isnull(message))
			return message
	return null

// Gates that need an era, research and crafting skill. They hide the recipe in
// the menu, refuse with a message at the start and refuse silently after the wait.
/datum/craft_guard/skill_gate
	after_wait = TRUE
	hides_recipe = TRUE
	var/message = ""

/datum/craft_guard/skill_gate/proc/allowed(mob/living/human/H, result_type)
	return TRUE

/datum/craft_guard/skill_gate/refusal(mob/living/human/H, datum/stack_recipe/R, phase)
	if (allowed(H, R.result_type))
		return null
	return phase == CRAFT_GUARD_START ? message : ""

// Standing over deep water is not enough: the builder needs a real deck.
/datum/craft_guard/deep_water
	order = 80
	after_wait = TRUE

/datum/craft_guard/deep_water/refusal(mob/living/human/H, datum/stack_recipe/R, phase)
	var/turf/T = get_turf(H)
	if (!istype(T, /turf/floor/beach/water/deep) || map.ID == MAP_VOYAGE || map.ID == MAP_BATTLE_SHIPS)
		return null
	if (bridge_deck_at(T) || vessel_building_deck_at(T))
		return null
	return "<span class = 'danger'>You can't build here!</span>"

// Not iscovered(): rafts, ladders and unattached ship parts keep swimmers up
// but cannot carry construction. A built hull's footprint also includes holes.
/proc/vessel_building_deck_at(turf/T)
	var/datum/hull_ledger/L = hull_ledger_at(T)
	if (!QDELETED(L) && !L.sinking)
		for (var/obj/covers/C in T)
			if (hull_floor_plank(C, T))
				return TRUE
	for (var/obj/structure/vehicleparts/frame/ship/F in T)
		if (F.loc != T || F.broken || QDELETED(F))
			continue
		var/obj/structure/vehicleparts/axis/ship/A = F.axis
		var/turf/helm = get_turf(A)
		if (istype(A) && !QDELETED(A) && helm && helm.z == T.z && get_dist(helm, T) <= 7 && (F in A.components))
			return TRUE
	return FALSE

// Religious works: the first entry whose title words match decides. Builders
// without a religion, or whose religion type is listed, cannot make the work.
var/global/list/religious_work_rules = list(
	list(list("talisman"), list("Priests", "Monks", "Clerics")),
	list(list("totem"), list("Priests", "Monks", "Clerics", "Cultists")),
	list(list("monumental ominous statue of the deep-one", "monumental ominous statue of the evil-one", "monumental ominous statue of the outsider", "monumental ominous statue of the ruler"), list("Shamans", "Priests", "Monks", "Clerics")),
	list(list("monumental stone buddha"), list("Shamans", "Priests", "Cultists", "Clerics")),
	list(list("monumental statue of a giant ape"), list("Monks", "Priests", "Cultists", "Clerics")),
)

/proc/religious_work_rule(title)
	for (var/list/rule in religious_work_rules)
		for (var/word in rule[1])
			if (findtext(title, word))
				return rule
	return null

/datum/craft_guard/religious_work
	order = 90

/datum/craft_guard/religious_work/refusal(mob/living/human/H, datum/stack_recipe/R, phase)
	var/list/rule = religious_work_rule(R.title)
	if (!rule)
		return null
	if (H.religion == "none")
		return "<span class = 'danger'>You cannot make a [R.title] as you have no religion.</span>"
	if (H.religion in rule[2])
		return "<span class = 'danger'>You cannot make a [R.title]; your religion type doesn't allow this.</span>"
	return null

// Gorilla and ant tribesmen cannot make some wooden weapons, walls and doors.
// Religious works are judged by their own rule only.
/datum/craft_guard/tribe_knowledge
	order = 100

/datum/craft_guard/tribe_knowledge/refusal(mob/living/human/H, datum/stack_recipe/R, phase)
	if (religious_work_rule(R.title))
		return null
	if (H.original_job_title != "Gorilla tribesman" && H.original_job_title != "Ant tribesman")
		return null
	if (findtext(R.title, "wood sarissa") || findtext(R.title, "wood dory") || findtext(R.title, "soft wood wall") || findtext(R.title, "log wall"))
		return "<span class = 'danger'>You don't know how to make this.</span>"
	if (R.result_type == /obj/structure/simple_door/key_door/anyone/wood)
		return "<span class = 'danger'>You don't know how to make this.</span>"
	if (H.original_job_title == "Ant tribesman" && (findtext(R.title, "wall") || findtext(R.title, "door")))
		return "<span class = 'danger'>You don't know how to make this.</span>"
	return null

// One requirement line for a crafting screen: list("kind", "label", "met").
// The default reports only an unmet guard, read from refusal() at the start
// phase without building anything; a guard may override to also list a met one.
/datum/craft_guard/proc/describe(mob/living/human/H, datum/stack_recipe/R)
	var/message = refusal(H, R, CRAFT_GUARD_START)
	if (isnull(message))
		return null
	var/label = strip_html_properly(message)
	return list("kind" = "[type]", "label" = label ? label : "Not available to you here.", "met" = FALSE)

// Every requirement the guards report for this recipe. Nothing is spent or built.
/proc/craft_recipe_requirements(mob/living/human/H, datum/stack_recipe/R)
	var/list/found = list()
	if (!R)
		return found
	for (var/datum/craft_guard/G in craft_guard_list())
		for (var/list/line in G.describe_lines(H, R))
			found[++found.len] = line
	return found

// Every line a guard reports. A guard with several requirements overrides this.
/datum/craft_guard/proc/describe_lines(mob/living/human/H, datum/stack_recipe/R)
	var/list/line = describe(H, R)
	return line ? list(line) : null
