// The party controller for a nomad visit. One runs at a time (nomad_raid).
//
// Raid:  march -> parley -> (tribute paid: loot the tribute) or assault ->
//        loot -> leave.
// Trade: march -> trade -> leave; attacking or robbing traders -> assault ->
//        leave.
// Any state flees to leave when the leader falls or half the party is down.
//
// The controller gives orders to its NPCs; their own combat AI does the
// fighting. A coordinator (agent control, nomad_coordinator.dm) can voice the
// leader and choose tactics, but only through order(), which enforces the
// same limits on it as on everything else.

/datum/nomad_raid
	should_save = FALSE
	var/tmp/kind = "raid" // raid or trade
	var/tmp/state = "march" // march, parley, trade, assault, loot, leave, ended
	var/tmp/clan
	var/tmp/started_by
	var/tmp/mob/living/simple_animal/hostile/human/nomad_raider/leader
	var/tmp/list/members = list()
	var/tmp/initial_size = 0
	var/tmp/turf/target
	var/tmp/turf/home
	var/tmp/edge
	var/tmp/list/target_ckeys = list()
	var/tmp/started_at = 0
	var/tmp/state_at = 0
	var/tmp/next_decide = 0
	var/tmp/hostile = FALSE // members may pick fights
	var/tmp/mob/living/focus // preferred target, set by the coordinator or a theft
	var/tmp/tactic = "advance" // advance, hold or flank while fighting
	var/tmp/last_seen_foe = 0
	var/tmp/outcome = ""
	var/tmp/list/last_health = list()
	var/tmp/list/struck = list() // ckeys already marked for striking first
	var/tmp/list/loot_target = list() // member = item or closet
	var/tmp/list/done_looting = list()
	var/tmp/stolen = 0
	var/tmp/fallen = 0
	var/tmp/escaped = 0
	var/tmp/escaped_items = 0
	// Raid tribute.
	var/tmp/tribute_base = 0
	var/tmp/tribute_demand = 0
	var/tmp/list/tribute_ignore = list()
	var/tmp/list/tribute_items = list()
	var/tmp/warned_short = FALSE
	// Trade.
	var/tmp/list/stall = list() // turfs where goods lie
	var/tmp/list/goods = list() // item = price
	var/tmp/list/base_price = list() // item = price when laid out
	var/tmp/list/credit = list() // ckey = worth paid and not yet spent
	var/tmp/list/payments = list() // ckey = items paid, newest last
	var/tmp/list/thieves = list() // ckey = list(world.time, item)
	var/tmp/list/payment_ignore = list()
	var/tmp/sold = 0
	// Coordinator and log.
	var/tmp/list/events = list() // list(id, kind, text)
	var/tmp/event_serial = 0
	var/tmp/voice_seen = -1e9
	var/tmp/list/pending_cue // list(text, emote, deadline)
	var/tmp/next_speech = 0

/datum/nomad_raid/persistence_runtime_var(key)
	return TRUE

// ---------------------------------------------------------------------------
// Log, speech and the coordinator's view.

/datum/nomad_raid/proc/event(kind_of, text)
	event_serial++
	events += list(list("id" = event_serial, "kind" = kind_of, "text" = "[text]"))
	if (events.len > NOMAD_RAID_LOG_MAX)
		events.Cut(1, 2)

/datum/nomad_raid/proc/log_event(text)
	log_admin("NOMAD [uppertext(kind)] ([clan]): [text]")
	message_admins("Nomad [kind] ([clan]): [text]")
	event("state", text)

/datum/nomad_raid/proc/set_state(new_state, reason)
	if (state == new_state || state == "ended")
		return
	state = new_state
	state_at = world.time
	log_event("[new_state] - [reason]")

/datum/nomad_raid/proc/heard(mob/living/speaker, text)
	event("heard", "[speaker.real_name] ([speaker.ckey]): [copytext(text, 1, 201)]")

/datum/nomad_raid/proc/voice_active()
	return world.time - voice_seen < NOMAD_RAID_VOICE_SEEN

/datum/nomad_raid/proc/leader_ok()
	return leader && !QDELETED(leader) && leader.stat == CONSCIOUS

