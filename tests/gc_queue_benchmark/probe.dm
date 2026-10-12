// Native representation benchmark, not a production GC integration test.
world
	fps = 40
/datum/var/gcDestroyed = 0
/datum/queue
	var/list/refs = list()
	var/list/stamps = list()
	var/list/current = list()
	var/head = 1
	var/candidate = FALSE
	var/checks = 0
	var/hards = 0
	var/compactions = 0
	var/max_slots = 0
/datum/queue/proc/add(reftext, stamp)
	if(candidate)
		refs += reftext
		stamps += stamp
		current[reftext] = stamp
	else
		refs -= reftext
		refs[reftext] = stamp
	max_slots = max(max_slots, refs.len)
/datum/queue/proc/drain(cutoff, real_refs = FALSE)
	checks = 0
	hards = 0
	while((candidate ? head <= refs.len : refs.len) && checks < 300 && hards < 30)
		var/r = refs[candidate ? head : 1]
		var/s = candidate ? stamps[head] : refs[r]
		if(s > cutoff)
			break
		checks++
		var/is_current = !candidate || current[r] == s
		if(real_refs && is_current)
			var/datum/D = locate(r)
			if(D && D.gcDestroyed == s)
				del(D)
				hards++
		if(candidate)
			if(is_current)
				current -= r
			refs[head] = null
			stamps[head] = null
			head++
		else
			refs.Cut(1,2)
	if(candidate && head > 4096 && head > refs.len / 2)
		refs.Cut(1,head)
		stamps.Cut(1,head)
		head = 1
		compactions++
	if(candidate && head > refs.len)
		refs.Cut()
		stamps.Cut()
		head = 1
/proc/ensure(value, message)
	if(!value)
		world.log << "FAIL: [message]"
		shutdown()
/proc/correctness(mode)
	var/datum/queue/Q = new
	Q.candidate = mode
	var/list/held = list()
	for(var/i = 1 to 35)
		var/datum/D = new
		D.gcDestroyed = 1
		held += D
		Q.add("\ref[D]",1)
	Q.drain(1,TRUE)
	ensure(Q.hards == 30 && Q.checks == 30,"hard budget")
	Q.drain(1,TRUE)
	ensure(Q.hards == 5,"remaining hard deletions")
	var/datum/live = new
	live.gcDestroyed = 20
	Q.add("\ref[live]",1)
	Q.drain(1,TRUE)
	ensure(live && live.gcDestroyed == 20,"recycled reference timestamp guard")
	Q.add("same-ref",1)
	Q.add("new-ref",20)
	Q.add("same-ref",21)
	Q.drain(1)
	ensure(mode ? Q.current["same-ref"] == 21 : Q.refs["same-ref"] == 21,"superseded entry guard")
	Q.drain(20)
	ensure(mode ? Q.current["same-ref"] == 21 : Q.refs["same-ref"] == 21,"new tail preserved")
	Q.drain(21)
	ensure(Q.refs.len == 0,"empty reset")
	for(var/i = 1 to 10000)
		Q.add("x[i]",1)
	Q.drain(1)
	ensure(Q.checks == 300,"check budget")
	while(mode ? Q.current.len : Q.refs.len)
		Q.drain(1)
	ensure(Q.refs.len == 0 && Q.head == 1,"compaction reset")
	if(mode)
		ensure(Q.compactions > 0,"compaction exercised")
	del(live)
var/global/benchmark_sequence = 0
/proc/workload(mode, backlog, rounds, reused)
	var/datum/queue/Q = new
	Q.candidate = mode
	for(var/i = 1 to backlog)
		Q.add("key[i]",1)
	var/sequence = ++benchmark_sequence
	text2file("start","start-[sequence].txt")
	for(var/round = 1 to rounds)
		for(var/i = 1 to 300)
			Q.add(reused ? "key[i]" : "r[round]-[i]", round + 1)
		Q.drain(round + 1)
	text2file("end","end-[sequence].txt")
	ensure(!mode || Q.refs.len <= 2 * backlog + 8192,"bounded compaction slots")
	return list("candidate"=mode,"backlog"=backlog,"rounds"=rounds,"reused"=reused,"sequence"=sequence,"slots"=Q.refs.len,"live_entries"=(mode ? Q.current.len : Q.refs.len),"compactions"=Q.compactions,"max_slots"=Q.max_slots)
/world/New()
	..()
	world.OpenPort(0)
	spawn(0)
		correctness(FALSE)
		correctness(TRUE)
		var/list/results = list()
		for(var/backlog in list(300,10000,50000))
			for(var/reused in list(FALSE,TRUE))
				for(var/repetition = 1 to 3)
					for(var/mode in list(FALSE,TRUE))
						results += list(workload(mode,backlog,200,reused))
		text2file(json_encode(list("correctness"="passed","results"=results)),"result.json")
		shutdown()
