// Paid player construction, using the same body/engine/seat layouts as map cars.
/obj/structure/car_workshop
	name = "automobile workshop"
	desc = "An electric metalworking and assembly press. Feed steel, glass, cloth, cable and four unattached wheels. It builds a car in the clear square northeast of the press. Finished cars need fuel."
	icon = 'icons/obj/structures.dmi'
	icon_state = "workbench"
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	// stock["woolcloth"] tracks the wool portion of stock["cloth"] for refunds.
	// Missing in old saves means all stored cloth is ordinary cloth.
	var/list/stock = list("steel" = 0, "glass" = 0, "cloth" = 0, "cable" = 0, "wheels" = 0)
	var/tmp/busy = FALSE
	var/tmp/assembly_time = 100

// One unplaced press per type answers placement checks for the crafting menu.
var/global/list/car_workshop_prototypes = list()

// Null when user may build result_type where they stand, otherwise why not.
/proc/car_workshop_build_refusal(mob/user, result_type)
	if (!ispath(result_type, /obj/structure/car_workshop))
		return null
	var/obj/structure/car_workshop/P = car_workshop_prototypes[result_type]
	if (QDELETED(P))
		P = new result_type(null)
		P.should_save = FALSE
		car_workshop_prototypes[result_type] = P
	return P.build_refusal(user, get_turf(user))

/obj/structure/car_workshop/persistence_runtime_var(key)
	return (key in list("busy", "assembly_time", "powerneeded", "powersource", "project_frames")) || ..(key)

/obj/structure/car_workshop/after_load()
	..()
	busy = FALSE
	powerneeded = 0
	powersource = null
	update_project_frames()

/obj/structure/car_workshop/proc/models()
	return list("ASNO Piccolino" = /obj/effects/premadevehicles/asno/piccolino, "ASNO Quattroporte" = /obj/effects/premadevehicles/asno/quattroporte, "Ubermacht Erstenklasse" = /obj/effects/premadevehicles/ubermacht/erstenklasse, "SMC Falcon" = /obj/effects/premadevehicles/smc/falcon, "SMC Falcon Unmarked" = /obj/effects/premadevehicles/smc/falcon/unmarked, "SMC Wyoming" = /obj/effects/premadevehicles/smc/wyoming, "Yamasaki Shinobu" = /obj/effects/premadevehicles/yamasaki/shinobu, "Yamasaki Police Shinobu" = /obj/effects/premadevehicles/yamasaki/shinobu/police, "Yamasaki Kazoku" = /obj/effects/premadevehicles/yamasaki/kazoku)

// Research the press needs before it will take inputs or assemble.
/obj/structure/car_workshop/proc/required_nodes()
	return list("automobiles", "electricity")

// Display names of the required research H's faction has not finished.
/obj/structure/car_workshop/proc/missing_research(mob/living/human/H)
	. = list()
	for (var/node_id in required_nodes())
		if (!H || !map || !map.is_node_done(H.civilization, node_id))
			var/datum/research_node/N = get_research_node(node_id)
			. += N ? N.name : node_id

/obj/structure/car_workshop/proc/allowed(mob/living/human/H)
	return H && map && !length(missing_research(H))

/obj/structure/car_workshop/proc/model_size(model)
	if (!(model in models()))
		return 0
	return (model in list("ASNO Piccolino", "ASNO Quattroporte", "Yamasaki Kazoku")) ? 3 : 4

/obj/structure/car_workshop/proc/costs(model)
	var/size = model_size(model)
	if (!size)
		return null
	return list("steel" = size == 3 ? 40 : 60, "glass" = size == 3 ? 6 : 8, "cloth" = size == 3 ? 4 : 6, "cable" = 10, "wheels" = 4)

/obj/structure/car_workshop/proc/requirement_text(mob/living/human/H)
	var/list/missing = missing_research(H)
	return "[english_list(missing.len ? missing : required_nodes())] research [missing.len == 1 ? "is" : "are"] required."

/obj/structure/car_workshop/proc/menu_text()
	return "Stored: [stock["steel"]] steel, [stock["glass"]] glass, [stock["cloth"]] cloth, [stock["cable"]] cable, [stock["wheels"]] wheels. Small cars cost 40/6/4/10/4; large cars cost 60/8/6/10/4. Keep the northeast 4x4 bay empty."

