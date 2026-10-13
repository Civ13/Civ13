// Constructed-car authority. No constructors mint identities or replacement keys.
/obj/item/vehicle_key
	name = "vehicle ignition key"
	desc = "A cut key for one vehicle and one lock generation."
	icon = 'icons/obj/key.dmi'
	icon_state = "modern"
	item_state = "key"
	w_class = ITEM_SIZE_SMALL
	var/vehicle_id
	var/key_generation = 0
	get_saved_vars()
		. = ..()
		. |= list("vehicle_id", "key_generation")
	proc/matches(obj/structure/vehicleparts/axis/A)
		return type == /obj/item/vehicle_key && A && A.keyed_vehicle_id == vehicle_id && A.key_generation == key_generation && vehicle_key_binding_valid(vehicle_id, key_generation)
	examine(mob/user)
		..()
		to_chat(user, "Vehicle [vehicle_id], lock generation [key_generation].")

/proc/vehicle_key_binding_valid(id, generation)
	return istext(id) && length(id) == 32 && ckey(id) == id && isnum(generation) && round(generation) == generation && generation >= 1 && generation <= 1000000

/obj/structure/vehicleparts/axis
	var/keyed_vehicle_id
	var/key_generation = 0
	var/tmp/key_service_busy = FALSE
	get_saved_vars()
		. = ..()
		if (keyed_vehicle_id) . |= list("keyed_vehicle_id", "key_generation")
	persistence_runtime_var(key)
		return key == "key_service_busy" || ..(key)
	after_load()
		..()
		key_service_busy = FALSE
		if (engine) engine.key_axis = src
	proc/key_access(mob/living/human/H)
		if (!keyed_vehicle_id) return TRUE
		if (key_service_busy || !vehicle_key_binding_valid(keyed_vehicle_id, key_generation) || !vehicle_key_service.ready_vehicle(src)) return FALSE
		if (!H || H.stat != CONSCIOUS) return FALSE
		for (var/obj/item/vehicle_key/K in H.contents)
			if (K.loc == H && K.matches(src)) return TRUE
		return FALSE

var/global/datum/vehicle_key_service/vehicle_key_service = new

/datum/vehicle_key_service
	var/datum/extraction_account_store/store = new
	New()
		..()
		store.root = "data/vehicle_key_service/"
	proc/ready_vehicle(obj/structure/vehicleparts/axis/A)
		if (!A || !vehicle_key_binding_valid(A.keyed_vehicle_id, A.key_generation)) return FALSE
		var/list/P = store.load_profile(A.keyed_vehicle_id)
		return islist(P) && P["vehicle_key_state"] == "committed" && P["key_generation"] == A.key_generation
	proc/issue_constructed(obj/structure/vehicleparts/axis/A, turf/destination)
		if (!A || A.keyed_vehicle_id || !destination) return null
		var/id = new_extraction_item_id()
		A.keyed_vehicle_id = id
		A.key_generation = 1
		A.extraction_vehicle_part_id = id
		var/list/P = store.load_profile(id)
		if (!islist(P) || P["revision"] != 0) return null
		P["vehicle_key_state"] = "pending"
		P["key_generation"] = 1
		P["operation"] = "construction"
		P["key_history"] = list(list("operation" = "construction", "generation" = 1, "timestamp" = num2text(world.realtime, 20)))
		if (!store.commit_profile(id, P)) return null
		var/obj/item/vehicle_key/K = new(destination)
		K.vehicle_id = id
		K.key_generation = 1
		K.extraction_item_id = new_extraction_item_id()
		P["vehicle_key_state"] = "committed"
		P["issued_key_id"] = K.extraction_item_id
		if (!store.commit_profile(id, P))
			qdel(K)
			return null
		return K

/obj/structure/engine
	var/obj/structure/vehicleparts/axis/key_axis
	get_saved_vars()
		. = ..()
		if (key_axis) . |= "key_axis"

