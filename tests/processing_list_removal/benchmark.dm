#define TRUE 1
#define FALSE 0
#define CRASH(message) throw message
var/list/results = list()
var/sink = 0
world
	fps = 20
/datum/entry
/process
	var/priority = PROCESS_PRIORITY_MEDIUM
	var/list/current_list
	var/current
/process/proc/consume()
	for(current in current_list)
		sink++
		PROCESS_LIST_CHECK
/process/proc/consume_baseline()
	for(current in current_list)
		sink++
		if(priority != PROCESS_PRIORITY_VERY_HIGH) current_list -= current
/process/proc/consume_guarded_cut()
	for(current in current_list)
		sink++
		if(current_list.len && current_list[1] == current)
			current_list.Cut(1,2)
		else
			current_list -= current
/process/proc/consume_remove_call()
	for(current in current_list)
		sink++
		if(priority != PROCESS_PRIORITY_VERY_HIGH) current_list.Remove(current)
/proc/measure(list/items, mode, repetitions)
	var/elapsed = 0
	var/operations = 0
	var/remaining = 0
	for(var/repeat = 1 to repetitions)
		var/list/queue = items.Copy()
		var/process/P = new
		P.current_list = queue
		var/start = world.timeofday
		var/start_sink = sink
		switch(mode)
			if("subtract")
				P.consume_baseline()
			if("production")
				P.consume()
			if("guarded-cut")
				P.consume_guarded_cut()
			if("remove-call")
				P.consume_remove_call()
			if("head-while")
				while(queue.len)
					var/datum/entry/current = queue[1]
					if(!current) CRASH("missing benchmark entry")
					sink++
					queue.Cut(1,2)
			if("batch", "cursor")
				for(var/i = 1 to queue.len)
					var/datum/entry/current = queue[i]
					if(!current) CRASH("missing benchmark entry")
					sink++
					if(mode == "cursor") queue[i] = null
				queue.Cut()
			if("pop", "reverse-pop")
				if(mode == "reverse-pop")
					for(var/i = 1 to round(queue.len/2))
						queue.Swap(i,queue.len-i+1)
				while(queue.len)
					var/datum/entry/current = queue[queue.len]
					if(!current) CRASH("missing benchmark entry")
					sink++
					queue.len--
		var/duration = world.timeofday-start
		if(duration < 0) duration += 864000
		elapsed += duration
		operations += sink-start_sink
		remaining += queue.len
		sleep(1)
	return list("elapsed_ds"=elapsed,"operations"=operations,"remaining"=remaining,"complete"=(operations == items.len*repetitions && !remaining))
/world/OpenPort(port)
	if(port == "none") return ..()
	return FALSE
/world/New()
	OpenPort("none")
	for(var/count in list(1000,5000,10000))
		var/list/items = list()
		for(var/i = 1 to count) items += new /datum/entry
		// Alternate paired order to limit drift; 5 groups x 20 complete passes.
		for(var/group = 1 to 5)
			var/list/modes = group%2 ? list("subtract","remove-call") : list("remove-call","subtract")
			for(var/mode in modes)
				var/list/sample = measure(items,mode,20)
				sample["count"] = count
				sample["mode"] = mode
				sample["group"] = group
				sample["passes"] = 20
				results += list(sample)
		for(var/mode in list("production","guarded-cut","head-while","batch","cursor","pop","reverse-pop"))
			var/list/sample = measure(items,mode,20)
			sample["count"] = count
			sample["mode"] = mode
			sample["group"] = 0
			sample["passes"] = 20
			results += list(sample)
	text2file(json_encode(list("byond"="516.1681","clock"="world.timeofday deciseconds","copy_timed"=FALSE,"samples"=results,"sink"=sink)),"result.json")
	shutdown()