/obj/structure/car_workshop/proc/assembled_message(model)
	return "Your [model] is assembled. Add the correct fuel before driving."

/obj/structure/car_workshop/proc/has_inputs(model)
	var/list/required = costs(model)
	if (!required)
		return FALSE
	for (var/key in required)
		if (stock[key] < required[key])
			return FALSE
	return TRUE

// Assembly bay terrain: dry, open floor. Shared by assembly and placement.
/obj/structure/car_workshop/proc/bay_floor(turf/T)
	return istype(T, /turf/floor) && !istype(T, /turf/floor/beach/water) && !T.density

/obj/structure/car_workshop/proc/largest_model_size()
	. = 0
	for (var/model in models())
		. = max(., model_size(model))

// Why a press placed on origin by H could never assemble anything, or null.
// Reuses the research, bay terrain and cable checks the press runs when used.
// Loose items in the bay are not counted: assembly asks for them to be moved.
/obj/structure/car_workshop/proc/build_refusal(mob/living/human/H, turf/origin)
	if (!isturf(origin))
		return "The [name] must be built on the ground."
	var/list/missing = list()
	var/list/research = missing_research(H)
	if (research.len)
		missing += "[english_list(research)] research"
	var/size = largest_model_size()
	var/blocked = 0
	for (var/dx = 1, dx <= size, dx++)
		for (var/dy = 1, dy <= size, dy++)
			var/turf/T = locate(origin.x + dx, origin.y + dy, origin.z)
			if (!bay_floor(T))
				blocked++
				continue
			for (var/obj/O in T)
				if (O.simulated && O.density && O.anchored)
					blocked++
					break
	if (blocked)
		missing += "a dry, open [size]x[size] floor bay to the northeast of this spot ([blocked] [blocked == 1 ? "tile is" : "tiles are"] walls, water, off the map or fixed structures)"
	if (!(locate(/obj/structure/cable) in range(1, origin)))
		missing += "a laid power cable on or next to this spot (assembly draws 20 power)"
	if (!missing.len)
		return null
	return "The [name] could not work here. Missing: [jointext(missing, "; ")]."

/obj/structure/car_workshop/proc/clear_footprint(model)
	var/size = model_size(model)
	if (!size || !isturf(loc))
		return FALSE
	for (var/dx = 1, dx <= size, dx++)
		for (var/dy = 1, dy <= size, dy++)
			var/turf/T = locate(x + dx, y + dy, z)
			if (!bay_floor(T))
				return FALSE
			// Loose objects and occupants must also be moved out of the assembly bay.
			// Every lit turf holds a lighting overlay, and ghosts or landmarks may
			// share the square; none of those are physical, so they don't count.
			for (var/atom/movable/M in T)
				if (!M.simulated)
					continue
				return FALSE
	return TRUE

/obj/structure/car_workshop/attackby(obj/item/I, mob/living/human/H)
	if (busy || QDELETED(I) || !allowed(H) || !Adjacent(H))
		return
	// A project in the bay takes the materials for its next piece.
	if (project && istype(I, /obj/item/stack))
		project_add(H, I)
		return
	var/key
	if (istype(I, /obj/item/stack/material/steel)) key = "steel"
	else if (istype(I, /obj/item/stack/material/glass)) key = "glass"
	else if (is_cloth_sheet(I)) key = "cloth"
	else if (istype(I, /obj/item/stack/cable_coil)) key = "cable"
	if (key)
		var/obj/item/stack/S = I
		var/wool_payment = key == "cloth" && istype(S, /obj/item/stack/material/woolcloth)
		var/payment = min(S.amount, 200 - stock[key])
		if (payment > 0 && S.use(payment))
			stock[key] += payment
			if (wool_payment) stock["woolcloth"] = (stock["woolcloth"] || 0) + payment
		return
	return ..()

