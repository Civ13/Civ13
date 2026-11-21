// A physical data network is separate from the electrical graph. Connection
// authority is the installed, reciprocal segments under the two terminals.
#define CIV_DATA_LAN_MAX_SEGMENTS 256

/proc/civ_data_lan_land(turf/T)
	return istype(T, /turf/floor) && !T.density && !istype(T, /turf/floor/beach/water)

/proc/civ_data_lan_site(turf/T, sealed)
	if (civ_data_lan_land(T))
		return TRUE
	return sealed && istype(T, /turf/floor/beach/water) && !T.density

/proc/civ_data_lan_reach_seabed(mob/living/human/H, turf/T)
	if (!sea_layer_cell(T))
		return TRUE
	var/turf/from = H.loc
	return !T.iscovered() && sea_layer_cell(from) && !from.iscovered() && H.can_walk_seabed() && H.seabed_zone_allowed(T)

// Only the map's real surface/seabed pair can host a vertical feedthrough.
/proc/civ_data_lan_riser_tile(turf/T)
	if (!T || T.iscovered() || !map || !map.sea_layer_surface_z)
		return null
	var/surface = map.sea_layer_surface_z
	var/below = multiz_level_below(surface)
	if (!below || below == surface || multiz_level_above(below) != surface)
		return null
	if (T.z == surface && sea_layer_open_surface(T))
		var/turf/B = locate(T.x, T.y, below)
		if (sea_layer_cell(B) && !B.iscovered())
			return B
	if (T.z == below && sea_layer_cell(T))
		var/turf/S = locate(T.x, T.y, surface)
		if (sea_layer_open_surface(S) && !S.iscovered())
			return S
	return null

/proc/civ_data_lan_ready(mob/living/human/H, atom/target)
	return !persistence_save_in_progress && !persistence_active_operation && !persistence_load_recovery_required && istype(H) && !QDELETED(H) && target && !QDELETED(target) && H.stat == CONSCIOUS && H.can_use_hands() && isturf(H.loc) && H.z == target.z && get_dist(H, target) <= 1

/obj/item/stack/data_lan_cable
	name = "land data cable coil"
	singular_name = "land data cable segment"
	desc = "Insulated data cable, not a power conductor. Use it on solid dry ground to lay a segment."
	icon = 'icons/obj/machines/power.dmi'
	icon_state = "coil"
	color = "#70ddbc"
	max_amount = 50
	w_class = ITEM_SIZE_SMALL
	var/segment_type = /obj/structure/data_lan_cable
	var/sealed = FALSE

/obj/item/stack/data_lan_cable/sealed
	name = "sealed data cable coil"
	singular_name = "sealed data cable segment"
	desc = "Jacketed data cable for water and dry ground. It neither carries power nor jumps between levels."
	color = "#66aaff"
	segment_type = /obj/structure/data_lan_cable/sealed
	sealed = TRUE
	sinkable = FALSE

/obj/item/stack/data_lan_cable/afterattack(atom/target, mob/user, proximity_flag, params)
	if (!isturf(target))
		return ..()
	var/turf/T = target
	var/mob/living/human/H = user
	if (!proximity_flag || !civ_data_lan_ready(H, T) || !H.item_is_in_hands(src) || !civ_telecom_era_allowed(/obj/structure/telecom/terminal/data_lan))
		return
	var/obj/structure/data_lan_cable/existing = locate(/obj/structure/data_lan_cable) in T
	if (!civ_data_lan_site(T, sealed) || existing)
		to_chat(H, "That tile cannot take this cable. Use sealed cable in water, and only one segment per tile.")
		return
	if (!civ_data_lan_reach_seabed(H, T))
		to_chat(H, "Enter the open water and reach the installation site with existing diving equipment or technique.")
		return
	if (!use(1))
		return
	var/obj/structure/data_lan_cable/C = new segment_type(T)
	C.add_fingerprint(H)
	to_chat(H, "You lay a data cable junction. Wrench it to change its open ports.")

/obj/structure/data_lan_cable
	name = "land data cable"
	desc = "A data-only segment. Terminals plug into the cable beneath them. A wrench changes the ports; wirecutters recover the cable."
	icon = 'icons/obj/machines/power.dmi'
	icon_state = "connector"
	color = "#70ddbc"
	layer = 1.96
	anchored = TRUE
	density = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	// Save physical shape, never an object reference or a computed network ID.
	var/port_mask = NORTH|SOUTH|EAST|WEST
	var/sealed = FALSE
	var/vertical_feed = FALSE
	var/coil_type = /obj/item/stack/data_lan_cable

/obj/structure/data_lan_cable/sealed
	name = "sealed data cable"
	desc = "A jacketed data segment rated for underwater use."
	color = "#66aaff"
	sealed = TRUE
	sinkable = FALSE
	coil_type = /obj/item/stack/data_lan_cable/sealed

