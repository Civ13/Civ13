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
	if (bridge_deck_at(T))
		return null
	var/list/deck = vessel_building_deck_at(H)
	if (deck)
		// Frames carry structures and items, not floor or wall covers.
		if (istype(deck[1], /obj/structure/vehicleparts/frame/ship) && ispath(R.result_type, /obj/covers))
			return SPAN_WARNING("This ship frame cannot carry that floor or wall.")
		if (ispath(R.result_type, /obj/structure) && !ship_same_tile_fixture(R.result_type))
			return SPAN_WARNING("This fixture needs its own placement site off the ship.")
		return null
	return "<span class = 'danger'>You can't build here!</span>"

// Find the filed deck tile beneath H's drawn centre. A known rider uses
// the same inverse offset as walking; a scenery cover never grants footing.
/proc/vessel_building_deck_at(mob/living/human/H)
	if (!isturf(H?.loc))
		return null
	var/datum/vehicle_offset/rider = vehicle_offset_riders[H]
	var/turf/T = (istype(rider, /datum/vehicle_offset/hull) || istype(rider, /datum/vehicle_offset/axis)) ? vehicle_offset_turf_under(H, rider.ox, rider.oy) : H.loc
	return vessel_building_deck_on(T, H)

// A non-rider query finds a fixture's filed supporting tile.
/proc/vessel_building_deck_on(turf/T, mob/living/human/H = null)
	if (!T)
		return null
	var/datum/hull_ledger/L = hull_ledger_at(T)
	if (!QDELETED(L) && !L.sinking)
		var/datum/vehicle_offset/hull/mover = L.craft.offset_mover
		if (!H || !mover || vehicle_offset_turf_under(H, mover.ox, mover.oy) == T)
			for (var/obj/covers/C in T)
				if (hull_floor_plank(C, T))
					return list(C, L)
	for (var/obj/structure/vehicleparts/frame/ship/F in T)
		if (F.loc != T || F.broken || QDELETED(F))
			continue
		var/obj/structure/vehicleparts/axis/ship/A = F.axis
		var/turf/helm = get_turf(A)
		if (istype(A) && !QDELETED(A) && helm && helm.z == T.z && get_dist(helm, T) <= 7 && (F in A.components))
			var/datum/vehicle_offset/axis/mover = A.offset_mover
			if (!H || !mover || vehicle_offset_turf_under(H, mover.ox, mover.oy) == T)
				return list(F, A)
	return null

// Fixtures with their own final target must not use the builder's deck.
/proc/ship_same_tile_fixture(path)
	if (ispath(path, /obj/structure/civ_generator/waterwheel) || ispath(path, /obj/structure/noticeboard) || ispath(path, /obj/structure/mirror) || ispath(path, /obj/structure/cannon/modern/tank))
		return FALSE
	if (ispath(path, /obj/structure/closet/crate/wall_mailbox) && !ispath(path, /obj/structure/closet/crate/wall_mailbox/wood_mailbox))
		return FALSE
	return !ispath(path, /obj/structure/sign) || ispath(path, /obj/structure/sign/signpost)

// An opt-in construction action may ride its original deck, but must not walk
// across it or switch decks. A fixture action also binds its exact workpiece.
/datum/ship_construction
	var/atom/movable/support
	var/datum/deck_owner
	var/relative_x
	var/relative_y
	var/heading
	var/atom/movable/workpiece
	var/atom/movable/workpiece_support
	var/workpiece_x
	var/workpiece_y

/datum/ship_construction/New(mob/living/human/H, list/deck)
	..()
	// The load-construction sweep creates each datum with no arguments.
	// Such a context must remain inert until explicitly built with a live deck.
	if (!istype(H) || QDELETED(H) || !islist(deck) || deck.len < 2)
		return
	var/atom/movable/plank = deck[1]
	var/datum/owner = deck[2]
	if (!istype(plank) || QDELETED(plank) || !isturf(plank.loc))
		return
	if ((!istype(owner, /datum/hull_ledger) && !istype(owner, /obj/structure/vehicleparts/axis/ship)) || QDELETED(owner))
		return
	support = plank
	deck_owner = owner
	var/datum/vehicle_offset/M = mover()
	relative_x = (H.x - support.x) * world.icon_size + H.step_x - (M ? M.ox : 0)
	relative_y = (H.y - support.y) * world.icon_size + H.step_y - (M ? M.oy : 0)
	heading = deck_heading()