/obj/structure/car_workshop
	var/key_copy_time = 300
	var/key_rekey_time = 3000
	proc/key_service_vehicle(obj/structure/vehicleparts/axis/A)
		if (!A || !A.keyed_vehicle_id || A.moving || A.currentspeed || A.engine?.on || A.key_service_busy) return FALSE
		var/datum/extraction_vehicle_transfer/T = new
		if (!T.capture(A, TRUE)) return FALSE
		for (var/obj/O in T.parts)
			var/turf/F = get_turf(O)
			if (!F || F.z != z || F.x <= x || F.x > x + 4 || F.y <= y || F.y > y + 4) return FALSE
		return vehicle_key_service.ready_vehicle(A)
	proc/key_service_inputs(mob/living/human/H, rekey)
		if (!H || H.stat != CONSCIOUS || !Adjacent(H) || !allowed(H)) return null
		var/obj/item/weapon/wrench/W = locate() in H.contents
		var/obj/item/weapon/weldingtool/T = locate() in H.contents
		if (!W || !T) return null
		var/obj/item/stack/material/steel/S = locate() in H.contents
		var/obj/item/stack/material/copper/C = locate() in H.contents
		var/steel_cost = rekey ? 20 : 2
		var/copper_cost = rekey ? 5 : 1
		if (!S || !C || S.type != /obj/item/stack/material/steel || C.type != /obj/item/stack/material/copper || !S.can_use(steel_cost) || !C.can_use(copper_cost) || round(S.amount) != S.amount || round(C.amount) != C.amount) return null
		if (S.extraction_secure_stored || C.extraction_secure_stored || S.extraction_insurance_token || C.extraction_insurance_token) return null
		return list("wrench" = W, "welder" = T, "steel" = S, "copper" = C, "steel_cost" = steel_cost, "copper_cost" = copper_cost)
	proc/same_key_service_inputs(mob/living/human/H, rekey, list/payment)
		var/list/current = key_service_inputs(H, rekey)
		if (!islist(current) || !islist(payment)) return FALSE
		for (var/key in payment)
			if (current[key] != payment[key]) return FALSE
		return TRUE
	proc/wait_for_key_service(mob/living/human/H, duration)
		return do_after(H, duration, src)
	proc/service_vehicle_key(mob/living/human/H, obj/structure/vehicleparts/axis/A, rekey = FALSE)
		if (busy || !key_service_vehicle(A)) return null
		var/list/payment = key_service_inputs(H, rekey)
		if (!payment || (!rekey && !A.key_access(H)) || (rekey && A.key_generation >= 1000000)) return null
		var/duration = rekey ? key_rekey_time : key_copy_time
		if (!isnum(duration) || round(duration) != duration || duration < 1 || duration > 36000) return null
		var/answer = WWinput(H, "Pay [payment["steel_cost"]] steel and [payment["copper_cost"]] copper for [duration / 10] seconds of powered service? Rekeying invalidates every old copy.", "Vehicle locksmith", "Cancel", list("Confirm", "Cancel"))
		if (answer != "Confirm" || busy || !key_service_vehicle(A) || !same_key_service_inputs(H, rekey, payment) || (!rekey && !A.key_access(H))) return null
		busy = TRUE
		powerneeded = 20
		A.key_service_busy = TRUE
		var/generation = A.key_generation
		var/turf/start = get_turf(A)
		visible_message("[H] begins [rekey ? "rekeying" : "copying a key for"] the secured vehicle. Rekeying will invalidate previous keys.")
		var/completed = draw_cable_power() && wait_for_key_service(H, duration)
		// Release the reservation for the bounded state preflight; no yield follows.
		if (A) A.key_service_busy = FALSE
		var/obj/item/vehicle_key/result
		if (completed && A && !QDELETED(src) && get_turf(A) == start && A.key_generation == generation && key_service_vehicle(A) && draw_cable_power() && same_key_service_inputs(H, rekey, payment) && (rekey || A.key_access(H)))
			var/list/P = vehicle_key_service.store.load_profile(A.keyed_vehicle_id)
			if (!islist(P) || !islist(P["key_history"]) || P["key_history"].len >= 128)
				finish_work()
				return null
			P["vehicle_key_state"] = "pending"
			P["operation"] = rekey ? "rekey" : "copy"
			P["operator"] = H.ckey
			P["previous_generation"] = generation
			P["key_generation"] = generation + (rekey ? 1 : 0)
			P["steel_cost"] = payment["steel_cost"]
			P["copper_cost"] = payment["copper_cost"]
			var/list/event = list("id" = new_extraction_item_id(), "state" = "pending", "operation" = P["operation"], "operator" = H.ckey, "generation" = P["key_generation"], "previous_generation" = generation, "steel_cost" = payment["steel_cost"], "copper_cost" = payment["copper_cost"], "timestamp" = num2text(world.realtime, 20))
			P["key_history"] += list(event)
			if (vehicle_key_service.store.commit_profile(A.keyed_vehicle_id, P))
				var/obj/item/stack/material/steel/S = payment["steel"]
				var/obj/item/stack/material/copper/C = payment["copper"]
				if (!S.use(payment["steel_cost"]) || !C.use(payment["copper_cost"]))
					finish_work()
					return null
				A.key_generation = P["key_generation"]
				result = new(get_turf(src))
				result.vehicle_id = A.keyed_vehicle_id
				result.key_generation = A.key_generation
				result.extraction_item_id = new_extraction_item_id()
				P["issued_key_id"] = result.extraction_item_id
				event["issued_key_id"] = result.extraction_item_id
				event["state"] = "committed"
				P["vehicle_key_state"] = "committed"
				if (!vehicle_key_service.store.commit_profile(A.keyed_vehicle_id, P))
					qdel(result)
					result = null
		finish_work()
		if (result) to_chat(H, "Vehicle key service completed. [rekey ? "All previous copies are invalid." : "The existing keys remain valid."]")
		return result