/datum/nomad_raid/proc/say_now(text, emote = null)
	if (!leader_ok())
		return FALSE
	next_speech = world.time + 3 SECONDS
	leader.say(text, leader.language)
	// Players may not share the leader's language; a gesture always reads.
	if (emote)
		leader.custom_emote(1, emote)
	event("said", text)
	return TRUE

// A line the leader should say now. An attached coordinator gets a few
// seconds to say it in its own words; otherwise it is said as written.
/datum/nomad_raid/proc/cue(text, emote = null)
	event("cue", text)
	if (voice_active())
		pending_cue = list(text, emote, world.time + NOMAD_RAID_VOICE_GRACE)
		return
	say_now(text, emote)

// ---------------------------------------------------------------------------
// Building the party.

// Returns null on success, else why it could not start.
/datum/nomad_raid/proc/setup(turf/_target, list/ckeys, size, by, _kind = "raid")
	kind = _kind == "trade" ? "trade" : "raid"
	target = _target
	target_ckeys = ckeys ? ckeys.Copy() : list()
	started_by = by
	clan = pick(nomad_raid_clans())
	// A target the party cannot walk to (an island) is reached by raft (nomad_boats.dm).
	var/list/site = plan_crossing(nomad_raid_edge_site(target))
	if (!site)
		return "no open, unseen ground near a map edge on that level"
	home = site["turf"]
	edge = site["edge"]
	// The leader stands nearest the target so followers never block the march.
	var/list/spots = sail_path ? list(home) : list()
	for (var/turf/T in sail_path ? list() : range(2, home))
		if (T == home || !nomad_raid_spawn_error(T))
			var/i = 1
			while (i <= spots.len && get_dist(spots[i], target) <= get_dist(T, target))
				i++
			spots.Insert(i, T)
	size = clamp(round(size), NOMAD_RAID_MIN_MEMBERS, NOMAD_RAID_MAX_MEMBERS)
	for (var/i = 1, i <= size, i++)
		add_member(spots[((i - 1) % spots.len) + 1], i == 1)
	initial_size = members.len
	if (!leader)
		return "the party could not be created"
	started_at = world.time
	state_at = world.time
	tribute_base = max(8, NOMAD_RAID_TRIBUTE_PER_RAIDER * members.len)
	tribute_demand = tribute_base
	return null

/datum/nomad_raid/proc/add_member(turf/T, is_leader)
	var/mob/living/simple_animal/hostile/human/nomad_raider/M = new(T)
	M.party = src
	M.is_leader = is_leader
	M.arm_for_age(map ? map.ordinal_age : 0)
	if (kind == "trade")
		M.name = is_leader ? "[clan] trader" : "[clan] guard"
		M.desc = "A travelling trader and their guards, wary but willing to deal."
	else
		M.name = is_leader ? "[clan] chieftain" : "[clan] raider"
	M.real_name = M.name
	members += M
	last_health[M] = M.health
	if (is_leader)
		leader = M
	return M

/datum/nomad_raid/proc/begin()
	log_event("started by [started_by]: [members.len] [kind == "trade" ? "traders" : "raiders"] from the [edge] edge at [home.x],[home.y],[home.z] toward [target.x],[target.y],[target.z] ([target_ckeys.len ? jointext(target_ckeys, ", ") : "no named players"])")
	for (var/ckey in target_ckeys)
		nomad_raid_cooldowns[ckey] = world.realtime
	nomad_raid_save_cooldowns()
	var/warning = kind == "trade" ? "Caravan bells sound in the distance to the [edge]. Someone is coming." : "War horns sound in the distance to the [edge]. Someone is coming."
	for (var/mob/living/human/H in nomad_raid_defenders_near(target))
		to_chat(H, SPAN_DANGER(warning))
	if (sail_path)
		log_event("crossing by raft from [home.x],[home.y] to land at [landing.x],[landing.y]")
		launch_boats()
	spawn(0)
		run_loop()

