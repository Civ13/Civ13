
/*
/tg/station13 /atom/movable Pool:
---------------------------------
By RemieRichards

Creation/Deletion is laggy, so let's reduce reuse and recycle!

*/
#define ATOM_POOL_COUNT 100
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
		if (!GlobalPool[get_type])
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
		D.ResetVars()
		D.Prepare(second_arg)
		return D
	return FALSE

/proc/PlaceInPool(var/datum/D)
	if (!istype(D))
		return

	if (length(GlobalPool[D.type]) > ATOM_POOL_COUNT)
		#ifdef DEBUG_ATOM_POOL
		to_chat(world, text("DEBUG_DATUM_POOL: PlaceInPool([]) exceeds []. Discarding.", D.type, ATOM_POOL_COUNT))
		#endif
		if (processes.garbage)
			processes.garbage.AddTrash(D)
		else
			del(D)
		return

	if (D in GlobalPool[D.type])
		return

	if (!GlobalPool[D.type])
		GlobalPool[D.type] = list()

	GlobalPool[D.type] += D

	D.Destroy()
	D.ResetVars()

/proc/IsPooled(var/datum/D)
	if (isnull(GlobalPool[D.type]))
		return FALSE
	return TRUE

/datum/proc/Prepare(args)
	if (islist(args))
		New(arglist(args))
	else
		New(args)

/atom/movable/Prepare(args)
	var/list/args_list = args
	if (istype(args_list) && args_list.len)
		loc = args[1]
	else
		loc = args
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
