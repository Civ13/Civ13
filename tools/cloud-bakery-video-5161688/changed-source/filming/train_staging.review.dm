// Disposable Little Creek fixture ONLY; not included in any DME.
// Original (x,y,z=2) -> crop (x,y-89,z=1). Nothing here is activated.
#define CITY_RAIL_RELEASED TRUE
var/list/city_rails = list()
var/obj/structure/trains/locomotive/coal/city_train
var/mob/living/human/intro_actor/city_fireman
var/mob/living/human/intro_actor/city_brakeman
var/obj/item/stack/ore/coal/city_coal

/proc/city_stage_train()
	intro_check(CITY_RAIL_RELEASED, "rail staging held for reviewed preflight")
	intro_check(!city_train && !city_rails.len, "fresh railway staging")
	// Source coordinate x80..87,y143; preserve every authored underlying cell.
	for (var/tx in 80 to 87)
		var/turf/T = locate(tx, 54, 1)
		intro_check(T && !T.density, "rail turf present and not dense")
		for (var/atom/movable/A in T)
			intro_check(!A.density && !istype(A, /obj/structure/rails) && !istype(A, /obj/structure/trains), "rail staging has no dense atom or existing rail")
		var/obj/structure/rails/regular/horizontal/R = new(T)
		R.initialize()
		intro_check(R.loc == T && R.dir == EAST, "native horizontal rail staged")
		city_rails += R
	intro_check(city_rails.len == 8, "exact eight staged rails")
	city_train = new(locate(83, 54, 1))
	city_train.set_dir(EAST)
	city_train.initialize()
	intro_check(city_train && city_train.dir == EAST && !city_train.on && !city_train.automovement && !city_train.connected && city_train.fuel == 0, "staged idle locomotive")
	// Actor helper is from the held bakery fixture; both are scripted, not clients.
	city_fireman = bakery_actor(83, 55, "Fireman", /obj/item/clothing/under/civ4)
	city_brakeman = bakery_actor(85, 55, "Brakeman", /obj/item/clothing/under/civ1)
	city_coal = new(city_fireman.loc)
	city_coal.amount = 1
	bakery_pickup(city_fireman, city_coal)
	intro_check(city_fireman.get_active_hand() == city_coal && city_coal.amount == 1, "staged fireman holds one coal")
	intro_check(city_train.Adjacent(city_fireman), "fireman reachable before fueling")
	text2file(json_encode(list("phase" = "train_staged", "time" = world.time, "engine" = "\ref[city_train]", "fireman" = "\ref[city_fireman]", "brakeman" = "\ref[city_brakeman]", "x" = city_train.x, "y" = city_train.y, "z" = city_train.z, "rail_count" = city_rails.len, "health" = city_train.health)), "city-train-before.json")

/proc/city_preflight_train()
	intro_check(CITY_RAIL_RELEASED && city_train && city_coal, "rail action held or unstaged")
	var/engine_ref = "\ref[city_train]"
	var/coal_ref = "\ref[city_coal]"
	var/initial_health = city_train.health
	var/initial_fireman_health = city_fireman.health
	var/initial_brakeman_health = city_brakeman.health
	// Check both movement tiles immediately before starting; moving-atom density
	// and actor reachability are rechecked at runtime rather than inferred from DMM.
	for (var/tx in 84 to 85)
		var/turf/T = locate(tx, 54, 1)
		intro_check(T && !T.density && (locate(/obj/structure/rails) in T), "rail destination present")
		for (var/atom/movable/A in T)
			intro_check(!A.density || istype(A, /obj/structure/rails), "rail destination empty of dense atoms")
	intro_check(city_train.Adjacent(city_fireman) && city_fireman.get_active_hand() == city_coal, "fueling reach and custody")
	city_train.attackby(city_coal, city_fireman)
	intro_check(city_train.fuel == 15 && !city_fireman.get_active_hand() && (!city_coal || city_coal.gc_destroyed), "normal coal handler paid one coal")
	var/fueled_at = world.time
	city_train.attack_hand(city_fireman)
	intro_check(city_train.on && city_train.automovement, "normal locomotive start")
	var/started_at = world.time
	var/deadline = world.time + 40
	while (city_train.x < 85 && world.time < deadline)
		intro_check(city_train.y == 54 && city_train.z == 1 && city_train.dir == EAST && !city_train.connected, "same straight train during movement")
		sleep(1)
	intro_check(city_train.x == 85 && city_train.y == 54 && city_train.z == 1 && city_train.on && city_train.Adjacent(city_brakeman), "train arrived in braking reach")
	var/arrived_at = world.time
	city_train.attack_hand(city_brakeman)
	intro_check(!city_train.on && !city_train.automovement, "normal locomotive stop")
	var/stopped_at = world.time
	sleep(15)
	intro_check(city_train.x == 85 && city_train.y == 54 && !city_train.on && !city_train.automovement, "train settled")
	intro_check(city_train.health == initial_health && city_fireman.health == initial_fireman_health && city_brakeman.health == initial_brakeman_health, "train action caused no injury")
	text2file(json_encode(list("phase" = "train_complete", "time" = world.time, "engine" = engine_ref, "coal" = coal_ref, "fireman" = "\ref[city_fireman]", "brakeman" = "\ref[city_brakeman]", "fueled_at" = fueled_at, "started_at" = started_at, "arrived_at" = arrived_at, "stopped_at" = stopped_at, "x" = city_train.x, "y" = city_train.y, "z" = city_train.z, "rail_count" = city_rails.len, "on" = city_train.on, "automovement" = city_train.automovement, "health" = city_train.health, "fuel" = city_train.fuel)), "city-train-after.json")