/obj/structure/data_lan_cable/New()
	..()
	update_icon()

/obj/structure/data_lan_cable/proc/valid_segment()
	return !QDELETED(src) && anchored && isturf(loc) && civ_data_lan_site(loc, sealed) && (port_mask in list(15, 3, 12, 5, 9, 6, 10))

/obj/structure/data_lan_cable/proc/data_riser_neighbor()
	if (!istype(src, /obj/structure/data_lan_cable/sealed) || !vertical_feed || !valid_segment())
		return null
	var/turf/T = civ_data_lan_riser_tile(loc)
	if (!T)
		return null
	var/obj/structure/data_lan_cable/sealed/N = locate(/obj/structure/data_lan_cable/sealed) in T
	if (!N || !N.vertical_feed || !N.valid_segment())
		return null
	return N

/obj/structure/data_lan_cable/examine(mob/user)
	. = ..()
	var/list/labels = list()
	if (port_mask & NORTH) labels += "N"
	if (port_mask & SOUTH) labels += "S"
	if (port_mask & EAST) labels += "E"
	if (port_mask & WEST) labels += "W"
	to_chat(user, "Open ports: [jointext(labels, ", ")].")
	if (istype(src, /obj/structure/data_lan_cable/sealed))
		if (vertical_feed)
			to_chat(user, "Seabed feedthrough: [data_riser_neighbor() ? "connected" : "enabled, not connected"].")
		else if (civ_data_lan_riser_tile(loc))
			to_chat(user, "Seabed feedthrough: off. Use a screwdriver on each end to connect.")

/obj/structure/data_lan_cable/update_icon()
	var/list/ports = list(NORTH, SOUTH, EAST, WEST)
	var/list/open_ports = list()
	for (var/side in ports)
		if (port_mask & side)
			open_ports += side
	if (open_ports.len == 2)
		icon = 'icons/obj/machines/cables.dmi'
		icon_state = "[open_ports[1]]-[open_ports[2]]"
	else
		icon = 'icons/obj/machines/power.dmi'
		icon_state = "connector"

/obj/structure/data_lan_cable/after_load()
	. = ..()
	update_icon()

/obj/structure/data_lan_cable/attackby(obj/item/W, mob/user, params)
	var/mob/living/human/H = user
	if (!civ_data_lan_ready(H, src) || !H.item_is_in_hands(W) || !isturf(loc) || !civ_data_lan_reach_seabed(H, loc))
		return
	if (istype(src, /obj/structure/data_lan_cable/sealed) && is_tool(W, TOOL_SCREWDRIVER))
		if (!vertical_feed && !civ_data_lan_riser_tile(loc))
			to_chat(H, "A feedthrough needs open deep saltwater above a matching seabed tile.")
			return
		vertical_feed = !vertical_feed
		examine(H)
		return
	if (is_tool(W, TOOL_WRENCH))
		var/list/shapes = list(15, 3, 12, 5, 9, 6, 10)
		port_mask = shapes[(shapes.Find(port_mask) % shapes.len) + 1]
		update_icon()
		examine(H)
		return
	if (is_tool(W, TOOL_WIRECUTTER))
		var/turf/T = loc
		if (!isturf(T) || QDELETED(src))
			return
		qdel(src)
		new coil_type(T, 1)
		to_chat(H, "You cut and recover the data cable segment.")
		return
	return ..()

// On-demand, bounded BFS. Never publish partial reachability for a large network.
/proc/civ_data_lan_component(obj/structure/data_lan_cable/start)
	if (!start || !start.valid_segment())
		return null
	var/list/pending = list(start)
	var/list/seen = list()
	seen[start] = TRUE
	var/list/sides = list(NORTH, SOUTH, EAST, WEST)
	var/cursor = 1
	while (cursor <= pending.len)
		var/obj/structure/data_lan_cable/C = pending[cursor++]
		for (var/side in sides)
			if (!(C.port_mask & side))
				continue
			var/turf/T = get_step(C, side)
			if (!T || T.z != C.z)
				continue
			var/obj/structure/data_lan_cable/N = locate(/obj/structure/data_lan_cable) in T
			if (!N || seen[N] || !N.valid_segment() || !(N.port_mask & turn(side, 180)))
				continue
			if (pending.len >= CIV_DATA_LAN_MAX_SEGMENTS)
				return null
			seen[N] = TRUE
			pending += N
		var/obj/structure/data_lan_cable/vertical = C.data_riser_neighbor()
		if (vertical && !seen[vertical])
			if (pending.len >= CIV_DATA_LAN_MAX_SEGMENTS)
				return null
			seen[vertical] = TRUE
			pending += vertical
	return seen

