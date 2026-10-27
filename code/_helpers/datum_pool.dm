
/*
/tg/station13 /atom/movable Pool:
---------------------------------
By RemieRichards

Creation/Deletion is laggy, so let's reduce reuse and recycle!

*/
#define ATOM_POOL_COUNT 100
#define DATUM_POOL_TOTAL_COUNT 1000
var/global/pooled_count = 0
var/global/list/pool_idle = list()
// Preserve reviewed legacy callers; a new type must explicitly opt in here.
var/global/list/pool_type_roots = list(/atom/movable/overlay, /atom/movable/lighting_overlay, /obj/effect/mist, /obj/effect/effect/steam, /obj/effect/sparks, /obj/effect/effect/smoke, /obj/effect/projectile, /datum/effect/effect/system/spark_spread, /datum/effect/effect/system/smoke_spread, /obj/effect/decal/cleanable/blood/splatter, /obj/item/stack/rods)

/proc/pool_type_allowed(get_type)
	for (var/root in pool_type_roots)
		if (ispath(get_type, root))
			return TRUE
	return FALSE

// Idle pools own only retired objects. Bound each sweep, not live content.
/proc/ExpirePools(limit = 32)
	while (limit-- > 0 && pool_idle.len)
		var/datum/D = pool_idle[1]
		if (pool_idle[D] > world.time)
			break
		pool_idle.Cut(1, 2)
		if (!D)
			continue
		GlobalPool[D.type] -= D
		pool_idle -= D
		pooled_count--
		D.gcDestroyed = 0
		if (processes.garbage)
			processes.garbage.AddTrash(D)
		else
			D.gcDestroyed = world.time + 1
			del(D)

// "define DEBUG_ATOM_POOL TRUE
var/global/list/GlobalPool = list()

//You'll be using this proc 90% of the time.
//It grabs a type from the pool if it can
//And if it can't, it creates one
//The pool is flexible and will expand to fit
//The new created atom when it eventually
//Goes into the pool

//Second argument can be a new location, if the type is /atom/movable
//Or a list of arguments
//Either way it gets passed to new

/proc/PoolOrNew(var/get_type,var/second_arg)
	var/datum/D
	D = GetFromPool(get_type,second_arg)

	if (!D)
		// So the GC knows we're pooling this type.
		if (pool_type_allowed(get_type) && !GlobalPool[get_type])
			GlobalPool[get_type] = list()
		if (islist(second_arg))
			return new get_type (arglist(second_arg))
		else
			return new get_type (second_arg)
	return D

/proc/GetFromPool(var/get_type,var/second_arg)
	if (isnull(GlobalPool[get_type]))
		return FALSE

	if (length(GlobalPool[get_type]) == FALSE)
		return FALSE

	var/datum/D = pick_n_take(GlobalPool[get_type])
	if (D)
		pool_idle -= D
		pooled_count--
		D.ResetVars()
		D.Prepare(second_arg)
		return D
	return FALSE

/proc/PlaceInPool(var/datum/D, cleaned = FALSE)
	if (!istype(D))
		return
	if (!cleaned)
		qdel(D)
		return
	if (D in GlobalPool[D.type])
		return
	if (!pool_type_allowed(D.type) || length(GlobalPool[D.type]) >= ATOM_POOL_COUNT || pooled_count >= DATUM_POOL_TOTAL_COUNT)
		if (processes.garbage)
			processes.garbage.AddTrash(D)
		else
			D.gcDestroyed = world.time + 1
			del(D)
		return
	if (!GlobalPool[D.type])
		GlobalPool[D.type] = list()
	D.ResetVars()
	D.gcDestroyed = world.time + 1
	D.gc_destroyed = GC_QUEUED_FOR_QUEUING
	GlobalPool[D.type] += D
	pooled_count++
	pool_idle[D] = world.time + 5 MINUTES

/proc/IsPooled(var/datum/D)
	if (isnull(GlobalPool[D.type]))
		return FALSE
	return TRUE

/datum/proc/Prepare(construct_args)
	if (islist(construct_args))
		New(arglist(construct_args))
	else
		New(construct_args)

/atom/movable/Prepare(construct_args)
	var/list/args_list = construct_args
	if (istype(args_list) && args_list.len)
		loc = construct_args[1]
	else
		loc = construct_args
	..()

var/list/excluded_vars = list("animate_movement", "contents", "loc", "locs", "parent_type", "vars", "verbs", "type")
var/list/pooledvariables = list()
//thanks to clusterfack @ /vg/station for these two procs
/datum/proc/createVariables(var/list/excluded)
	pooledvariables[type] = new/list()
	var/list/all_excluded = excluded_vars + excluded

	for (var/key in vars)
		if (key in all_excluded)
			continue
		pooledvariables[type][key] = initial(vars[key])

/datum/proc/ResetVars(var/list/excluded = list())
	if (!pooledvariables[type])
		createVariables(excluded)

	for (var/key in pooledvariables[type])
		vars[key] = pooledvariables[type][key]

/atom/movable/ResetVars()
	..()
	loc = null
	contents = initial(contents) //something is really wrong if this object still has stuff in it by this point

/image/ResetVars()
	..()
	loc = null

#undef ATOM_POOL_COUNT
#undef DATUM_POOL_TOTAL_COUNT
