// Account adapter around native assembly. Stock is a locked preview until the
// original components are durably reserved and consumed after the action wait.
/obj/structure/car_workshop/extraction_private
	name = "private automobile workshop"
	should_save = FALSE
	var/room = 1
	var/tmp/datum/extraction_session/build_session
	var/tmp/list/build_objects
	var/tmp/list/build_payment
	var/tmp/list/build_plan
	var/tmp/build_digest
	var/tmp/feeding = FALSE
	var/tmp/list/paid_wheels
	models()
		return list("ASNO Piccolino" = /obj/effects/premadevehicles/asno/piccolino)
	allowed(mob/living/human/H)
		if (!..()) return FALSE
		var/obj/map_metadata/extraction_survival/M = map
		var/datum/extraction_session/S = H.extraction_session
		return istype(M) && M.owned(H) && H.stat == CONSCIOUS && S.profile["state"] == "home" && S.profile["level"] >= 2 && S.house?.room == room && z == S.house.z && (!S.transitioning || (S == build_session && feeding))
	clear_footprint(model)
		var/obj/map_metadata/extraction_survival/M = map
		return model == "ASNO Piccolino" && istype(M) && build_session && M.car_bay_clear(build_session)
	attackby(obj/item/I, mob/living/human/H)
		if (feeding && H == build_session?.body) return ..()
		to_chat(H, "Keep the exact paid recipe components beside the press, then use it to confirm assembly. Drag an active laid cable onto the press for power.")
	MouseDrop_T(atom/movable/O, mob/living/human/H)
		if (!allowed(H)) return
		if (feeding && H == build_session?.body) return ..()
		if (istype(O, /obj/structure/cable)) return ..()
	unload()
		// Preview stock is not a second inventory of paid components.
		return
	has_inputs(model)
		if (!..() || !build_session?.active()) return FALSE
		if (feeding) return build_session.profile["garage_purchase"]["id"] == build_plan["garage_purchase"]["id"]
		var/obj/map_metadata/extraction_survival/M = map
		if (md5(json_encode(build_session.profile)) != build_digest || json_encode(M.records(M.home_roots(build_session))) != json_encode(build_session.profile["stash"])) return FALSE
		for (var/obj/item/I in build_objects)
			if (!I.loc || !I.Adjacent(src) || !I.Adjacent(build_session.body)) return FALSE
		return json_encode(build_session.plan_vehicle_construction(build_payment, build_session.profile["revision"], costs(model))) == json_encode(build_plan)
	attack_hand(mob/living/human/H)
		if (busy || !Adjacent(H) || !allowed(H)) return
		var/obj/map_metadata/extraction_survival/M = map
		var/datum/extraction_session/S = H.extraction_session
		if (!M.save_home(S) || !M.car_bay_clear(S)) return
		var/list/required = costs("ASNO Piccolino")
		var/list/totals = list("steel" = 0, "glass" = 0, "cloth" = 0, "cable" = 0, "wheels" = 0)
		var/list/objects = list()
		var/list/payment = list()
		for (var/obj/item/I in M.home_roots(S))
			if (!I.Adjacent(src) || !I.Adjacent(H) || I.extraction_secure_stored || I.extraction_insurance_token) continue
			var/key
			if (I.type == /obj/item/stack/material/steel) key = "steel"
			else if (I.type == /obj/item/stack/material/glass) key = "glass"
			else if (I.type == /obj/item/stack/material/cloth) key = "cloth"
			else if (I.type == /obj/item/stack/cable_coil) key = "cable"
			else if (I.type == /obj/item/extraction_wheel_crate) key = "wheels"
			if (!key || totals[key] >= required[key]) continue
			var/quantity = key == "wheels" ? 1 : I:amount
			if (totals[key] + quantity > required[key]) continue
			totals[key] += quantity
			objects += I
			payment += I.extraction_item_id
		var/list/plan = S.plan_vehicle_construction(payment, S.profile["revision"], required)
		if (!plan)
			to_chat(H, "Bring exactly 40 steel, 6 glass, 4 cloth, 10 cable and four boxed standard wheels beside the press. Split oversized stacks first. A level-two empty bay and 20 available cable power are required.")
			return
		var/digest = md5(json_encode(S.profile))
		if (WWinput(H, "Assemble a Piccolino from these exact paid components? Assembly needs native research, 20 cable power and an uninterrupted action. Finished cars have no fuel. An uncertain paid build quarantines the account for explicit offline forfeiture.", name, "Cancel", list("Assemble", "Cancel")) != "Assemble") return
		if (busy || !allowed(H) || !Adjacent(H) || md5(json_encode(S.profile)) != digest) return
		build_session = S
		build_objects = objects
		build_payment = payment
		build_plan = plan
		build_digest = digest
		stock = required.Copy()
		try
			assemble_for(H, "ASNO Piccolino")
			// Native validation can return before acquiring/releasing its work lock.
			if (build_session) finish_work()
		catch (var/exception/E)
			world.log << "Private assembly interrupted: [E]"
			if (islist(S.profile["garage_purchase"]) && S.profile["garage_purchase"]["status"] == "pending") S.locked = TRUE
			finish_work()
	wait_for_assembly(mob/living/human/H)
		if (!..() || !allowed(H) || !Adjacent(H) || !has_inputs("ASNO Piccolino") || !clear_footprint("ASNO Piccolino") || !draw_cable_power()) return FALSE
		var/datum/extraction_session/S = build_session
		S.transitioning = TRUE
		if (!S.commit(build_plan)) return FALSE
		feeding = TRUE
		paid_wheels = list()
		stock = list("steel" = 0, "glass" = 0, "cloth" = 0, "cable" = 0, "wheels" = 0)
		busy = FALSE
		for (var/obj/item/I in build_objects)
			if (I.type == /obj/item/extraction_wheel_crate)
				var/obj/item/extraction_wheel_crate/C = I
				// Keep originals in their paid crates until the layout is ready.
				if (!C.snapshot_wheel() || C.wheel.broken) return FALSE
				paid_wheels += C
				stock["wheels"]++
			else attackby(I, H)
		busy = TRUE
		return TRUE
	assemble_layout(obj/effects/premadevehicles/B, size)
		var/obj/map_metadata/extraction_survival/M = map
		var/turf/anchor = M.garage_anchor(build_session)
		var/obj/structure/car_workshop/factory = new(null)
		factory.loc = locate(anchor.x - 3, anchor.y - 1, anchor.z)
		var/obj/structure/vehicleparts/axis/A = factory.assemble_layout(B, size)
		qdel(factory)
		if (!install_paid_wheels(A)) return null
		return A
	proc/install_paid_wheels(obj/structure/vehicleparts/axis/A)
		if (!A || A.wheels.len != 4 || paid_wheels?.len != 4) return FALSE
		var/list/templates = A.wheels.Copy()
		var/list/seen = list()
		// Preflight the whole substitution before touching any of the four roots.
		for (var/i in 1 to 4)
			var/obj/item/extraction_wheel_crate/C = paid_wheels[i]
			var/obj/structure/vehicleparts/movement/old = templates[i]
			if (!C.snapshot_wheel() || C.wheel.broken || !old.connected || old.axis != A || old.connected.mwheel != old) return FALSE
			if ((C in seen) || (old.connected in seen)) return FALSE
			seen += C
			seen += old.connected
		for (var/i in 1 to 4)
			var/obj/item/extraction_wheel_crate/C = paid_wheels[i]
			var/obj/structure/vehicleparts/movement/old = templates[i]
			var/obj/structure/vehicleparts/frame/F = old.connected
			var/obj/structure/vehicleparts/movement/W = C.wheel
			A.wheels -= old
			F.mwheel = null
			old.axis = null
			old.connected = null
			qdel(old)
			W.MouseDrop(F)
			W.should_save = TRUE
			W.update_icon()
			if (W.axis != A || W.connected != F || W.loc != F) return FALSE
			C.wheel = null
			qdel(C)
		return TRUE
	complete_assembly(model)
		var/obj/structure/vehicleparts/axis/A = ..()
		var/obj/map_metadata/extraction_survival/M = map
		var/datum/extraction_session/S = build_session
		var/datum/extraction_vehicle_transfer/T = new
		if (A && T.capture(A))
			S.garage_vehicle = A
			S.garage_parts = T.parts.Copy()
			var/list/garage = M.garage_snapshot(S)
			if (garage?.len && S.finish_vehicle_purchase(garage[1], build_plan["garage_purchase"]["id"]))
				S.transitioning = FALSE
				return A
		S.locked = TRUE
		return null
	finish_work()
		..()
		if (build_session?.profile && islist(build_session.profile["garage_purchase"]) && build_session.profile["garage_purchase"]["status"] == "pending") build_session.locked = TRUE
		else if (build_session) build_session.transitioning = FALSE
		stock = list("steel" = 0, "glass" = 0, "cloth" = 0, "cable" = 0, "wheels" = 0)
		feeding = FALSE
		paid_wheels = null
		build_session = null
		build_objects = null
		build_payment = null
		build_plan = null
		build_digest = null
	persistence_runtime_var(key)
		if (key in list("stock", "build_session", "build_objects", "build_payment", "build_plan", "build_digest", "feeding", "paid_wheels")) return TRUE
		return ..()
