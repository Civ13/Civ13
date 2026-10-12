// Production vote manager and handles; no clients or deployment adapters.
/datum/vote/lifecycle_probe
	var/list/routes = list()
	apply_result(resolved_mode, resolved_faction, winner, list/completion)
		routes += resolved_mode

/datum/vote_probe_listener
	var/calls = 0
	var/reenter = FALSE
	var/cancel_replacement = FALSE
	var/datum/vote_handle/expected
	var/datum/vote_handle/replacement
	proc/complete(winner)
		calls++
		equipment_assert(!vote.active_request, "completion sees detached old vote")
		if (expected) equipment_assert(expected.state == "resolved" && !expected.manager && !expected.completion, "completion sees terminal state without retained callback")
		if (reenter)
			replacement = vote.request_vote("safehouse map", "fixture", TRUE)
			if (cancel_replacement) replacement.cancel()

/proc/vote_handle_probe()
	var/datum/vote/lifecycle_probe/V = new
	var/datum/vote_probe_listener/L = new
	var/datum/vote_handle/A = vote.request_vote("safehouse map", "fixture", TRUE, list(L, "complete"))
	equipment_assert(A && A.state == "pending", "request returns pending handle")
	var/old_generation = A.generation
	equipment_assert(vote.submit_vote("fixture", 1, old_generation), "current ballot accepted")
	equipment_assert(A.cancel() && A.state == "cancelled" && !vote.mode && !vote.active_request && !A.completion && !A.manager, "cancel detaches callbacks and clears UI session")
	vote.process()
	equipment_assert(!A.resolve() && !A.cancel() && L.calls == 0, "cancelled handle cannot resolve or call winner")
	var/datum/vote_handle/B = vote.request_vote("safehouse map", "fixture", TRUE, list(L, "complete"))
	equipment_assert(B && B.generation > old_generation, "replacement receives distinct generation")
	equipment_assert(!vote.submit_vote("fixture", 1, old_generation) && !vote.result(A), "stale ballot and timer cannot touch replacement")
	equipment_assert(vote.submit_vote("fixture", 1, B.generation), "replacement ballot accepted")
	L.reenter = TRUE
	L.expected = B
	equipment_assert(B.resolve() && B.state == "resolved" && !B.completion && !B.manager && L.calls == 1, "resolution exactly once detaches before callback")
	equipment_assert(L.replacement && vote.is_current(L.replacement), "reentrant callback replacement survives old completion")
	equipment_assert(V.routes.len == 0, "reentrant completion suppresses old route effects")
	equipment_assert(!B.resolve() && !B.cancel() && L.calls == 1, "resolved handle cannot resolve twice")
	equipment_assert(L.replacement.cancel(), "reentrant replacement cancellable")
	L.reenter = FALSE
	var/datum/vote_handle/C = vote.request_vote("safehouse map", "fixture", TRUE, list(L, "complete"))
	C.deadline = world.time - 1
	vote.process()
	equipment_assert(C.state == "resolved" && L.calls == 2 && !vote.mode, "expiry resolves default once")
	vote.process()
	equipment_assert(L.calls == 2, "expired timer does not repeat completion")
	var/saved_delay = config.vote_delay
	config.vote_delay = 1000
	equipment_assert(!vote.request_vote("safehouse map", "fixture", FALSE), "ordinary cooldown survives completion")
	config.vote_delay = saved_delay
	var/datum/vote_handle/D = vote.request_choices("Deploy?", list("Ready", "Wait"), "fixture", 20, list(L, "complete"), TRUE)
	equipment_assert(D && !vote.request_choices("Overlap?", list("Yes"), "fixture", 20, list(), TRUE), "generic request refuses replacement while pending")
	D.deadline = world.time
	vote.process()
	equipment_assert(D.state == "resolved" && !D.winner && L.calls == 3, "generic no-ballot expiry completes with null winner")
	for (var/route in list("map", "epoch", "restart", "gamemode", "ship selection"))
		var/datum/vote_handle/E = vote.request_choices("Adapter", list("Choice"), "fixture", 20, list(), TRUE)
		vote.mode = route
		vote.submit_vote("fixture", 1, E.generation)
		var/before = V.routes.len
		equipment_assert(E.resolve() && V.routes.len == before + 1 && V.routes[V.routes.len] == route, "legacy route dispatched once: [route]")
		equipment_assert(!E.resolve() && V.routes.len == before + 1, "legacy route cannot repeat: [route]")
	var/datum/vote_handle/F = vote.request_choices("Reentrant cancel", list("Choice"), "fixture", 20, list(L, "complete"), TRUE)
	vote.mode = "restart"
	vote.submit_vote("fixture", 1, F.generation)
	L.expected = F
	L.reenter = TRUE
	L.cancel_replacement = TRUE
	var/routes_before = V.routes.len
	equipment_assert(F.resolve() && L.replacement.state == "cancelled" && !vote.active_request && V.routes.len == routes_before, "callback-started then cancelled replacement still suppresses old route")
