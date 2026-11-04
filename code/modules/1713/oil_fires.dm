/obj/structure/oil_spring
	name = "petroleum spring"
	desc = "A hole on the ground where petroleum reaches the surface. Sticky!"
	icon = 'icons/obj/watercloset.dmi'
	icon_state = "oil_spring1"
	anchored = TRUE
	var/counter = 1
	var/timeout = 0
	var/tmp/refill_pending = FALSE
	flammable = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE

/obj/structure/oil_spring/attackby(obj/item/O as obj, mob/living/user as mob)
	if (counter <= 0)
		to_chat(user, "<span class='warning'>\The [src] is dry!</span>")
		if (counter < 0)
			counter = 0
		return

	if (istype(O, /obj/item/weapon/reagent_containers))
		var/obj/item/weapon/reagent_containers/RG = O
		if (istype(RG) && RG.is_open_container() && do_after(user, 15, src, check_for_repeats = FALSE))
			if (counter > 0)
				RG.reagents.add_reagent("petroleum", min(RG.volume - RG.reagents.total_volume, 10))
				user.visible_message("<span class='notice'>[user] fills \the [RG] using \the [src].</span>", "<span class='notice'>You fill \the [RG] using \the [src].</span>")
				playsound(loc, 'sound/effects/watersplash.ogg', 100, TRUE)
				user.setClickCooldown(20)
				counter--
				update_icon()
				timeout = world.time + 600
				refill()
				return

	else if (istype(O, /obj/item/flashlight/torch))
		var/obj/item/flashlight/torch/OO = O
		if (counter > 0 && OO.on)
			user.visible_message("<span class = 'red'>[user.name] sets \the [src] on fire!</span>", "<span class = 'red'>You set \the [src] on fire!</span>")
			counter = 0
			timeout = world.time + 1800
			refill()
			oil_explode()
			update_icon()
			qdel(O)
			return

/obj/structure/oil_spring/update_icon()
	..()
	if (counter > 0)
		icon_state = "oil_spring1"
	else
		icon_state = "oil_spring0"

/obj/structure/oil_spring/proc/refill()
	if (refill_pending || !isturf(loc))
		return
	if (world.time >= timeout)
		if (counter < 1)
			counter++
			update_icon()
			return
	else
		refill_pending = TRUE
		spawn(50)
			refill_pending = FALSE
			if (isturf(loc))
				refill()

/obj/structure/oil_spring/get_saved_vars()
	var/list/saved = ..()
	saved -= list("refill_pending", "timeout")
	return saved

/obj/structure/oil_spring/after_load()
	. = ..()
	refill_pending = FALSE
	if (counter < 1)
		timeout = world.time + 600
		refill()

/obj/structure/oil_spring/proc/oil_explode()
	playsound(loc, 'sound/effects/Explosion2.ogg', 100, FALSE, 12)
	for (var/mob/living/LS1 in locate(x,y,z))
		LS1.adjustBurnLoss(35)
		LS1.fire_stacks += rand(8,10)
		LS1.IgniteMob()
	new/obj/effect/fire(locate(x,y,z))

	for (var/mob/living/LS2 in locate(x-1,y,z))
		LS2.adjustBurnLoss(35)
		LS2.fire_stacks += rand(5,7)
		LS2.IgniteMob()
	new/obj/effect/fire(locate(x-1,y,z))

	for (var/mob/living/LS3 in locate(x+1,y,z))
		LS3.adjustBurnLoss(35)
		LS3.fire_stacks += rand(5,7)
		LS3.IgniteMob()
	new/obj/effect/fire(locate(x+1,y,z))

	for (var/mob/living/LS21 in locate(x,y+1,z))
		LS21.adjustBurnLoss(35)
		LS21.fire_stacks += rand(8,10)
		LS21.IgniteMob()
	new/obj/effect/fire(locate(x,y+1,z))

	for (var/mob/living/LS22 in locate(x-1,y+1,z))
		LS22.adjustBurnLoss(35)
		LS22.fire_stacks += rand(5,7)
		LS22.IgniteMob()
	new/obj/effect/fire(locate(x-1,y+1,z))

	for (var/mob/living/LS23 in locate(x+1,y+1,z))
		LS23.adjustBurnLoss(35)
		LS23.fire_stacks += rand(5,7)
		LS23.IgniteMob()
	new/obj/effect/fire(locate(x+1,y+1,z))

	for (var/mob/living/LS31 in locate(x,y-1,z))
		LS31.adjustBurnLoss(35)
		LS31.fire_stacks += rand(8,10)
		LS31.IgniteMob()
	new/obj/effect/fire(locate(x,y-1,z))

	for (var/mob/living/LS32 in locate(x-1,y-1,z))
		LS32.adjustBurnLoss(35)
		LS32.fire_stacks += rand(5,7)
		LS32.IgniteMob()
	new/obj/effect/fire(locate(x-1,y-1,z))

	for (var/mob/living/LS33 in locate(x+1,y-1,z))
		LS33.adjustBurnLoss(35)
		LS33.fire_stacks += rand(5,7)
		LS33.IgniteMob()
	new/obj/effect/fire(locate(x+1,y-1,z))
	return