/datum/ship_construction/proc/mover()
	var/datum/hull_ledger/L = deck_owner
	if (istype(L) && !QDELETED(L))
		return L.craft?.offset_mover
	var/obj/structure/vehicleparts/axis/ship/A = deck_owner
	if (istype(A) && !QDELETED(A))
		return A.offset_mover
	return null

/datum/ship_construction/proc/deck_heading()
	var/datum/hull_ledger/L = deck_owner
	if (istype(L) && !QDELETED(L))
		return L.craft?.body?.heading()
	var/obj/structure/vehicleparts/axis/ship/A = deck_owner
	if (istype(A) && !QDELETED(A))
		return A.dir
	return null

/datum/ship_construction/proc/stationary(mob/living/human/H)
	// Compare positions in the original plank's coordinate space. A whole
	// tile crossing changes both world coordinates and wraps the offset.
	if (QDELETED(support) || !isturf(support.loc) || !isturf(H?.loc) || H.z != support.z || !heading || deck_heading() != heading)
		return FALSE
	var/datum/vehicle_offset/M = mover()
	if ((H.x - support.x) * world.icon_size + H.step_x - (M ? M.ox : 0) != relative_x)
		return FALSE
	return (H.y - support.y) * world.icon_size + H.step_y - (M ? M.oy : 0) == relative_y

/datum/ship_construction/proc/target(mob/living/human/H)
	if (!stationary(H))
		return null
	var/list/deck = vessel_building_deck_at(H)
	if (!deck || deck[1] != support || deck[2] != deck_owner)
		return null
	return support.loc

// Match a structure's original live supporting plank/frame on the same ship.
// This supports both the actor's tile and an adjacent fixture clicked normally.
/datum/ship_construction/proc/bind_fixture(obj/structure/fixture)
	if (QDELETED(support) || QDELETED(fixture) || !isturf(fixture.loc) || fixture.craft_left_behind() || istype(fixture, /obj/structure/wild))
		return FALSE
	var/list/deck = vessel_building_deck_on(fixture.loc)
	if (!deck || deck[2] != deck_owner || deck[1] == fixture)
		return FALSE
	var/datum/vehicle_offset/M = mover()
	if (M && vehicle_offset_turf_under(fixture, M.ox, M.oy) != fixture.loc)
		return FALSE
	workpiece = fixture
	workpiece_support = deck[1]
	workpiece_x = fixture.step_x - (M ? M.ox : 0)
	workpiece_y = fixture.step_y - (M ? M.oy : 0)
	return fixture_stationary(fixture)

/datum/ship_construction/proc/fixture_stationary(atom/fixture, confirm_deck = FALSE)
	if (fixture != workpiece || QDELETED(workpiece) || QDELETED(workpiece_support) || !isturf(workpiece_support.loc) || workpiece.loc != workpiece_support.loc)
		return FALSE
	if (confirm_deck)
		var/list/deck = vessel_building_deck_on(workpiece_support.loc)
		if (!deck || deck[1] != workpiece_support || deck[2] != deck_owner)
			return FALSE
	var/datum/vehicle_offset/M = mover()
	var/datum/vehicle_offset/rider = vehicle_offset_riders[workpiece]
	if (rider && rider != M)
		return FALSE
	var/current_x = workpiece.step_x
	var/current_y = workpiece.step_y
	if (M)
		current_x -= M.ox
		current_y -= M.oy
	return current_x == workpiece_x && current_y == workpiece_y

// Only callers that commit to the live fixture can opt in. Any other
// target or actor keeps the original world-space wait and cancellation.
/proc/do_ship_fixture_after(mob/user, delay, obj/structure/fixture)
	var/mob/living/human/H = user
	var/list/deck = istype(H) ? vessel_building_deck_at(H) : null
	if (deck)
		var/datum/ship_construction/action = new(H, deck)
		if (action.bind_fixture(fixture))
			return do_after(user, delay, fixture, ship_craft = action) && action.target(H) && action.fixture_stationary(fixture, TRUE)
	return do_after(user, delay, fixture)

/datum/ship_construction/proc/align(atom/movable/fixture)
	if (QDELETED(fixture) || fixture.loc != support.loc || fixture.craft_left_behind())
		return
	var/datum/vehicle_offset/M = mover()
	if (!M || !(M.ox || M.oy || M.carried.len))
		return
	var/is_cover = istype(fixture, /obj/covers)
	if (is_cover && !istype(M, /datum/vehicle_offset/hull))
		return
	// The result was placed square on the deck, not dropped into a world
	// pixel. Enroll it now so both next-pulse settlement and stops agree.
	M.carry_at(fixture, 0, 0, is_cover)
	M.draw_one(fixture)

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