/datum/nomad_raid/proc/run_loop()
	while (state != "ended")
		if (!persistence_active_operation && !persistence_save_in_progress)
			try
				tick()
			catch (var/exception/E)
				log_event("stopped by an error: [E] [E.file]:[E.line]")
				remove_all("error")
		sleep(NOMAD_RAID_STEP)

/datum/nomad_raid/proc/alive_members()
	var/list/out = list()
	for (var/mob/living/simple_animal/hostile/human/nomad_raider/M in members)
		if (!QDELETED(M) && M.stat != DEAD)
			out += M
	return out

// ---------------------------------------------------------------------------
// Orders to the NPCs.

/datum/nomad_raid/proc/foe_ok(mob/living/L)
	if (!istype(L) || L.stat != CONSCIOUS || (L in members) || istype(L, /mob/living/simple_animal/hostile/human/nomad_raider))
		return FALSE
	if (ishuman(L))
		return TRUE
	// Animals only when they are already fighting a member.
	if (istype(L, /mob/living/simple_animal))
		var/mob/living/simple_animal/SA = L
		return SA.target_mob in members
	return FALSE

/datum/nomad_raid/proc/set_hostile(on)
	hostile = on ? TRUE : FALSE
	for (var/mob/living/simple_animal/hostile/human/nomad_raider/M in alive_members())
		M.behaviour = hostile ? "hostile" : "defends"
		if (!hostile)
			M.target_mob = null
			M.stance = HOSTILE_STANCE_IDLE

/datum/nomad_raid/proc/order_move(mob/living/simple_animal/hostile/human/nomad_raider/M, atom/dest)
	var/turf/T = get_turf(dest)
	if (!M || !T || M.stat != CONSCIOUS || T.z != M.z)
		return
	M.pathfind_target = T
	if (get_dist(M, T) > 1 && (!M.moving || M.target_obj != T))
		M.do_movement(T)

/datum/nomad_raid/proc/order_halt(mob/living/simple_animal/hostile/human/nomad_raider/M)
	if (!M)
		return
	M.pathfind_target = null
	M.target_obj = null
	M.moving = FALSE

/datum/nomad_raid/proc/follow_leader(list/alive, reach = 2)
	for (var/mob/living/simple_animal/hostile/human/nomad_raider/M in alive)
		if (M == leader)
			continue
		if (get_dist(M, leader) > reach)
			order_move(M, leader)
		else
			order_halt(M)

// ---------------------------------------------------------------------------
// The controller pass.

/datum/nomad_raid/proc/tick()
	var/hurt = FALSE
	for (var/mob/living/simple_animal/hostile/human/nomad_raider/M in members.Copy())
		if (QDELETED(M))
			members -= M
			continue
		if (M.stat == DEAD)
			continue
		if (M.health < last_health[M])
			hurt = TRUE
			note_attacker(M)
		last_health[M] = M.health
	var/list/alive = alive_members()
	if (!alive.len)
		finish("every member fell")
		return
	if (world.time - started_at > NOMAD_RAID_TOTAL_LIMIT)
		remove_all("time limit")
		return
	if (pending_cue && world.time >= pending_cue[3])
		var/list/C = pending_cue
		pending_cue = null
		say_now(C[1], C[2])
	var/decide = world.time >= next_decide
	if (decide)
		next_decide = world.time + NOMAD_RAID_DECIDE
	if (state != "leave" && (!leader_ok() || alive.len * 2 <= initial_size))
		if (leader_ok())
			cue("Fall back! Back to the wilds!")
		set_state("leave", leader_ok() ? "half the party is down" : "the leader is down")
		set_hostile(FALSE)
	switch (state)
		if ("sail")
			tick_sail(alive)
		if ("march")
			tick_march(alive, hurt, decide)
		if ("parley")
			tick_parley(alive, hurt, decide)
		if ("trade")
			tick_trade(alive, hurt, decide)
		if ("assault")
			tick_assault(alive, decide)
		if ("loot")
			tick_loot(alive, decide)
		if ("leave")
			tick_leave(alive)