// Wheels are structures: drag an unused wheel onto the workshop.
/obj/structure/car_workshop/MouseDrop_T(atom/movable/O, mob/living/human/H)
	if (busy || QDELETED(O) || !allowed(H) || !Adjacent(H) || !O.Adjacent(H))
		return
	if (istype(O, /obj/structure/cable) && O.Adjacent(src) && isturf(O.loc))
		if (powersource)
			powersource.update_power(0, 1, src)
			powersource.connections -= src
		powersource = O
		powersource.connections |= src
		to_chat(H, SPAN_NOTICE("Workshop connected to the power cable."))
		return
	if (project && istype(O, /obj/structure/vehicleparts/movement))
		project_add(H, O)
		return
	if (O.type == /obj/structure/vehicleparts/movement && stock["wheels"] < 4)
		var/obj/structure/vehicleparts/movement/W = O
		if (!W.axis && !W.connected && !W.broken && !W.anchored)
			stock["wheels"]++
			qdel(W)

/obj/structure/car_workshop/attack_hand(mob/living/human/H)
	if (busy || !Adjacent(H))
		return
	if (!allowed(H))
		to_chat(H, SPAN_WARNING(requirement_text(H)))
		return
	var/list/options = models()
	var/list/extras = extra_options()
	options += extras
	var/list/projects = project_options()
	options += projects
	options["Unload inputs"] = "unload"
	options["Service vehicle keys"] = "keys"
	var/text = menu_text()
	if (piece_projects)
		text += " [project_status()]"
		if (!project)
			text += " Or build one piece by piece in the bay: the materials are brought a piece at a time, by anyone, to the press or to the vehicle."
	var/choice = WWinput(H, text, name, "Cancel", options + list("Cancel"))
	if (busy || !Adjacent(H) || !allowed(H))
		return
	if (choice in extras)
		extra_action(H, extras[choice])
		return
	if (choice in projects)
		project_action(H, projects[choice])
		return
	if (choice == "Unload inputs")
		unload()
		return
	if (choice == "Service vehicle keys")
		var/list/cars = list()
		for (var/obj/structure/vehicleparts/axis/A in range(5, src))
			if (key_service_vehicle(A)) cars["[A.reg_number] ([A.keyed_vehicle_id])"] = A
		var/car = WWinput(H, "Select a stopped unoccupied vehicle in the northeast service bay.", name, "Cancel", cars + list("Cancel"))
		var/action = WWinput(H, "Copy requires a matching key. Rekey requires physical custody and invalidates old copies.", name, "Cancel", list("Copy", "Rekey", "Cancel"))
		if (cars[car] && (action in list("Copy", "Rekey"))) service_vehicle_key(H, cars[car], action == "Rekey")
		return
	assemble_for(H, choice)

// Subtypes add menu entries (label = action) handled by extra_action().
/obj/structure/car_workshop/proc/extra_options()
	return list()

/obj/structure/car_workshop/proc/extra_action(mob/living/human/H, action)
	return

/obj/structure/car_workshop/proc/wait_for_assembly(mob/living/human/H)
	return do_after(H, assembly_time, src)

/obj/structure/car_workshop/proc/assemble_for(mob/living/human/H, choice)
	if (busy || !Adjacent(H) || !allowed(H))
		return null
	if (!(choice in models()) || !has_inputs(choice) || !clear_footprint(choice))
		to_chat(H, SPAN_WARNING("Assembly needs all inputs and an empty, dry floor bay."))
		return null
	busy = TRUE
	powerneeded = 20
	if (!draw_cable_power())
		finish_work()
		to_chat(H, SPAN_WARNING("Connect an active cable supply with 20 available power."))
		return
	var/completed = wait_for_assembly(H)
	if (QDELETED(src))
		return null
	var/obj/structure/vehicleparts/axis/result
	if (completed && Adjacent(H) && allowed(H) && draw_cable_power())
		result = complete_assembly(choice)
		if (result)
			to_chat(H, SPAN_NOTICE(assembled_message(choice)))
	finish_work()
	return result

/obj/structure/car_workshop/proc/finish_work()
	if (powersource)
		powersource.update_power(-powerneeded, 1, src)
	powerneeded = 0
	busy = FALSE

/obj/structure/car_workshop/Destroy()
	finish_work()
	clear_project_frames()
	return ..()

