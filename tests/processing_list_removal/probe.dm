#define TRUE 1
#define FALSE 0
#define PROCESS_KILL 26
var/list/processing_objects = list()
var/list/trace = list()
var/failures = 0
var/checks = 0
var/process/obj/active
/proc/check(ok, message)
	checks++
	if(!ok)
		failures++
		world.log << "FAIL [message]"
/proc/isDeleted(obj/O)
	return !O
/process
	var/priority = PROCESS_PRIORITY_MEDIUM
	var/list/current_list
	var/current
	var/run_time_tick_usage = 0
	var/run_time_tick_usage_allowance = 100000
	var/errors = 0
/process/proc/catchException(exception/e, obj/O)
	errors++
/process/proc/catchBadType(obj/O)
	return
/process/proc/fire()
	return
/process/proc/reset_current_list()
	return
// The separate time-contract suite verifies units and adapter forwarding.
/process/proc/configured_interval_seconds()
	return 2
/obj
	var/id
	var/action
	var/calls = 0
	var/obj/peer
/obj/proc/process()
	calls++
	trace += id
	switch(action)
		if("self-delete")
			del(src)
		if("peer-delete")
			if(peer) del(peer)
		if("remove")
			processing_objects -= peer
		if("add")
			processing_objects += peer
		if("kill")
			return PROCESS_KILL
		if("throw")
			throw "controlled callback"
		if("snapshot-remove")
			active.current_list -= src
		if("sleep")
			sleep(1)
		if("reenter")
			if(calls == 1) active.fire()
	return 0
/obj/proc/process_interval(configured_seconds)
	return process()
/proc/item(id, action = null)
	var/obj/O = new
	O.id = id
	O.action = action
	return O
/world/OpenPort(port)
	if(port == "none") return ..()
	return FALSE
/world/New()
	OpenPort("none")
	// Native tick_usage during world initialization is not an admitted run budget.
	sleep(1)
	check(!world.port && !OpenPort(12345), "closed isolated port")
	for(var/scenario in list("plain", "self-delete", "peer-delete", "remove", "add", "kill", "throw", "reenter", "duplicate", "snapshot-remove", "sleep"))
		trace = list()
		var/obj/a = item("a",scenario)
		var/obj/b = item("b")
		var/obj/c = item("c")
		a.peer = scenario == "add" ? item("d") : b
		processing_objects = list(a,b,c)
		if(scenario == "duplicate") processing_objects += a
		active = new
		active.reset_current_list()
		active.run_time_tick_usage = world.tick_usage
		active.fire()
		var/observed_order = jointext(trace, "")
		world.log << "TRACE [scenario] order=[observed_order] remaining=[active.current_list.len]"
		check(!active.current_list.len, "[scenario] snapshot consumed")
		var/expected = "abc"
		if(scenario == "peer-delete") expected = "ac"
		if(scenario == "reenter") expected = "aabcbc"
		if(scenario == "duplicate") expected = "abca"
		check(jointext(trace,"") == expected, "[scenario] production callback order")
		if(scenario == "add") check(processing_objects.len == 4 && trace.len == 3, "new registry entry waits for fresh pass")
		if(scenario == "remove") check(b.calls == 1 && !(b in processing_objects), "registry removal preserves captured work")
		if(scenario == "kill") check(!(a in processing_objects), "kill unregisters object")
		if(scenario == "throw") check(active.errors == 1 && c.calls == 1, "callback exception retains later work")
	trace = list()
	processing_objects = list(item("a"),item("b"),item("c"))
	active = new
	active.reset_current_list()
	active.run_time_tick_usage_allowance = -1
	for(var/i = 1 to 3)
		check(active.fire() == PROCESS_TICK_CHECK_RETURNED_EARLY && active.current_list.len == 3-i, "budget resume [i] leaves exact suffix")
	check(jointext(trace,"") == "abc", "budget resumes exactly once in forward order")
	// Thousands of objects across single-entry budget slices, actual object loop.
	trace = list()
	processing_objects = list()
	for(var/i = 1 to 5000) processing_objects += item(i)
	active = new
	active.reset_current_list()
	active.run_time_tick_usage_allowance = -1
	var/suffix_ok = TRUE
	for(var/i = 1 to 5000)
		if(active.fire() != PROCESS_TICK_CHECK_RETURNED_EARLY || active.current_list.len != 5000-i) suffix_ok = FALSE
	check(suffix_ok && trace.len == 5000, "5000 object budget slices consume exact suffixes")
	var/order_ok = TRUE
	for(var/i = 1 to trace.len)
		if(trace[i] != i || processing_objects[i]:calls != 1) order_ok = FALSE
	check(order_ok, "5000 objects processed exactly once in forward order")
	var/process/P = new
	var/obj/a = item("a")
	var/obj/b = item("b")
	var/obj/c = item("c")
	for(var/list/input in list(list(a,b,c),list(a,b,a),list(null,b,null),list(a,b,c)))
		for(var/value in list(a,b,c,null))
			P.current_list = input.Copy()
			P.current = value
			var/list/expected = input.Copy()
			expected -= value
			P.consume()
			if(!equal_lists(P.current_list,expected)) world.log << "MISMATCH before=[describe(input)] actual=[describe(P.current_list)] expected=[describe(expected)]"
			check(equal_lists(P.current_list,expected), "value removal matches native subtraction")
	P.current_list = list(a,b,c)
	P.current = b
	P.consume()
	check(P.current_list.len == 2 && P.current_list[1] == a && P.current_list[2] == c, "skipped head retained")
	P.current_list = list(a,b,c)
	P.current = a
	P.current_list -= a
	P.consume()
	check(P.current_list.len == 2 && P.current_list[1] == b, "already removed current leaves next entry")
	P.current_list = list(a,b,c)
	P.current = b
	P.current_list.Insert(1,c)
	P.consume()
	check(equal_lists(P.current_list,list(c,a,c)), "inserted head and duplicate preserve value removal")
	P.current_list = list()
	P.current = b
	P.consume()
	check(!P.current_list.len, "empty snapshot stays empty")
	P.current_list = list(a,b,c)
	P.current = a
	P.priority = PROCESS_PRIORITY_VERY_HIGH
	P.consume()
	check(P.current_list.len == 3, "very high aliases remain untouched")
	P.priority = PROCESS_PRIORITY_MEDIUM
	P.current_list = list(a,b,c)
	P.current = a
	del(a)
	P.consume()
	check(P.current_list.len == 2 && P.current_list[1] == b, "native deletion nulls current and consumes null head")
	var/list/associated = list("a"=1,"b"=2)
	P.current_list = associated.Copy()
	P.current = "a"
	P.consume()
	associated -= "a"
	check(equal_lists(P.current_list,associated) && P.current_list["b"] == 2, "associated key removal matches subtraction")
	world.log << "RESULT checks=[checks] failures=[failures]"
	text2file(json_encode(list("checks"=checks,"failures"=failures)),"result.json")
	shutdown()
/process/proc/consume()
	PROCESS_LIST_CHECK
/proc/equal_lists(list/a,list/b)
	if(a.len != b.len) return FALSE
	for(var/i = 1 to a.len)
		if(a[i] != b[i]) return FALSE
	return TRUE
/proc/describe(list/items)
	var/list/labels = list()
	for(var/entry in items)
		if(isnull(entry))
			labels += "null"
		else if(istype(entry,/obj))
			var/obj/O = entry
			labels += O.id
		else
			labels += "[entry]"
	return jointext(labels,",")