// Striking a party that had not drawn weapons costs reputation, once a visit.
/datum/nomad_raid/proc/note_attacker(mob/living/simple_animal/hostile/human/nomad_raider/M)
	var/mob/living/human/H = M.lastattacker
	if (hostile || !istype(H) || !H.ckey || (H.ckey in struck))
		return
	struck += H.ckey
	nomad_rep_record(H.ckey, "attack")
	event("reputation", "[H.ckey] struck first")

// Raiders meeting a wanted player attack on sight. Returns TRUE if they did.
/datum/nomad_raid/proc/wanted_check()
	if (kind != "raid" || !leader_ok())
		return FALSE
	var/list/wanted = nomad_rep_wanted_near(get_turf(leader), NOMAD_RAID_PARLEY_RANGE)
	if (!wanted.len)
		return FALSE
	var/mob/living/human/H = wanted[1]
	focus = H
	cue("[H.real_name]! The clans know you. Kill them!", "points their weapon straight at [H.real_name].")
	start_assault("[H.ckey] is wanted by the clans")
	return TRUE

/datum/nomad_raid/proc/start_assault(reason)
	set_state("assault", reason)
	set_hostile(TRUE)
	last_seen_foe = world.time

/datum/nomad_raid/proc/tick_march(list/alive, hurt, decide)
	if (hurt)
		cue(kind == "trade" ? "Bandits! Guards, to me!" : "They strike first! Kill them!")
		start_assault("attacked on the march")
		return
	if (world.time - state_at > NOMAD_RAID_MARCH_LIMIT)
		set_state("leave", "the march took too long")
		return
	if (decide)
		if (wanted_check())
			return
		var/list/near = nomad_raid_defenders_near(get_turf(leader), NOMAD_RAID_PARLEY_RANGE)
		if (near.len)
			if (kind == "trade")
				begin_trade()
			else
				begin_parley()
			return
		if (get_dist(leader, target) <= 3 && !nomad_raid_defenders_near(target).len)
			set_state("leave", "nobody was home")
			return
	order_move(leader, target)
	follow_leader(alive)

// ---------------------------------------------------------------------------
// Raid: parley, assault, loot.

/datum/nomad_raid/proc/begin_parley()
	set_state("parley", "defenders in sight")
	for (var/mob/living/simple_animal/hostile/human/nomad_raider/M in alive_members())
		order_halt(M)
	warned_short = FALSE
	tribute_ignore = list()
	for (var/obj/item/I in range(1, leader))
		tribute_ignore += I
	for (var/mob/living/human/H in nomad_raid_defenders_near(get_turf(leader), NOMAD_RAID_PARLEY_RANGE))
		if (nomad_rep_score(H.ckey) >= NOMAD_REP_FRIEND)
			tribute_demand = max(accept_floor(), round(tribute_demand / 2))
			cue("[H.real_name] is a friend of the [clan]. For their sake, half the usual tribute - lay it at my feet.", "nods at [H.real_name].")
			return
	cue("We are the [clan]. Lay tribute at my feet - tools, metal, food - and we walk away. Refuse, and we take everything.", "points at the ground at their feet, then at your stores, and raises their weapon.")

/datum/nomad_raid/proc/tribute_value()
	var/total = 0
	tribute_items = list()
	for (var/obj/item/I in range(1, leader))
		if (I in tribute_ignore)
			continue
		var/worth = nomad_raid_worth(I)
		if (worth)
			total += worth
			tribute_items += I
	return total

/datum/nomad_raid/proc/accept_tribute(reason)
	outcome = "tribute paid"
	for (var/mob/living/human/H in nomad_raid_defenders_near(get_turf(leader), NOMAD_RAID_PARLEY_RANGE))
		nomad_rep_record(H.ckey, "tribute")
	cue("Wise. The [clan] remembers its friends.")
	set_state("loot", reason)

/datum/nomad_raid/proc/tick_parley(list/alive, hurt, decide)
	if (hurt)
		cue("So be it! Take them!")
		start_assault("attacked during parley")
		return
	follow_leader(alive)
	if (!decide)
		return
	if (wanted_check())
		return
	if (tribute_value() >= tribute_demand)
		accept_tribute("tribute paid")
		return
	var/elapsed = world.time - state_at
	if (!warned_short && elapsed > NOMAD_RAID_PARLEY_TIME - 30 SECONDS)
		warned_short = TRUE
		cue("Not enough. Your time runs short.", "counts on their fingers and glares.")
	if (elapsed > NOMAD_RAID_PARLEY_TIME)
		cue("Then we take it! Kill them!")
		start_assault("tribute refused")

