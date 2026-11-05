// What a coordinator (an LLM through agent control) sees and may order.
// Every order is checked here; the coordinator cannot do anything the
// controller would not do on its own: it can talk, bargain within set
// bounds, choose a tactic or focus target in a fight that has already
// started, order looting or a retreat, and reprice goods within bounds.

/datum/nomad_raid/proc/accept_floor()
	return max(4, round(tribute_base / 2))

/datum/nomad_raid/proc/allowed_orders()
	var/list/out = list("say")
	switch (state)
		if ("march")
			out += "retreat"
		if ("parley")
			out += list("bargain", "retreat")
			if (world.time - state_at >= NOMAD_RAID_EARLY_ASSAULT)
				out += "assault"
		if ("trade")
			out += list("price", "retreat")
		if ("assault")
			out += list("tactic", "focus", "retreat")
			if (kind == "raid")
				out += "loot"
		if ("loot")
			out += list("tactic", "focus", "retreat")
	return out

/datum/nomad_raid/proc/coordinator_status(since = 0)
	voice_seen = world.time
	var/turf/center = leader_ok() ? get_turf(leader) : target
	var/list/party_out = list()
	for (var/mob/living/simple_animal/hostile/human/nomad_raider/M in alive_members())
		party_out += list(list("ref" = "\ref[M]", "name" = M.name, "leader" = M.is_leader ? TRUE : FALSE, "health" = round(M.health), "max_health" = M.maxHealth, "distance" = get_dist(center, M), "fighting" = M.target_mob ? "[M.target_mob.name]" : null, "carrying" = M.carried.len))
	var/list/people = list()
	for (var/mob/living/human/H in range(NOMAD_RAID_FIGHT_RANGE + 3, center))
		if (H.stat == DEAD)
			continue
		var/obj/item/held = H.get_active_hand()
		var/list/row = list("ref" = "\ref[H]", "name" = H.real_name, "ckey" = H.ckey, "distance" = get_dist(center, H), "awake" = H.stat == CONSCIOUS ? TRUE : FALSE, "holding" = held ? "[held.name]" : null)
		if (kind == "trade")
			row["credit"] = credit[H.ckey] || 0
		people += list(row)
	var/list/new_events = list()
	for (var/list/E in events)
		if (E["id"] > since)
			new_events += list(E)
	var/list/out = list(
		"active" = TRUE,
		"kind" = kind,
		"clan" = clan,
		"state" = state,
		"seconds_in_state" = round((world.time - state_at) / 10),
		"leader" = leader_ok() ? leader.name : null,
		"party" = party_out,
		"people" = people,
		"events" = new_events,
		"last_event" = event_serial,
		"tactic" = tactic,
		"focus" = focus ? focus.real_name : null,
		"cue" = pending_cue ? pending_cue[1] : null,
		"allowed" = allowed_orders(),
	)
	if (kind == "raid")
		out["tribute"] = list(
			"demand" = tribute_demand,
			"offered" = (state == "parley" && leader_ok()) ? tribute_value() : 0,
			"min_accept" = accept_floor(),
			"min_demand" = accept_floor(),
			"max_demand" = tribute_base * 2,
			"seconds_left" = state == "parley" ? max(0, round((NOMAD_RAID_PARLEY_TIME - (world.time - state_at)) / 10)) : null,
		)
	else
		out["goods"] = goods_list()
		out["thieves"] = thieves.len
	return out

