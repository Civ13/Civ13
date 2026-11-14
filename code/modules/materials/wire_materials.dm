// Wire by material (docs/material-roles.md, "Wire").
//
// Copper cable is the standard and loses nothing, as it always has. Cable of
// another metal is a coil subtype whose cable_color names the metal, so it
// needs no new value on a cable: cables only join their own colour, a run is
// one metal, and a connector joins two metals the way it joins two colours.
//
// Every tile of such cable on a grid takes a share of the supply that follows
// the metal's conductivity. The grid walk in cables.dm adds the shares up as
// it visits each cable, so nothing is walked twice.

#define WIRE_LOSS_PER_TILE 0.005 // at half of copper's conductivity
#define WIRE_LOSS_MAX 0.9        // a grid always delivers a tenth

// cable_color -> material name. Anything not listed is copper.
var/global/list/cable_wire_materials = list(
	"iron" = "iron",
	"aluminium" = "aluminium",
	"silver" = "silver",
	"gold" = "gold",
)
var/global/list/cable_wire_coils = list(
	"iron" = /obj/item/stack/cable_coil/iron,
	"aluminium" = /obj/item/stack/cable_coil/aluminium,
	"silver" = /obj/item/stack/cable_coil/silver,
	"gold" = /obj/item/stack/cable_coil/gold,
)
var/global/list/cable_wire_loss_cache = list()

// Share of the supply one tile of this cable costs: iron 2.4%, aluminium
// 0.3%, gold 0.2%, silver and copper nothing.
/proc/cable_wire_loss(cable_color)
	var/material_name = cable_wire_materials[cable_color]
	if (!material_name)
		return 0
	var/cached = cable_wire_loss_cache[material_name]
	if (isnull(cached))
		var/material/M = get_material_by_name(material_name)
		cached = (M && M.conductivity > 0) ? max(0, WIRE_LOSS_PER_TILE * (100 / M.conductivity - 1)) : WIRE_LOSS_MAX
		cable_wire_loss_cache[material_name] = cached
	return cached

// What reaches the consumers of a grid whose cables add up to this loss.
/proc/cable_delivered(capacity, loss)
	if (loss <= 0)
		return capacity
	return round(capacity * (1 - min(WIRE_LOSS_MAX, loss)), 0.1)

// The coil a cut cable of this colour gives back.
/proc/cable_coil_type(cable_color)
	return cable_wire_coils[cable_color] || /obj/item/stack/cable_coil

/obj/structure/cable/var/tmp/grid_wire_loss = 0

/obj/structure/cable/examine(mob/user)
	. = ..()
	var/material_name = cable_wire_materials[cable_color]
	if (material_name)
		var/material/M = get_material_by_name(material_name)
		var/loss = cable_wire_loss(cable_color)
		to_chat(user, "It is [M ? M.display_name : material_name] wire. [loss > 0 ? "Each tile of it costs the grid [round(loss * 100, 0.1)]% of its supply." : "It carries power as well as copper."]")
	if (grid_wire_loss > 0)
		to_chat(user, "Wire losses on this grid: [round(min(WIRE_LOSS_MAX, grid_wire_loss) * 100)]% of the supply.")

/obj/item/stack/cable_coil/update_icon()
	..()
	var/material_name = cable_wire_materials[cable_color]
	if (material_name)
		var/material/M = get_material_by_name(material_name)
		name = "[M ? M.display_name : material_name] [name]"

/obj/item/stack/cable_coil/iron
	desc = "A coil of insulated iron wire. Cheap, and it wastes a good share of the power on a long run."
	cable_color = "iron"
	color = "#6e6e72"

/obj/item/stack/cable_coil/aluminium
	desc = "A coil of insulated aluminium wire. Light, and it loses a little power on a long run."
	cable_color = "aluminium"
	color = "#c8ccd0"

/obj/item/stack/cable_coil/silver
	desc = "A coil of insulated silver wire. It carries power as well as copper does."
	cable_color = "silver"
	color = "#e8e8f0"

/obj/item/stack/cable_coil/gold
	desc = "A coil of insulated gold wire. It loses a little power on a long run and costs a fortune."
	cable_color = "gold"
	color = "#e6c84a"

#undef WIRE_LOSS_PER_TILE
#undef WIRE_LOSS_MAX