/datum/nomad_raid/proc/foes_near()
	for (var/mob/living/simple_animal/hostile/human/nomad_raider/M in alive_members())
		if (M.target_mob && foe_ok(M.target_mob))
			return TRUE
	for (var/mob/living/human/H in range(NOMAD_RAID_FIGHT_RANGE, target))
		if (foe_ok(H))
			return TRUE
	return FALSE

// Followers without a fight of their own move by the current tactic.
/datum/nomad_raid/proc/tick_assault(list/alive, decide)
	if (world.time - state_at > NOMAD_RAID_ASSAULT_LIMIT)
		end_fight("the fight ran long")
		return
	if (focus && (QDELETED(focus) || focus.stat != CONSCIOUS))
		focus = null
	if (!decide)
		return
	var/side = 1
	for (var/mob/living/simple_animal/hostile/human/nomad_raider/M in alive)
		if (M.target_mob && foe_ok(M.target_mob))
			continue
		switch (tactic)
			if ("hold")
				if (get_dist(M, leader) > 2)
					order_move(M, leader)
			if ("flank")
				// Swing wide on alternating sides of the target.
				var/d = turn(get_dir(home, target), side * 90)
				side = -side
				var/turf/T = nomad_raid_offset(target, d, 5)
				order_move(M, T ? T : target)
			else
				order_move(M, focus ? focus : target)
	if (foes_near())
		last_seen_foe = world.time
	else if (world.time - last_seen_foe > NOMAD_RAID_QUIET_LIMIT)
		end_fight("no one left standing to fight")

/datum/nomad_raid/proc/end_fight(reason)
	if (kind == "trade")
		cue("Enough. We go, and we will not come back.")
		set_hostile(FALSE)
		set_state("leave", reason)
		return
	cue("Grab what you can carry!")
	set_state("loot", reason)

// The tribute if it was paid, else the best loose item or an unlocked crate near the target.
/datum/nomad_raid/proc/pick_loot(mob/living/simple_animal/hostile/human/nomad_raider/M)
	var/list/claimed = list()
	for (var/mob/other in loot_target)
		claimed += loot_target[other]
	if (outcome == "tribute paid")
		for (var/obj/item/I in tribute_items)
			if (!QDELETED(I) && isturf(I.loc) && !(I in claimed) && I.w_class <= M.carry_space())
				return I
		return null
	var/atom/best
	var/best_worth = 0
	for (var/obj/item/I in range(NOMAD_RAID_LOOT_RANGE, target))
		if (I in claimed)
			continue
		if (I.w_class > M.carry_space())
			continue
		var/worth = nomad_raid_worth(I) * 10 - get_dist(M, I)
		if (worth > best_worth)
			best = I
			best_worth = worth
	if (best)
		return best
	for (var/obj/structure/closet/C in range(NOMAD_RAID_LOOT_RANGE, target))
		if (!C.opened && !C.locked && !C.welded && !(C in claimed))
			return C
	return null

/datum/nomad_raid/proc/tick_loot(list/alive, decide)
	if (world.time - state_at > NOMAD_RAID_LOOT_LIMIT)
		set_hostile(FALSE)
		set_state("leave", "looting ran long")
		return
	if (!decide)
		return
	if (outcome == "tribute paid")
		set_hostile(FALSE)
	var/working = FALSE
	for (var/mob/living/simple_animal/hostile/human/nomad_raider/M in alive)
		if (M in done_looting)
			continue
		if (M.target_mob && foe_ok(M.target_mob))
			working = TRUE
			continue
		var/atom/goal = loot_target[M]
		if (!goal || QDELETED(goal) || (istype(goal, /obj/item) && !isturf(goal.loc)))
			goal = pick_loot(M)
			loot_target[M] = goal
			if (!goal)
				done_looting += M
				continue
		working = TRUE
		if (get_dist(M, goal) > 1)
			order_move(M, goal)
			continue
		if (istype(goal, /obj/structure/closet))
			var/obj/structure/closet/C = goal
			C.open()
		else if (M.take_item(goal))
			stolen++
		loot_target[M] = null
	if (!working)
		if (outcome != "tribute paid")
			cue("We have what we came for.")
		set_hostile(FALSE)
		set_state("leave", "looting done")