/obj/structure/car_workshop/proc/unload()
	// Separate the paid textile kinds before creating refundable stacks.
	stock["woolcloth"] = min(stock["woolcloth"] || 0, stock["cloth"])
	stock["cloth"] -= stock["woolcloth"]
	var/list/paths = list("steel" = /obj/item/stack/material/steel, "glass" = /obj/item/stack/material/glass, "cloth" = /obj/item/stack/material/cloth, "woolcloth" = /obj/item/stack/material/woolcloth, "cable" = /obj/item/stack/cable_coil)
	for (var/key in paths)
		var/path = paths[key]
		while (stock[key] > 0)
			var/obj/item/stack/S = new path(get_turf(src), 1, FALSE)
			S.amount = min(stock[key], S.max_amount)
			stock[key] -= S.amount
			S.update_icon()
	while (stock["wheels"] > 0)
		new /obj/structure/vehicleparts/movement(get_turf(src))
		stock["wheels"]--

/obj/structure/car_workshop/proc/complete_assembly(model)
	if (!has_inputs(model) || !clear_footprint(model))
		return null
	var/list/choices = models()
	var/path = choices[model]
	var/obj/effects/premadevehicles/B = new path(null, TRUE)
	var/obj/structure/vehicleparts/axis/A = assemble_layout(B, model_size(model))
	qdel(B)
	if (!A)
		return null
	var/list/required = costs(model)
	for (var/key in required)
		stock[key] -= required[key]
	// Spend ordinary cloth first, retaining wool provenance for excess stock.
	stock["woolcloth"] = min(stock["woolcloth"] || 0, stock["cloth"])
	if (!vehicle_key_service.issue_constructed(A, get_turf(src))) return null
	return A

/obj/structure/car_workshop/proc/assemble_layout(obj/effects/premadevehicles/B, size)
	var/list/parts = list()
	var/obj/structure/vehicleparts/axis/A = new B.axis()
	A.dir = SOUTH
	A.color = B.custom_color
	A.new_number()
	var/obj/structure/bed/chair/drivers/D
	for (var/coords in B.tocreate)
		var/list/C = splittext(coords, ",")
		var/turf/T = locate(x + size - 2 + text2num(C[1]), y + text2num(C[2]), z)
		for (var/partpath in B.tocreate[coords])
			// Map templates include free fuel/accessories. Manufacture only car parts.
			if (ispath(partpath, /obj/item/weapon/reagent_containers/glass/barrel/fueltank))
				partpath = ispath(partpath, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/smalltank) ? /obj/item/weapon/reagent_containers/glass/barrel/fueltank/smalltank : /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank
			else if (ispath(partpath, /obj/item))
				continue
			var/obj/O = new partpath(T)
			parts += O
			O.dir = SOUTH
			O.anchored = TRUE
			if (istype(O, /obj/structure/vehicleparts/frame))
				var/obj/structure/vehicleparts/frame/F = O
				F.axis = A
				A.components += F
			if (istype(O, /obj/structure/engine/internal))
				A.engine = O
				A.engine.key_axis = A
				A.engine.engineclass = "carengine"
				A.engine.icon = 'icons/obj/vehicles/vehicleparts.dmi'
			if (istype(O, /obj/structure/bed/chair/drivers))
				D = O
	A.check_corners()
	A.loc = A.corners[2]
	D.axis = A
	A.wheel = D.wheel
	A.wheel.control = locate(/obj/structure/vehicleparts/frame) in D.loc
	for (var/obj/item/weapon/reagent_containers/glass/barrel/fueltank/F in parts)
		A.engine.fueltank = F
		F.icon_state = "fueltank_incar"
	for (var/obj/structure/vehicleparts/movement/W in parts)
		var/obj/structure/vehicleparts/frame/F = locate() in W.loc
		W.MouseDrop(F)
	for (var/obj/structure/vehicleparts/license_plate/P in parts)
		P.axis = A
		P.reg_number = A.reg_number
		P.name = A.reg_number
	// The turning matrix is square, including empty space alongside the body.
	for (var/dx = 1, dx <= size, dx++)
		for (var/dy = 1, dy <= size, dy++)
			var/turf/T = locate(x + dx, y + dy, z)
			if (!(locate(/obj/structure/vehicleparts/frame) in T))
				var/obj/effect/pseudovehicle/P = new(T)
				P.link = A
				P.dir = SOUTH
				A.components += P
	A.check_matrix()
	for (var/obj/O in parts)
		O.update_icon()
	return A
