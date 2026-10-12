#define TRUE 1
#define FALSE 0
#define CRASH(message) throw message
var/list/results = list()
var/sink = 0
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
/proc/measure(list/items, mode, repetitions)
	var/elapsed = 0
	for(var/repeat = 1 to repetitions)
		var/list/queue = items.Copy()
		var/process/P = new
		P.current_list = queue
		var/start = world.timeofday
		switch(mode)
			if("subtract")
				P.consume_baseline()
			if("production")
				P.consume()
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
		elapsed += (world.timeofday-start+864000)%864000
		sleep(1)
	return elapsed
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
			var/list/modes = group%2 ? list("subtract","production") : list("production","subtract")
			for(var/mode in modes)
				var/elapsed = measure(items,mode,20)
				results += list(list("count"=count,"mode"=mode,"group"=group,"passes"=20,"elapsed_ds"=elapsed))
		for(var/mode in list("batch","cursor","pop","reverse-pop"))
			var/elapsed = measure(items,mode,20)
			results += list(list("count"=count,"mode"=mode,"group"=0,"passes"=20,"elapsed_ds"=elapsed))
	text2file(json_encode(list("byond"="516.1681","clock"="world.timeofday deciseconds","copy_timed"=FALSE,"samples"=results,"sink"=sink)),"result.json")
	shutdown()