/obj/structure/telecom/terminal/data_lan
	name = "land data terminal"
	desc = "A powered addressed terminal. Connect electricity normally and lay land data cable on its exact tile."
	color = "#70ddbc"

/obj/structure/telecom/terminal/data_lan/operational()
	// Wet cable is passive. No general permission to power equipment underwater.
	return isturf(loc) && civ_data_lan_land(loc) && ..()

/obj/structure/telecom/terminal/data_lan/proc/data_address()
	return "[x].[y].[z]"

/obj/structure/telecom/terminal/data_lan/proc/data_endpoint()
	if (!isturf(loc))
		return null
	var/obj/structure/data_lan_cable/C = locate(/obj/structure/data_lan_cable) in loc
	return C

/obj/structure/telecom/terminal/data_lan/proc/data_can_send(mob/living/human/H, datum/admission)
	return civ_data_lan_ready(H, src) && admission == persistence_admission_identity && !(H.client && H.client.prefs && (H.client.prefs.muted & MUTE_IC))

/obj/structure/telecom/terminal/data_lan/examine(mob/user)
	. = ..()
	to_chat(user, "Local address: [data_address()]. Cable beneath terminal: [data_endpoint() ? "present" : "missing"].")

/obj/structure/telecom/terminal/data_lan/attack_hand(mob/living/human/H)
	if (!civ_data_lan_ready(H, src))
		return
	var/datum/admission = persistence_admission_identity
	var/turf/source_tile = loc
	var/choice = player_input(H, "Land data terminal [data_address()]", name, null, "anything", list("Send", "Power"), TRUE)
	if (!civ_data_lan_ready(H, src) || loc != source_tile || admission != persistence_admission_identity)
		return
	if (choice == "Power")
		enabled = !enabled
		if (!enabled && powersource)
			powersource.update_power(-powerneeded, 1, src)
		return
	if (choice != "Send" || !data_can_send(H, admission))
		return
	if (!operational())
		to_chat(H, "The terminal has no operating power.")
		return
	var/list/component = civ_data_lan_component(data_endpoint())
	if (!component)
		to_chat(H, "No usable cable beneath the terminal, or the network exceeds 256 segments.")
		return
	var/list/addresses = list()
	var/list/duplicates = list()
	for (var/obj/structure/telecom/terminal/data_lan/T in civ_telecom_devices)
		var/obj/structure/data_lan_cable/C = T.data_endpoint()
		if (!C || !component[C] || !T.operational())
			continue
		var/address = T.data_address()
		if (addresses[address])
			duplicates[address] = TRUE
		addresses[address] = T
	var/list/choices = list()
	for (var/address in addresses)
		if (!duplicates[address] && addresses[address] != src)
			choices += address
	if (duplicates[data_address()] || !choices.len)
		to_chat(H, "No uniquely addressed powered recipient on this network. Use one terminal per tile.")
		return
	var/address = player_input(H, "Recipient address", name, null, "anything", choices, TRUE)
	if (!data_can_send(H, admission) || loc != source_tile || !(address in choices))
		return
	var/obj/structure/telecom/terminal/data_lan/target = addresses[address]
	var/raw = player_input(H, "Message (200 characters)", name, null, "text", null, TRUE)
	if (!data_can_send(H, admission) || loc != source_tile || isnull(raw))
		return
	var/message = sanitize(apply_dictionary_replacements(raw), 200)
	if (!message)
		return
	if (deliver_data_message(target, address, message))
		to_chat(H, "Message displayed at [address].")
	else
		to_chat(H, "Message not sent: wait two seconds, or check both terminals, their addresses and the cable path.")

/obj/structure/telecom/terminal/data_lan/proc/deliver_data_message(obj/structure/telecom/terminal/data_lan/target, address, message)
	if (!message || !target || QDELETED(target) || target == src || address != target.data_address() || world.time < last_message + 20 || !operational() || !target.operational())
		return FALSE
	var/obj/structure/data_lan_cable/destination = target.data_endpoint()
	var/list/component = civ_data_lan_component(data_endpoint())
	if (!component || !destination || !component[destination])
		return FALSE
	// A prompt can outlive a moved or newly placed duplicate terminal.
	for (var/obj/structure/telecom/terminal/data_lan/T in civ_telecom_devices)
		if (T != src && T != target && (T.loc == loc || T.loc == target.loc))
			return FALSE
	last_message = world.time
	var/count = 0
	for (var/mob/living/human/H in view(3, target))
		if (H.client && H.stat == CONSCIOUS)
			to_chat(H, "[target] displays from [data_address()]: [message]")
			if (++count >= 32)
				break
	return TRUE

#undef CIV_DATA_LAN_MAX_SEGMENTS
