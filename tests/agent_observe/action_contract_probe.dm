// Production queue contract probe. Included only by the isolated observe fixture.
/proc/observe_action_contract_checks()
	var/datum/agent_character/C = observe_character(22, 22, "Receipt worker")
	var/datum/agent_identity/A = observe_identity()
	var/list/first = observe_call("observe", C, list())
	var/guard = first["queue"]["guard"]
	var/list/request = list("guard" = guard, "_request_id" = "synthetic-request-1", "actions" = list(list("do" = "face", "dir" = "north")))
	var/list/accepted = observe_call("queue", C, request)
	observe_check(islist(accepted) && accepted["state"] == "accepted" && accepted["request_id"] == "synthetic-request-1", "a guarded queue returns acceptance, not completion")
	var/serial = C.queue_serial
	var/replayed = observe_call("queue", C, request)
	observe_check(istext(replayed) && findtext(replayed, "stale_action") && C.queue_serial == serial, "duplicate guarded request cannot enqueue again")
	sleep(5)
	var/list/state = C.queue_state()
	var/list/receipts = state["results"]
	observe_check(receipts.len == 1 && receipts[1]["state"] == "completed" && receipts[1]["request_id"] == "synthetic-request-1", "completion retains the accepted request identity")
	first = observe_call("observe", C, list())
	request["guard"] = first["queue"]["guard"]
	var/duplicate = observe_call("queue", C, request)
	observe_check(istext(duplicate) && findtext(duplicate, "duplicate_action") && C.queue_serial == serial, "duplicate request id cannot reuse a fresh observation")
	first = observe_call("observe", C, list())
	guard = first["queue"]["guard"]
	observe_call("observe", C, list())
	request = list("guard" = guard, "_request_id" = "synthetic-old", "actions" = list(list("do" = "face", "dir" = "south")))
	var/stale = observe_call("queue", C, request)
	observe_check(istext(stale) && findtext(stale, "stale_action") && C.queue_serial == serial, "out-of-order observation guard is rejected without queue mutation")
	first = observe_call("observe", C, list())
	C.queue_guard_at = world.time - AGENT_QUEUE_GUARD_TTL - 1
	request["guard"] = first["queue"]["guard"]
	stale = observe_call("queue", C, request)
	observe_check(istext(stale) && findtext(stale, "stale_action") && C.queue_serial == serial, "expired observation guard is rejected")
	first = observe_call("observe", C, list())
	guard = first["queue"]["guard"]
	request = list("guard" = guard, "actions" = list(list("do" = "face", "dir" = "south")))
	var/bad = observe_call("queue", C, request)
	observe_check(istext(bad) && findtext(bad, "request_id") && C.queue_serial == serial, "missing request identity is rejected before mutation")
	// Keep a real wait active while a malformed replacement attempts to clear its suffix.
	observe_call("queue", C, list("actions" = list(list("do" = "wait", "ticks" = 10), list("do" = "face", "dir" = "west"))))
	sleep(1)
	var/pending = C.queue.len
	serial = C.queue_serial
	bad = observe_call("queue", C, list("clear" = TRUE, "actions" = list(list("do" = "intent", "intent" = "invalid"))))
	observe_check(istext(bad) && C.queue.len == pending && C.queue_serial == serial, "invalid replacement never clears pending work")
	first = observe_call("observe", C, list())
	request = list("guard" = first["queue"]["guard"], "_request_id" = "synthetic-pending", "actions" = list(list("do" = "face", "dir" = "south")))
	bad = observe_call("queue", C, request)
	observe_check(istext(bad) && findtext(bad, "action_pending") && C.queue_serial == serial, "guarded second action is refused while the first is pending")
	request = list("guard" = first["queue"]["guard"], "_request_id" = "synthetic-cancel", "clear" = TRUE)
	accepted = observe_call("queue", C, request)
	observe_check(islist(accepted) && !C.queue.len && C.queue_running, "cancel clears suffix but does not claim running game work was rolled back")
	sleep(12)
	state = C.queue_state(1)
	receipts = state["results"]
	observe_check(receipts.len == 2 && !receipts[1]["ok"] && !receipts[2]["ok"] && receipts[1]["id"] < receipts[2]["id"], "cancelled wait and suffix both have ordered terminal receipts")
	// A targeted stop cannot erase an independent operator's queued work.
	C.queue_running = TRUE // hold dispatch while inspecting cancellation bookkeeping
	observe_call("queue", C, list("_request_id" = "other-operator", "actions" = list(list("do" = "face", "dir" = "east"))))
	observe_call("queue", C, list("_request_id" = "our-request", "actions" = list(list("do" = "face", "dir" = "south"))))
	observe_call("queue", C, list("clear" = TRUE, "cancel_request_id" = "our-request"))
	observe_check(C.queue.len == 1 && C.queue[1]["request_id"] == "other-operator", "targeted cancellation preserves another operator's queue")
	C.cancel_queue("fixture cleanup")
	C.queue_running = FALSE
	// Scope loss is checked for wait steps too, not just ordinary actions.
	observe_call("queue", C, list("actions" = list(list("do" = "wait", "ticks" = 2), list("do" = "face", "dir" = "south"))))
	A.scopes = list()
	sleep(5)
	observe_check(!C.queue.len && !C.queue_running && C.body.dir != SOUTH, "scope revocation prevents pending wait and face actions")
	A.scopes = list("characters")
	agent_characters -= C.body
	qdel(C.body)
