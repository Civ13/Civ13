// Separate long-running Modern Nomads map. The existing bounded account,
// shipment and insurance journals remain the sole equipment owners.
var/global/list/extraction_city_stations = list()

/obj/effect/extraction_exit/scheduled
	name = "scheduled evacuation station"
	var/station_id = "north"
	New()
		..()
		extraction_city_stations |= src
	Del()
		extraction_city_stations -= src
		..()
	eligible(mob/living/human/H)
		if (!..()) return FALSE
		var/obj/map_metadata/extraction_survival/modern_city/M = map
		return istype(M) && M.boarding_allowed(H, src)
	attack_hand(mob/user)
		var/mob/living/human/H = user
		var/obj/map_metadata/extraction_survival/modern_city/M = map
		if (!istype(H) || !istype(M)) return
		M.reserve_evacuation(H, src)

/obj/map_metadata/extraction_survival/modern_city
	ID = MAP_EXTRACTION_CITY
	title = "Modern City Extraction"
	description = "Build and survive in an abandoned Modern city, ship recovered supplies home and reach an announced evacuation station before the final departure."
	nomads = TRUE
	has_hunger = TRUE
	default_research = 210
	no_time_of_day_cycle = FALSE
	round_duration = 6 HOURS + 10 SECONDS
	gamemode = "Modern City Extraction"
	var/tmp/list/evacuation_queue = list()
	var/tmp/departure_index = 1
	var/tmp/departure_warning = 0
	var/tmp/departure_processing = FALSE
	var/tmp/departure_start = 0
	round_briefing()
		return "This city runs for six hours. Hourly departures alternate north and south stations. Reserve the named station and be beside it at departure; the sixth is final. Ship gear before final stranding."
	proc/evacuation_time()
		return world.time
	ensure_round()
		if (!..()) return FALSE
		if (!departure_start) departure_start = round_deadline - round_duration
		return TRUE
	proc/departure_due()
		return departure_start + departure_index HOURS
	proc/departure_station()
		return departure_index % 2 ? "north" : "south"
	proc/reserve_evacuation(mob/living/human/H, obj/effect/extraction_exit/scheduled/E)
		if (!owned(H) || H.stat != CONSCIOUS || H.z != 1 || E?.z != 1 || !E.Adjacent(H) || !(E in extraction_city_stations) || H.extraction_session.profile["state"] != "raid" || H.extraction_session.transitioning || departure_index > 6 || E.station_id != departure_station() || evacuation_time() >= departure_due()) return FALSE
		var/datum/extraction_session/S = H.extraction_session
		evacuation_queue[S.owner] = list("sequence" = S.profile["raid_sequence"], "departure" = departure_index, "station" = E.station_id)
		to_chat(H, "Reserved departure [departure_index] at [E.station_id] station in [round((departure_due() - evacuation_time()) / 600, 0.1)] minutes. Stay or return beside this station at departure. On-foot evacuation keeps carried gear; shipments already committed stay home. No automatic extraction occurs while absent.")
		return TRUE
	proc/boarding_allowed(mob/living/human/H, obj/effect/extraction_exit/scheduled/E)
		var/datum/extraction_session/S = H?.extraction_session
		var/list/reservation = S ? evacuation_queue[S.owner] : null
		return departure_processing && evacuation_time() >= departure_due() && evacuation_time() < departure_due() + 10 SECONDS && islist(reservation) && reservation["departure"] == departure_index && reservation["station"] == E.station_id && E.station_id == departure_station() && reservation["sequence"] == S.profile["raid_sequence"]
	wait_for_extraction(mob/living/human/H, obj/effect/extraction_exit/E)
		// The departure itself is the wait. Commit synchronously after checking
		// physical presence, consciousness, reservation and exact raid sequence.
		return E.eligible(H)
	proc/evacuation_tick()
		if (!ensure_round() || round_closing || departure_index > 6) return
		var/now = evacuation_time()
		var/due = departure_due()
		if (now >= due - 5 MINUTES && departure_warning != departure_index)
			departure_warning = departure_index
			world << "City evacuation [departure_index] leaves [departure_station()] station in at most five minutes. Be beside the named station; the sixth departure is final."
		if (now < due) return
		departure_processing = TRUE
		// A stalled scheduler never grants a late departure retroactively.
		if (now < due + 10 SECONDS)
			for (var/owner in evacuation_queue.Copy())
				var/datum/extraction_session/S = accounts.sessions[owner]
				var/mob/living/human/H = S?.body
				if (!H || !owned(H) || S.transitioning) continue
				for (var/obj/effect/extraction_exit/scheduled/E in extraction_city_stations)
					if (E.eligible(H))
						extract_player(H, E)
						break
		departure_processing = FALSE
		world << "City evacuation [departure_index] has departed [departure_station()] station. Absent or ineligible reservations were not extracted."
		evacuation_queue.Cut()
		departure_index++
	tick()
		evacuation_tick()
		return ..()

/datum/job/civilian/extraction_survival/modern_city
	title = "City Survivor"
	allowed_maps = list(MAP_EXTRACTION_CITY)
	is_nomad = TRUE
	equip(mob/living/human/H)
		..()
		H.make_nomad()
		H.add_note("City Evacuation", "This Modern Nomads city runs for six hours. Hourly evacuation alternates north and south stations. Click the announced station to reserve and be beside it when departure occurs. The sixth departure is final; remaining unsent gear is forfeited. Shipments and home game credits remain in your account.")
