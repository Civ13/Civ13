// The shipyard office: the press that lays an aircraft carrier down. It
// stands on the shore like the submarine pen and is fed steel, glass and
// cable; the ship is laid down on the deep sea to the north-east of it, its
// box corner on the tile diagonally next to the office, bow to the heading
// the shipwright picks. Naval Aviation research gates it.

/obj/structure/car_workshop/shipyard
	name = "shipyard office"
	desc = "The drawing office and slipway press of a naval shipyard. Feed it steel, glass and cable. It lays an aircraft carrier down on the open deep sea to the north-east of this spot, with a level below for the hangar deck and open sky above for the island."
	icon_state = "workbench"

// The ships this office lays down. Each heading is its own entry so the
// wheel can be picked from the same menu as the ship.
var/global/list/shipyard_models = list(
	"Aircraft carrier, bow east" = list("type" = /datum/vessel/carrier, "heading" = EAST),
	"Aircraft carrier, bow north" = list("type" = /datum/vessel/carrier, "heading" = NORTH),
	"Aircraft carrier, bow west" = list("type" = /datum/vessel/carrier, "heading" = WEST),
	"Aircraft carrier, bow south" = list("type" = /datum/vessel/carrier, "heading" = SOUTH),
)

/obj/structure/car_workshop/shipyard/models()
	return shipyard_models

/obj/structure/car_workshop/shipyard/required_nodes()
	return list("naval_aviation")

/obj/structure/car_workshop/shipyard/model_size(model)
	return (model in models()) ? 1 : 0

/obj/structure/car_workshop/shipyard/costs(model)
	if (!(model in models()))
		return null
	return list("steel" = 400, "glass" = 20, "cable" = 40)

/obj/structure/car_workshop/shipyard/menu_text()
	return "Stored: [stock["steel"]] steel, [stock["glass"]] glass, [stock["cable"]] cable. An aircraft carrier costs 400 steel, 20 glass and 40 cable. It is laid down on the deep sea to the north-east of the office, 40 tiles long and 9 wide along the heading you pick, and leaves with empty bunkers."

/obj/structure/car_workshop/shipyard/assembled_message(model)
	return "Your aircraft carrier is laid down. Climb to the island by the ladder on the starboard side of the flight deck, pour diesel or petroleum into the bunker filling point on the hangar deck, then weigh anchor and ring down a speed at the wheel."

// The corner of the ship's box: the tile diagonally north-east of the office.
/obj/structure/car_workshop/shipyard/proc/corner()
	return isturf(loc) ? locate(x + 1, y + 1, z) : null

// A fresh unplaced ship of the model, for fit checks and laying down.
/obj/structure/car_workshop/shipyard/proc/new_vessel(model)
	var/list/spec = models()[model]
	if (!spec)
		return null
	var/path = spec["type"]
	return new path

// Whether the model's ship would fit at the corner; the reason it would not
// is returned through refusal (a list with one text entry) when given.
/obj/structure/car_workshop/shipyard/proc/vessel_fits(model, list/refusal)
	var/turf/origin = corner()
	var/list/spec = models()[model]
	if (!origin || !spec)
		return FALSE
	var/datum/vessel/V = new_vessel(model)
	. = V.fits(origin.x, origin.y, origin.z, spec["heading"])
	if (!. && islist(refusal))
		refusal += V.last_refusal
	qdel(V)

/obj/structure/car_workshop/shipyard/clear_footprint(model)
	return vessel_fits(model)

// Why an office on origin could never lay a ship down, or null. Any heading
// that fits will do; the refusal names the last heading's problem.
/obj/structure/car_workshop/shipyard/build_refusal(mob/living/human/H, turf/origin)
	if (!isturf(origin))
		return "The [name] must be built on the ground."
	var/list/missing = list()
	var/list/research = missing_research(H)
	if (research.len)
		missing += "[english_list(research)] research"
	var/fits = FALSE
	var/list/reasons = list()
	for (var/model in models())
		var/list/spec = models()[model]
		var/datum/vessel/V = new_vessel(model)
		var/turf/C = locate(origin.x + 1, origin.y + 1, origin.z)
		if (C && V.fits(C.x, C.y, C.z, spec["heading"]))
			fits = TRUE
		else
			reasons += "[lowertext(copytext(model, findtext(model, ", ") + 2))]: [V.last_refusal]"
		qdel(V)
		if (fits)
			break
	if (!fits)
		missing += "a box of open deep sea to the north-east of this spot, 40 tiles long and 9 wide for some heading, with a level below and open sky above ([jointext(reasons, "; ")])"
	if (!(locate(/obj/structure/cable) in range(1, origin)))
		missing += "a laid power cable on or next to this spot (laying down draws 20 power)"
	if (!missing.len)
		return null
	return "The [name] could not work here. Missing: [jointext(missing, "; ")]."

/obj/structure/car_workshop/shipyard/complete_assembly(model)
	var/list/spec = models()[model]
	if (!spec || !has_inputs(model))
		return null
	var/turf/origin = corner()
	if (!origin)
		return null
	var/result = carrier_lay_down(origin, spec["heading"])
	if (!istype(result, /datum/vessel))
		return null
	var/list/required = costs(model)
	for (var/key in required)
		stock[key] -= required[key]
	return result

// The office keeps no vehicles in a bay, so the key and service menu entries
// of the automobile workshop do not apply.
/obj/structure/car_workshop/shipyard/extra_options()
	return list()
