// Works vehicles (docs/craft-core.md "Works vehicles"): the automobile
// workshop also builds trucks, scout and armoured cars, tracked carriers and
// tanks. They are built piece by piece only (vehicle_projects.dm), never in
// one go, from the same body layouts map vehicles use. Each spec is data:
// the layout, the footprint, what it costs, how much of the steel is the
// turret and gun, and the research it needs beyond the press's own.
//
// A works vehicle leaves with an empty tank, empty shell racks and no loose
// guns, ammunition or supplies: the layout's free extras are left out. A
// tank's turret is the craftable built turret with the craftable tank cannon
// and crew seats (vehicle_turret.dm), not the map tank's armed one.

var/global/list/works_vehicle_specs = list(
	"Scout car" = list("path" = /obj/effects/premadevehicles/kurogane/type95, "size" = 3, "node" = null, "gun" = 0,
		"cost" = list("steel" = 50, "glass" = 4, "cloth" = 4, "cable" = 10, "wheels" = 4)),
	"Field car" = list("path" = /obj/effects/premadevehicles/car/mercedes, "size" = 3, "node" = null, "gun" = 0,
		"cost" = list("steel" = 90, "glass" = 6, "cloth" = 4, "cable" = 10, "wheels" = 4)),
	"Cargo truck" = list("path" = /obj/effects/premadevehicles/truck/daf, "size" = 4, "node" = null, "gun" = 0,
		"cost" = list("steel" = 80, "glass" = 8, "cloth" = 6, "cable" = 10, "wheels" = 4)),
	"Armoured car" = list("path" = /obj/effects/premadevehicles/apc/ba64, "size" = 3, "node" = "mechanized_war", "gun" = 0,
		"cost" = list("steel" = 120, "cloth" = 4, "cable" = 10, "wheels" = 4)),
	"Tankette" = list("path" = /obj/effects/premadevehicles/tank/l3, "size" = 3, "node" = "mechanized_war", "gun" = 0,
		"cost" = list("steel" = 140, "cloth" = 4, "cable" = 10, "tracks" = 4)),
	"Tracked carrier" = list("path" = /obj/effects/premadevehicles/apc/m113, "size" = 4, "node" = "mechanized_war", "gun" = 0,
		"cost" = list("steel" = 180, "cloth" = 6, "cable" = 12, "tracks" = 4)),
	"Light tank" = list("path" = /obj/effects/premadevehicles/tank/bt7, "size" = 4, "node" = "mechanized_war", "gun" = 70, "turret" = "round_tank_turret", "turret_x" = -16,
		"cost" = list("steel" = 220, "cloth" = 4, "cable" = 12, "tracks" = 4)),
	"Medium tank" = list("path" = /obj/effects/premadevehicles/tank/t34, "size" = 4, "node" = "mechanized_war", "gun" = 70, "turret" = "tank_turret", "turret_x" = 0,
		"cost" = list("steel" = 300, "cloth" = 6, "cable" = 14, "tracks" = 4)),
	"Heavy tank" = list("path" = /obj/effects/premadevehicles/tank/kv1, "size" = 4, "node" = "mechanized_war", "gun" = 70, "turret" = "tank_turret", "turret_x" = 0,
		"cost" = list("steel" = 380, "cloth" = 6, "cable" = 14, "tracks" = 4)),
	"Main battle tank" = list("path" = /obj/effects/premadevehicles/tank/t55, "size" = 4, "node" = "modern_armor", "gun" = 70, "turret" = "round_tank_turret", "turret_x" = 0,
		"cost" = list("steel" = 460, "cloth" = 6, "cable" = 16, "tracks" = 4)),
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
	// A map tank's own turret comes armed; the press makes the craftable one.
	if (ispath(partpath, /obj/structure/turret))
		return /obj/structure/turret/built
	if (ispath(partpath, /obj/structure/supply_crate) || ispath(partpath, /obj/structure/bed/chair/mgunner) || ispath(partpath, /obj/structure/radio))
		return null
	return partpath

// A works vehicle just assembled as A: its turret gets the craftable tank
// cannon and a gunner's and a loader's seat, fitted as a hand-built tank's
// are (vehicle_turret.dm), and the vehicle counts as hand built, so its
// owners can restyle the turret, refit it or take it apart.
/obj/structure/car_workshop/proc/works_fit(obj/structure/vehicleparts/axis/A, list/spec)
	for (var/obj/structure/turret/built/B in A.built_turrets())
		var/turf/T = get_turf(B)
		var/list/fittings = list(new /obj/structure/cannon/modern/tank(T), new /obj/structure/bed/chair/gunner(T), new /obj/structure/bed/chair/loader(T))
		for (var/obj/O in fittings)
			O.dir = A.dir
		if (spec["turret"])
			B.turret_icon = spec["turret"]
		B.turret_x = spec["turret_x"] || 0
		if (A.color)
			B.turret_color = A.color
		B.fit()
		B.update_icon()
	A.name = lowertext(spec["name"])
	A.hand_built = TRUE

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
