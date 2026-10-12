#define TRUE 1
#define FALSE 0
var/list/probe_scores = list()
var/list/owned = list()
var/list/results = list()
var/list/samples = list()
var/failures = 0
var/comparisons = 0

/world
	maxx = 32
	maxy = 32
	maxz = 2
	fps = 20
	turf = /turf
	New()
		..()
		OpenPort("none")
		spawn(1)
			run_probe()
	OpenPort(port)
		if(port == "none") return ..()
		return FALSE
/obj/structure
/obj/structure/window/barrier
/mob/living/simple_animal/hostile/human
	var/faction = "friendly"
	var/role = "soldier"
	var/stat = 0
/proc/add_actor(x, y, z = 1, team = "friendly", officer = FALSE)
	var/mob/living/simple_animal/hostile/human/H = new(locate(x,y,z))
	H.faction = team
	H.role = officer ? "officer" : "soldier"
	owned += H
	return H
/proc/reset_scene()
	for(var/atom/A in owned)
		del(A)
	owned.Cut()
	for(var/turf/T in world)
		T.density = FALSE
		T.opacity = FALSE
/proc/position(atom/A)
	return A ? "[A.x],[A.y],[A.z]" : "null"
/proc/check_scene(mob/living/simple_animal/hostile/human/H, atom/enemy, id)
	probe_scores = list()
	var/turf/B = H.baseline_cover(enemy)
	var/list/base_scores = probe_scores
	probe_scores = list()
	var/turf/C = H.candidate_cover(enemy)
	var/ok = B == C && json_encode(base_scores) == json_encode(probe_scores)
	comparisons += base_scores.len
	if(!ok) failures++
	results += list(list("id" = id, "equal" = ok, "baseline" = position(B), "candidate" = position(C), "scores" = base_scores))
/proc/setup_scene(id)
	reset_scene()
	var/cx = id % 10 == 9 ? 2 : 16
	var/cy = id % 10 == 8 ? 31 : 16
	var/mob/living/simple_animal/hostile/human/H = add_actor(cx,cy)
	H.role = id % 7 == 0 ? "officer" : "soldier"
	var/mob/living/simple_animal/hostile/human/E = add_actor(28,16,1,"enemy")
	var/i = 0
	for(var/turf/T in range(3,H))
		i++
		if(id % 10 == 0) continue
		if((i + id) % 3 == 0 || id % 10 == 1)
			var/obj/structure/S
			if(i % 4 == 0)
				S = new /obj/structure/window/barrier(T)
				S.dir = i % 8 + 1
			else
				S = new /obj/structure(T)
				S.density = TRUE
				S.opacity = i % 2
			owned += S
		if(id % 10 == 2 && i % 5 == 0)
			T.density = TRUE
		if(id % 10 == 3 && i % 7 == 0)
			T.opacity = TRUE
	// Include exact clump/leadership boundaries, other factions and other z.
	for(var/j in 1 to (id % 10 == 0 ? 0 : 36))
		var/x = clamp(cx + ((j*7+id) % 19) - 9,1,32)
		var/y = clamp(cy + ((j*11+id) % 19) - 9,1,32)
		var/mob/living/simple_animal/hostile/human/A = add_actor(x,y,j % 11 == 0 ? 2 : 1,j % 4 == 0 ? "enemy" : "friendly",j % 3 == 0)
		A.stat = j % 2
	add_actor(clamp(cx+8,1,32),cy,1,"friendly",TRUE)
	add_actor(clamp(cx+9,1,32),cy,1,"friendly",TRUE)
	if(id % 10 == 4)
		var/obj/container = new(locate(cx,cy,1))
		owned += container
		var/mob/living/simple_animal/hostile/human/A = add_actor(cx,cy,1,"friendly",TRUE)
		A.loc = container
	if(id % 10 == 5)
		E.loc = null
	return list(H,E)
/proc/run_probe()
	if(world.port || world.OpenPort(12345))
		failures++
	for(var/id in 0 to 99)
		var/list/actors = setup_scene(id)
		check_scene(actors[1], id == 99 ? null : actors[2], id)
		if(id % 10 == 0) sleep(1)
#ifdef BENCHMARK
	for(var/mode in list("empty", "sparse", "crowded"))
		var/list/actors = setup_scene(mode == "empty" ? 0 : 1)
		var/mob/living/simple_animal/hostile/human/H = actors[1]
		var/atom/E = actors[2]
		if(mode == "sparse")
			for(var/atom/A in owned.Copy())
				if(A == H || A == E) continue
				del(A)
			owned.Cut()
			owned += H
			owned += E
			var/obj/structure/S = new(locate(17,16,1))
			S.density = TRUE
			owned += S
		if(mode == "crowded")
			for(var/j in 1 to 800)
				var/obj/clutter = new(locate(8+j%17,8+(j*7)%17,1))
				owned += clutter
		// Untimed warmup; every measured call also validates its chosen turf.
		var/turf/expected = H.baseline_bench(E)
		for(var/j in 1 to 100)
			H.baseline_bench(E)
			H.candidate_bench(E)
		for(var/pair in 1 to 5)
			for(var/order in 1 to 2)
				var/current = pair % 2 ? order == 2 : order == 1
				sleep(1)
				var/start = world.timeofday
				var/count = 0
				for(var/call in 1 to 1000)
					var/turf/chosen = current ? H.candidate_bench(E) : H.baseline_bench(E)
					if(chosen != expected) failures++
					count++
				samples += list(list("mode"=mode,"pair"=pair,"candidate"=current,"calls"=count,"elapsed_ds"=world.timeofday-start))
#endif
	text2file(json_encode(list("scenarios"=100,"score_comparisons"=comparisons,"failures"=failures,"choices"=results,"samples"=samples)),"result.json")
	del(world)
