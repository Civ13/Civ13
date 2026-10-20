// Portable callback deadlines. Queue identity plus row identity cancels old
// sleepers after a repeated load; each named callback has at most one owner.
// This queue stores no actors, terrain snapshots or client session references.
/datum/durable_timer_queue
	var/datum/owner
	var/list/allowed = list()
	var/list/pending = list()
	var/revision = 0

/datum/durable_timer_queue/New(datum/target, list/callbacks)
	..()
	owner = target
	allowed = callbacks.Copy()

/datum/durable_timer_queue/proc/now()
	return world.time

/datum/durable_timer_queue/proc/blocked()
	return persistence_save_in_progress

/datum/durable_timer_queue/proc/schedule(key, delay)
	if(!(key in allowed) || !isnum(delay) || delay < 0 || delay > 1e15)
		throw EXCEPTION("Unsupported durable callback or delay")
	if(pending[key]) return FALSE
	var/list/row = list("deadline" = now() + delay)
	pending[key] = row
	var/expected_revision = revision
	spawn(delay)
		while(owner && revision == expected_revision && pending[key] == row && blocked())
			sleep(1)
		if(!owner || revision != expected_revision || pending[key] != row) return
		pending -= key
		call(owner, allowed[key])()
	return TRUE

/datum/durable_timer_queue/proc/cancel(key)
	pending -= key

/datum/durable_timer_queue/proc/cancel_all()
	revision++
	pending = list()

/datum/durable_timer_queue/proc/snapshot()
	var/list/result = list()
	for(var/key in pending)
		var/list/row = pending[key]
		result[key] = max(0, row["deadline"] - now())
	return result

/datum/durable_timer_queue/proc/validate(list/state)
	if(!islist(state) || state.len > allowed.len)
		throw EXCEPTION("Invalid durable callback inventory")
	for(var/key in state)
		var/remaining = state[key]
		if(!istext(key) || !(key in allowed) || !isnum(remaining) || remaining < 0 || remaining > 1e15)
			throw EXCEPTION("Invalid durable callback remainder")
	return TRUE

/datum/durable_timer_queue/proc/restore(list/state)
	// Validate everything before cancelling any existing callback.
	validate(state)
	cancel_all()
	for(var/key in state)
		schedule(key, state[key])
	return TRUE

/datum/durable_timer_queue/Destroy()
	cancel_all()
	owner = null
	return ..()
