// Works vehicles (docs/craft-core.md "Works vehicles"): the automobile
// workshop also builds a truck, an armoured car, a tracked carrier and two
// tanks. They are built piece by piece only (vehicle_projects.dm), never in
// one go, from the same body layouts map vehicles use. Each spec is data:
// the layout, the footprint, what it costs, how much of the steel is the
// turret and gun, and the research it needs beyond the press's own.
//
// A works vehicle leaves with an empty tank, empty shell racks and no loose
// guns, ammunition or supplies: the layout's free extras are left out.

var/global/list/works_vehicle_specs = list(
	"Cargo truck" = list("path" = /obj/effects/premadevehicles/truck/daf, "size" = 4, "node" = null, "gun" = 0,
		"cost" = list("steel" = 80, "glass" = 8, "cloth" = 6, "cable" = 10, "wheels" = 4)),
	"Armoured car" = list("path" = /obj/effects/premadevehicles/apc/ba64, "size" = 3, "node" = "mechanized_war", "gun" = 0,
		"cost" = list("steel" = 120, "cloth" = 4, "cable" = 10, "wheels" = 4)),
	"Tracked carrier" = list("path" = /obj/effects/premadevehicles/apc/m113, "size" = 4, "node" = "mechanized_war", "gun" = 0,
		"cost" = list("steel" = 180, "cloth" = 6, "cable" = 12, "tracks" = 4)),
	"Light tank" = list("path" = /obj/effects/premadevehicles/tank/bt7, "size" = 4, "node" = "mechanized_war", "gun" = 70,
		"cost" = list("steel" = 220, "cloth" = 4, "cable" = 12, "tracks" = 4)),
	"Medium tank" = list("path" = /obj/effects/premadevehicles/tank/t34, "size" = 4, "node" = "mechanized_war", "gun" = 70,
		"cost" = list("steel" = 300, "cloth" = 6, "cable" = 14, "tracks" = 4)),
)

// Model -> layout for the works vehicles this press builds.
/obj/structure/car_workshop/proc/works_models()
	. = list()
	for (var/model in works_vehicle_specs)
		var/list/spec = works_vehicle_specs[model]
		.[model] = spec["path"]

// The spec of a works vehicle this press builds, or null for its other models.
/obj/structure/car_workshop/proc/works_spec(model)
	var/list/spec = works_vehicle_specs[model]
	if (!spec)
		return null
	var/list/choices = models()
	return choices[model] == spec["path"] ? spec : null

// TRUE when the press assembles model in one go from its stock.
/obj/structure/car_workshop/proc/one_go(model)
	return (model in models()) && !works_spec(model)

// Display names of the research model needs beyond the press's own that H
// has not finished.
/obj/structure/car_workshop/proc/model_missing_research(mob/living/human/H, model)
	. = list()
	var/list/spec = works_spec(model)
	if (!spec || !spec["node"])
		return
	if (!H || !map || !research_node_known(H, spec["node"]))
		var/datum/research_node/N = get_research_node(spec["node"])
		. += N ? N.name : spec["node"]

// What a layout part becomes when the press builds it, or null to leave it
// out: tanks leave empty, items other than the tank are never made, and the
// free guns, shells, supplies and radios of map vehicles stay behind.
/proc/workshop_layout_part(partpath)
	if (ispath(partpath, /obj/item/weapon/reagent_containers/glass/barrel/fueltank))
		return ispath(partpath, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/smalltank) ? /obj/item/weapon/reagent_containers/glass/barrel/fueltank/smalltank : /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank
	if (ispath(partpath, /obj/item))
		return null
	if (ispath(partpath, /obj/structure/shellrack))
		return /obj/structure/shellrack
	if (ispath(partpath, /obj/structure/supply_crate) || ispath(partpath, /obj/structure/bed/chair/mgunner) || ispath(partpath, /obj/structure/radio))
		return null
	return partpath

// How many columns wide a layout is.
/proc/workshop_layout_width(obj/effects/premadevehicles/B)
	. = 0
	for (var/coords in B.tocreate)
		var/list/parts = B.tocreate[coords]
		if (!islist(parts) || !parts.len)
			continue
		var/list/C = splittext(coords, ",")
		. = max(., text2num(C[1]))

// Which piece-project material a loose wheel or track pays as, or null.
/proc/workshop_wheel_key(atom/movable/W)
	if (W.type == /obj/structure/vehicleparts/movement)
		return "wheels"
	if (W.type == /obj/structure/vehicleparts/movement/tracks)
		return "tracks"
	return null