/datum/nomad_raid/proc/tick_leave(list/alive)
	if (world.time - state_at > NOMAD_RAID_LEAVE_LIMIT)
		remove_all("the walk home ran long")
		return
	for (var/mob/living/simple_animal/hostile/human/nomad_raider/M in alive)
		var/turf/at = get_turf(M)
		if ((get_dist(at, home) <= 3 || get_dist(at, target) > 40) && !ecology_visible_to_players(at, NOMAD_RAID_VIEW_MARGIN))
			escape(M)
			continue
		if (leave_by_boat(M))
			continue
		if (!M.target_mob)
			order_move(M, home)
	sail_step()
	if (!alive_members().len)
		finish(outcome ? outcome : "the party left")

// Leaves the map with what it carries.
/datum/nomad_raid/proc/escape(mob/living/simple_animal/hostile/human/nomad_raider/M)
	escaped++
	for (var/obj/item/I in M.carried)
		if (!QDELETED(I) && I.loc == M)
			escaped_items++
			qdel(I)
	M.carried.Cut()
	members -= M
	qdel(M)

// A fallen member drops everything it carried.
/datum/nomad_raid/proc/member_fell(mob/living/simple_animal/hostile/human/nomad_raider/M)
	fallen++
	M.drop_carried()
	// Killing traders or their guards is remembered; killing raiders is not.
	var/mob/living/human/H = M.lastattacker
	if (kind == "trade" && istype(H) && H.ckey)
		nomad_rep_record(H.ckey, "kill")
		event("reputation", "[H.ckey] killed [M.name]")
	event("fell", "[M.name] fell")

// Ends with everyone gone: survivors drop what they carry, so nothing is lost.
/datum/nomad_raid/proc/remove_all(reason)
	pack_up()
	for (var/mob/living/simple_animal/hostile/human/nomad_raider/M in members.Copy())
		if (!QDELETED(M))
			M.drop_carried()
			M.party = null
			qdel(M)
	members.Cut()
	finish(reason)

/datum/nomad_raid/proc/send_home(reason)
	if (state == "ended")
		return
	cue("Enough. We go.")
	pack_up()
	set_hostile(FALSE)
	set_state("leave", reason)

/datum/nomad_raid/proc/finish(reason)
	if (state == "ended")
		return
	state = "ended"
	clear_boats()
	log_event("ended - [reason]. [escaped] of [initial_size] left the map with [escaped_items] items; [fallen] fell; [stolen] items taken; [sold] goods sold.")
	if (nomad_raid == src)
		nomad_raid = null

/datum/nomad_raid/proc/status_text()
	var/list/alive = alive_members()
	var/extra = kind == "trade" ? ", [goods.len] goods on the stall, [sold] sold" : ", tribute demand [tribute_demand], [stolen] items taken"
	return "[clan] [kind]: [state] for [round((world.time - state_at) / 10)] s, [alive.len] of [initial_size] standing[extra], target [target.x],[target.y],[target.z][voice_active() ? ", coordinator attached" : ""]."

// Starts a visit on a turf. Returns null on success, else why not.
/proc/start_nomad_raid(turf/target, list/ckeys, size, by, kind = "raid")
	if (nomad_raid)
		return "a visit is already running"
	if (!target)
		return "no target"
	if (persistence_active_operation || persistence_save_in_progress)
		return "a world save is running"
	nomad_raid_load_cooldowns()
	var/datum/nomad_raid/R = new
	var/error = R.setup(target, ckeys, size, by, kind)
	if (error)
		R.remove_all("could not start: [error]")
		qdel(R)
		return error
	nomad_raid = R
	R.begin()
	return null