// Fire has no durable continuation codec. Save/import requires quiescence of
// these actual callback rows, including an executing or failed row whose fire
// was retired. Retirement makes pending rows inert before removing the guard.
var/global/list/nomads_fire_callbacks = list()
/datum/nomads_fire_callback
	should_save = FALSE
	var/obj/effect/fire/owner
	var/running = FALSE
	var/cancelled = FALSE
	var/failed = FALSE
/datum/nomads_fire_callback/New(obj/effect/fire/target)
	owner = target
	nomads_fire_callbacks[src] = TRUE
	owner.nomads_pending_callbacks[src] = TRUE
/datum/nomads_fire_callback/proc/complete()
	if(failed) return
	nomads_fire_callbacks -= src
	if(owner) owner.nomads_pending_callbacks -= src
	owner = null
/datum/nomads_fire_callback/proc/cancel()
	cancelled = TRUE
	if(!running && !failed) complete()
/datum/nomads_fire_callback/proc/schedule(delay, method, list/arguments)
	spawn(delay) invoke(method, arguments)
/datum/nomads_fire_callback/proc/invoke(method, list/arguments)
	if(failed) return
	while(!cancelled && owner && !isDeleted(owner) && persistence_save_in_progress && map && map.uses_durable_metadata())
		sleep(1)
	if(cancelled || !owner || isDeleted(owner))
		complete()
		return
	running = TRUE
	try
		call(owner, method)(arglist(arguments))
	catch(var/exception/E)
		running = FALSE
		failed = TRUE
		if(map && map.uses_durable_metadata()) map.durable_nomads_fail("fire callback failure")
		log_debug("Fire callback [method] requires recovery: [E]")
		return // Retain the failed row after retirement; do not admit a partial save.
	running = FALSE
	complete()

/obj/effect/fire
	name = "fire"
	icon = 'icons/effects/effects.dmi'
	icon_state = "burning_fire2"
	layer = TURF_LAYER+2.2
	anchored = TRUE
	density = FALSE
	var/timer = 180
	var/runonce = FALSE
	var/tmp/list/nomads_pending_callbacks = list()
/obj/effect/fire/New()
	var/datum/nomads_fire_callback/construction = new(src)
	construction.running = TRUE
	try
		..()
		icon = 'icons/effects/effects.dmi'
		icon_state = "burning_fire2"
		alpha = 230
		fire_defer(30, "fire_start_burning")
		set_light(3)
		light_color = "#FF9900"
		fire_defer(timer, "fire_expire")
	catch(var/exception/E)
		construction.failed = TRUE
		construction.running = FALSE
		if(map && map.uses_durable_metadata()) map.durable_nomads_fail("fire construction failure")
		throw E
	construction.running = FALSE
	construction.complete()
/obj/effect/fire/persistence_runtime_var(key)
	return key == "nomads_pending_callbacks" || ..()
/obj/effect/fire/get_saved_vars()
	if(map && map.uses_durable_metadata()) throw EXCEPTION("Fire requires quiescence before durable export")
	return ..()
/obj/effect/fire/Destroy()
	for(var/datum/nomads_fire_callback/C in nomads_pending_callbacks.Copy()) C.cancel()
	return ..()
/obj/effect/fire/proc/fire_defer(delay, method, list/arguments = list())
	if(isDeleted(src) || !loc) return
	var/datum/nomads_fire_callback/C = new(src)
	C.schedule(delay, method, arguments)
/obj/effect/fire/proc/fire_start_burning()
	if(!runonce)
		burningproc_work()
		runonce = TRUE
/obj/effect/fire/proc/fire_expire()
	set_light(0)
	qdel(src)
/obj/effect/fire/proc/fire_blood_cleanup(obj/effect/decal/cleanable/blood/O)
	if(O) qdel(O)

