// Electrochemical devices are cable-only sources, never mechanical engines.
/obj/structure/battery
	name = "Baghdad-style jar cell"
	desc = "A speculative reconstruction of a disputed ancient battery interpretation. Replace its iron electrode and grape juice electrolyte when empty; it cannot be electrically recharged."
	icon = 'icons/obj/claystuff.dmi'
	icon_state = "clayvase"
	anchored = FALSE
	not_disassemblable = TRUE
	not_movable = FALSE
	var/stored_energy = 0 // abstract power-unit seconds (PU s)
	var/energy_capacity = 600
	var/discharge_rate = 1 // PU; one interval is one second (10 deciseconds)
	var/charge_rate = 0
	var/rechargeable = FALSE
	var/assembled = FALSE
	var/commissioned = FALSE
	var/electrodes_ready = FALSE
	var/electrode_cost = 1
	var/electrolyte_cost = 10
	var/tmp/mode = "off"
	var/tmp/output_power = 0
	var/tmp/output_until = 0
	var/tmp/last_tick = -1
	var/tmp/retired = FALSE

/obj/structure/battery/pile
	name = "iron-copper voltaic-style pile"
	desc = "A gameplay substitute for an early nineteenth-century pile, using iron instead of zinc. It consumes iron electrodes and grape juice electrolyte and cannot be electrically recharged."
	assembled = TRUE
	energy_capacity = 3000
	discharge_rate = 5
	electrode_cost = 5
	electrolyte_cost = 50

/obj/structure/battery/lead_acid
	name = "lead-acid accumulator"
	desc = "A rechargeable nineteenth-century storage battery. Commission it with sulfuric acid, then select charge or discharge. It is built empty."
	assembled = TRUE
	rechargeable = TRUE
	energy_capacity = 12000
	discharge_rate = 10
	charge_rate = 10
	electrolyte_cost = 20

/obj/structure/battery/New()
	..()
	spawn(10)
		battery_loop()

/obj/structure/battery/proc/battery_loop()
	while (!retired)
		settle_tick()
		sleep(10)

/obj/structure/battery/Destroy()
	retired = TRUE
	mode = "off"
	output_power = 0
	if (powersource)
		var/obj/structure/cable/CB = powersource
		CB.connections -= src
		powersource = null
		CB.rebuild_supply()
	return ..()


/obj/structure/battery/proc/disconnect_battery()
	mode = "off"
	output_power = 0
	if (powersource)
		var/obj/structure/cable/CB = powersource
		CB.connections -= src
		powersource = null
		CB.rebuild_supply()

/obj/structure/battery/Move()
	var/atom/previous = loc
	. = ..()
	if (. && loc != previous) disconnect_battery()

/obj/structure/battery/forceMove(atom/destination, var/special_event)
	var/atom/previous = loc
	. = ..()
	if (. && loc != previous) disconnect_battery()
// Only durable chemical state is saved. Output, mode, timers and wiring are
// intentionally rebuilt by players, so loading cannot replay prepaid output.
/obj/structure/battery/get_saved_vars()
	return list("name", "dir", "anchored", "stored_energy", "assembled", "commissioned", "electrodes_ready")

/obj/structure/battery/examine(mob/user)
	..()
	to_chat(user, "Energy: [stored_energy]/[energy_capacity] PU s. Output limit: [discharge_rate] PU. Mode: [mode].")
	if (!assembled)
		to_chat(user, "Fit a fired clay vase first.")
	else if (!commissioned && rechargeable)
		to_chat(user, "Add [electrolyte_cost] units of sulfuric acid to commission this empty accumulator.")
	else if (!rechargeable && !stored_energy)
		to_chat(user, "Fit [electrode_cost] iron sheets, then add [electrolyte_cost] units of grape juice.")

/obj/structure/battery/attack_hand(mob/user)
	if (!anchored || !connected() || !commissioned)
		to_chat(user, "Secure, commission and cable the battery first.")
		return
	if (mode == "off")
		mode = rechargeable ? "charge" : "discharge"
	else if (mode == "charge")
		mode = "discharge"
	else
		mode = "off"
	output_power = 0
	powersource.rebuild_supply()
	to_chat(user, "Battery mode: [mode].")