// Returns list("ok", "detail"). by names the coordinator, for the log.
/datum/nomad_raid/proc/order(list/req, by)
	var/what = lowertext("[req["order"]]")
	if (!(what in allowed_orders()))
		return list("ok" = FALSE, "detail" = "[what] is not allowed while [state]; allowed: [jointext(allowed_orders(), ", ")]")
	switch (what)
		if ("say")
			var/text = istext(req["text"]) ? trim(sanitize(copytext(req["text"], 1, 201))) : ""
			if (!length(text))
				return list("ok" = FALSE, "detail" = "say needs text")
			if (world.time < next_speech)
				return list("ok" = FALSE, "detail" = "the leader just spoke; wait [round((next_speech - world.time) / 10, 0.1)] s")
			var/emote = istext(req["emote"]) ? trim(sanitize(copytext(req["emote"], 1, 121))) : null
			if (!say_now(text, length(emote) ? emote : null))
				return list("ok" = FALSE, "detail" = "the leader cannot speak")
			pending_cue = null
			return list("ok" = TRUE, "detail" = text)
		if ("retreat")
			send_home("[by] ordered a retreat")
			return list("ok" = TRUE, "detail" = "leaving")
		if ("assault")
			cue("Then we take it! Kill them!")
			start_assault("[by] refused to wait")
			return list("ok" = TRUE, "detail" = "assault")
		if ("bargain")
			var/decision = lowertext("[req["decision"]]")
			switch (decision)
				if ("accept")
					var/offered = tribute_value()
					if (offered < accept_floor())
						return list("ok" = FALSE, "detail" = "only [offered] offered; at least [accept_floor()] is needed")
					accept_tribute("[by] accepted [offered]")
					pending_cue = null
					return list("ok" = TRUE, "detail" = "accepted [offered]")
				if ("counter")
					var/demand = text2num("[req["demand"]]")
					if (!isnum(demand) || demand < accept_floor() || demand > tribute_base * 2)
						return list("ok" = FALSE, "detail" = "demand must be [accept_floor()] to [tribute_base * 2]")
					tribute_demand = round(demand)
					event("bargain", "[by] set the demand to [tribute_demand]")
					return list("ok" = TRUE, "detail" = "demand [tribute_demand]")
				if ("refuse")
					if (world.time - state_at < NOMAD_RAID_EARLY_ASSAULT)
						return list("ok" = FALSE, "detail" = "the defenders get at least [NOMAD_RAID_EARLY_ASSAULT / 10] seconds to answer")
					cue("Then we take it! Kill them!")
					start_assault("[by] refused the offer")
					return list("ok" = TRUE, "detail" = "assault")
			return list("ok" = FALSE, "detail" = "decision must be accept, counter or refuse")
		if ("tactic")
			var/new_tactic = lowertext("[req["tactic"]]")
			if (!(new_tactic in list("advance", "hold", "flank")))
				return list("ok" = FALSE, "detail" = "tactic must be advance, hold or flank")
			tactic = new_tactic
			event("tactic", "[by] ordered [tactic]")
			return list("ok" = TRUE, "detail" = tactic)
		if ("focus")
			var/mob/living/L = locate(req["target"])
			if (!foe_ok(L) || !ishuman(L) || !leader_ok() || get_dist(leader, L) > NOMAD_RAID_FIGHT_RANGE + 3)
				return list("ok" = FALSE, "detail" = "focus needs an awake person near the party, by ref from people")
			focus = L
			event("focus", "[by] focused on [L.real_name]")
			return list("ok" = TRUE, "detail" = L.real_name)
		if ("loot")
			end_fight("[by] ordered looting")
			return list("ok" = TRUE, "detail" = "looting")
		if ("price")
			var/obj/item/I = locate(req["target"])
			if (!I || !(I in goods))
				return list("ok" = FALSE, "detail" = "price needs a good's ref from goods")
			var/price = text2num("[req["price"]]")
			var/base = base_price[I]
			if (!isnum(price) || price < max(1, round(base / 2)) || price > base * 2)
				return list("ok" = FALSE, "detail" = "price must be [max(1, round(base / 2))] to [base * 2]")
			goods[I] = round(price)
			event("price", "[by] priced [I.name] at [goods[I]]")
			return list("ok" = TRUE, "detail" = "[I.name] [goods[I]]")
	return list("ok" = FALSE, "detail" = "unknown order")