/obj/effect/fire/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/reagent_containers))
		var/obj/item/weapon/reagent_containers/CT = W
		for (var/datum/reagent/R in CT.reagents.reagent_list)
			if (istype(R, /datum/reagent/water))
				user.visible_message("[user] empties \the [CT] into the fire!", "You empty \the [CT] into the fire!")
				if (prob(max(R.volume, 100)))
					qdel(src)
					visible_message("The fire is extinguished!")
				CT.reagents.clear_reagents()

/obj/effect/fire/proc/burningproc()
	if(isDeleted(src) || !loc) return
	var/datum/nomads_fire_callback/C = new(src)
	C.invoke("burningproc_work", list())
/obj/effect/fire/proc/burningproc_work()
//this tile
	if (prob(3))
		new/obj/effect/effect/smoke(loc)
	var/area/A = get_area(get_turf(src))
	if (!A)
		return
	if (A.weather == WEATHER_WET)
		if (A.climate != "semiarid" || A.climate != "jungle" || A.climate != "desert" || A.climate != "savanna" || season == "WINTER" || season == "SPRING")
			if (prob(30))
				qdel(src)
	if (A.weather == WEATHER_EXTREME)
		qdel(src)
	if(isDeleted(src) || !loc) return

	for (var/mob/living/L in src.loc)
		L.adjustBurnLoss(rand(20, 40))
		if (prob(40))
			L.fire_stacks += rand(1,2)
		L.IgniteMob()

	for (var/obj/effect/decal/cleanable/blood/O in src.loc)
		fire_defer(50, "fire_blood_cleanup", list(O))

	for (var/obj/OB in src.loc)
		if (prob(35) && !istype(OB, /obj/effect/decal/cleanable/blood) && OB.flammable)
			OB.fire_act(1200)

	for (var/obj/effect/fire/OTH in src.loc)
		if (OTH != src)
			qdel(OTH)

	for (var/obj/structure/oil_spring/OS in src.loc)
		if (OS.counter > 0)
			OS.oil_explode()
			OS.counter = 0

//burn floors
	if (istype(get_turf(src), /turf/floor/grass))
		var/turf/T = get_turf(src)
		T.ChangeTurf(/turf/floor/dirt/burned)
	else if (istype(get_turf(src), /turf/floor/wood))
		var/turf/T = get_turf(src)
		T.ChangeTurf(/turf/floor/wood_broken)

//bordering tiles
	for (var/obj/effect/decal/cleanable/blood/OL in orange(1, src))
		if (istype(OL, /obj/effect/decal/cleanable/blood/oil))
			if (prob(35))
				new/obj/effect/fire(OL.loc)
		if (istype(OL, /obj/effect/decal/cleanable/blood/tracks) && OL.color == "#030303")
			if (prob(35))
				new/obj/effect/fire(OL.loc)

	for (var/turf/floor/grass/GR in orange(1, src))
		var/blocked = 0
		for (var/obj/covers/CV in GR)
			if (CV.flammable == 0)
				blocked = 1
		for (var/obj/structure/vehicleparts/frame/F in GR)
			var/found = FALSE
			for (var/obj/structure/vehicleparts/frame/F2 in src.loc)
				found = TRUE
			if (!found)
				blocked = 1
		if (prob(10) && !blocked)
			new/obj/effect/fire(GR)

	for (var/turf/floor/wood/WF in orange(1, src))
		if (prob(21))
			new/obj/effect/fire(WF)
	for (var/obj/covers/repairedfloor/RF in orange(1, src))
		if (prob(12))
			new/obj/effect/fire(RF)

//remove duplicates
	for (var/obj/effect/fire/OTH in src.loc)
		if (OTH != src)
			qdel(OTH)
	fire_defer(50, "burningproc_work")
	return

/obj/effect/decal/cleanable/blood/oil
	name = "oil"
	desc = "It's black and greasy."
	basecolor="#030303"

/obj/effect/decal/cleanable/blood/oil/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/flashlight/torch))
		var/obj/item/flashlight/torch/OO = W
		if (OO.on)
			user.visible_message("<span class = 'red'>[user.name] sets \the [src] on fire!</span>", "<span class = 'red'>You set \the [src] on fire!</span>")
			ignite_turf(src.loc, 18, 20)
			return

/obj/effect/decal/cleanable/blood/oil/dry()
	return

/obj/effect/decal/cleanable/blood/oil/streak
	random_icon_states = list("mgibbl1", "mgibbl2", "mgibbl3", "mgibbl4", "mgibbl5")
	amount = 2