/obj/structure/battery/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/wrench))
		if (powersource)
			to_chat(user, "Cut the cable first.")
			return
		anchored = !anchored
		return
	if (!assembled && istype(W, /obj/item/weapon/reagent_containers/food/drinks/clay/clayvase))
		assembled = TRUE
		qdel(W)
		to_chat(user, "You fit the ceramic casing.")
		return
	if (assembled && !rechargeable && !stored_energy && !electrodes_ready && istype(W, /obj/item/stack/material/iron))
		var/obj/item/stack/material/iron/I = W
		if (I.amount < electrode_cost)
			to_chat(user, "You need [electrode_cost] iron sheets.")
			return
		I.use(electrode_cost)
		electrodes_ready = TRUE
		return
	if (assembled && mode == "off" && W.reagents)
		var/id = rechargeable ? "sacid" : "grapejuice"
		if ((rechargeable && !commissioned) || (!rechargeable && !stored_energy && electrodes_ready))
			if (W.reagents.get_reagent_amount(id) < electrolyte_cost)
				to_chat(user, "You need [electrolyte_cost] units of [id].")
				return
			W.reagents.remove_reagent(id, electrolyte_cost)
			commissioned = TRUE
			if (!rechargeable)
				stored_energy = energy_capacity
				electrodes_ready = FALSE
			return
	if (istype(W, /obj/item/stack/cable_coil))
		if (!anchored || powersource)
			to_chat(user, "Secure the battery and remove its existing cable first.")
			return
		var/obj/item/stack/cable_coil/CC = W
		var/obj/structure/cable/CB = CC.place_turf(get_turf(src), user, turn(get_dir(user, src), 180))
		if (!CB) return
		powersource = CB
		CB.connections |= src
		// Match existing straight cable attachment semantics.
		for (var/obj/structure/cable/N in range(1, CB))
			if (N != CB && N.cable_color == CB.cable_color && N.tiledir == CB.tiledir && ((CB.tiledir == "horizontal" && N.y == CB.y) || (CB.tiledir == "vertical" && N.x == CB.x)))
				CB.connections |= N
				N.connections |= CB
		CB.rebuild_supply()
		return
	..()

// BATTERY CONTRACTS: also compiled by the isolated fixture.
/obj/structure/battery/proc/connected()
	return anchored && isturf(loc) && powersource && isturf(powersource.loc) && get_dist(src, powersource) == 0 && (src in powersource.connections)

/obj/structure/battery/proc/available_output()
	return connected() && mode == "discharge" && world.time < output_until ? output_power : 0

/obj/structure/battery/proc/settle_tick()
	var/epoch = round(world.time / 10)
	if (last_tick == epoch || retired)
		return
	last_tick = epoch
	stored_energy = min(energy_capacity, max(0, stored_energy))
	output_power = 0
	if (!connected() || !commissioned)
		mode = "off"
		return
	if (mode == "discharge")
		// Prepay one second. Even idle output is consumed; disconnect/toggle
		// never refunds it. A partial final interval publishes reduced capacity.
		output_power = min(discharge_rate, stored_energy)
		stored_energy -= output_power
		output_until = world.time + 10
	else if (mode == "charge" && rechargeable)
		stored_energy += powersource.reserve_battery_charge(min(charge_rate, energy_capacity - stored_energy))
	powersource.rebuild_supply()

/obj/structure/cable/proc/battery_network()
	var/list/pending = list(src)
	var/list/cables = list()
	while (pending.len)
		var/obj/structure/cable/CB = pending[pending.len]
		pending.len--
		if ((CB in cables) || !isturf(CB.loc)) continue
		cables += CB
		for (var/obj/structure/cable/N in CB.connections)
			if (isturf(N.loc) && CB.z == N.z && get_dist(CB, N) <= 1 && (CB in N.connections))
				pending |= N
	return cables

/obj/structure/cable/proc/reserve_battery_charge(requested)
	if (requested <= 0) return 0
	var/epoch = round(world.time / 10)
	var/list/engines = list()
	var/list/loads = list()
	var/available = 0
	var/demand = 0
	for (var/obj/structure/cable/CB in battery_network())
		for (var/obj/OB in CB.connections)
			if (!isturf(OB.loc) || CB.z != OB.z || get_dist(CB, OB) > 1) continue
			if (istype(OB, /obj/structure/engine))
				var/obj/structure/engine/E = OB
				if ((E in engines) || !(CB in E.connections) || !E.on || E.broken) continue
				// Only single-port electrical generators can charge storage.
				// Mechanical loads and separate cable ports have no shared budget.
				var/ports = 0
				var/electrical_only = TRUE
				for (var/obj/device in E.connections)
					if (istype(device, /obj/structure/cable))
						ports++
					else
						electrical_only = FALSE
				if (!electrical_only || ports != 1) continue
				engines += E
				if (E.battery_charge_epoch != epoch)
					E.battery_charge_epoch = epoch
					E.battery_charge_power = 0
				available += max(0, E.maxpower - E.battery_charge_power)
			else if (!istype(OB, /obj/structure/cable) && !istype(OB, /obj/structure/battery) && OB.powersource == CB && !(OB in loads))
				loads += OB
				// Conservative reservation includes idle consumers.
				demand += max(0, OB.powerneeded)
	var/transfer = min(requested, max(0, available - demand))
	var/remaining = transfer
	for (var/obj/structure/engine/E in engines)
		var/draw = min(remaining, max(0, E.maxpower - E.battery_charge_power))
		E.battery_charge_power += draw
		remaining -= draw
	return transfer
