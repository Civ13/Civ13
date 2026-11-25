// Carriages (code/game/objects/structures/carriage.dm and
// code/modules/craft/carriage_papers.dm): the team's pull and pace, the
// footprint and team lane, boarding, harness and cargo seats, steps and what
// stops them, turning, hunger, the papers and the lock on the reins, getting
// off and a destroyed carriage. Steps are driven by calling do_move() as the
// movement timer would; tests/carriage_glide/ride.py drives the real timer
// and the glide in a full game.
/world
	hub = ""
	hub_password = ""
	maxx = 60
	maxy = 60
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/carriage_probe/New()
	return
var/carriage_failures = 0
var/carriage_checks = 0
var/carriage_runtime_error = FALSE
/proc/carriage_check(condition, label)
	carriage_checks++
	if (!condition)
		carriage_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	carriage_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

// Nobody has a client in the fixture; the drivers are awake all the same.
/mob/living/human/carriage_probe/ssd_check()
	return FALSE

var/carriage_owners_about = FALSE
/datum/craft_register/carriage_probe/owners_online()
	return party ? carriage_owners_about : FALSE

/proc/carriage_ground()
	var/area/A = get_area(locate(1, 1, 1))
	A.location = AREA_OUTSIDE
	for (var/turf/T in block(locate(1, 1, 1), locate(world.maxx, world.maxy, 1)))
		T.ChangeTurf(/turf/floor/plating/road, FALSE, FALSE)

/proc/carriage_person(x, y, char_name, faction = "Reds")
	var/mob/living/human/carriage_probe/H = new(locate(x, y, 1))
	H.real_name = char_name
	H.name = char_name
	H.civilization = faction
	return H

/proc/carriage_step(obj/structure/vehicle/carriage/C)
	C.moving = TRUE
	C.next_step = 0
	. = C.do_move(C.facing)
	C.moving = FALSE

/proc/carriage_glides_together(obj/structure/vehicle/carriage/C)
	var/datum/carriage_glide_lease/lease = C.carriage_glide
	if (!lease)
		return FALSE
	for (var/atom/movable/A in C.everything_aboard())
		if (!(A in lease.members) || A.glide_size != C.glide_size)
			return FALSE
	return TRUE

/proc/carriage_pure_checks()
	var/mob/living/simple_animal/horse/horse = new(locate(2, 2, 1))
	var/mob/living/simple_animal/cattle/cow/cow = new(locate(3, 2, 1))
	var/mob/living/simple_animal/cattle/cow/calf = new(locate(4, 2, 1))
	calf.calf = TRUE
	carriage_check(draft_animal_pull(horse) == 2 && draft_animal_pull(cow) == 1 && draft_animal_pull(calf) == 0, "a horse pulls 2, an ox or cow 1, a calf nothing")
	horse.simplehunger = 100
	carriage_check(draft_animal_pull(horse) == 1, "a starving horse pulls at half strength")
	carriage_check(is_draft_animal(horse) && is_draft_animal(cow) && !is_draft_animal(calf), "calves are not draft animals")
	carriage_check(carriage_top_gear(1) == 1 && carriage_top_gear(2) == 2 && carriage_top_gear(3) == 2 && carriage_top_gear(4) == 3 && carriage_top_gear(0) == 0, "oxen walk, one horse trots, two canter")
	carriage_check(carriage_step_delay(1, 0.5) == 7 && carriage_step_delay(3, 1) == 2.2 && carriage_step_delay(1, 2) == 14, "load past the team's capacity slows each gear in proportion")
	var/list/ns = carriage_cells(10, 10, 1, NORTH, 0)
	var/list/ew = carriage_cells(10, 10, 1, EAST, 2)
	carriage_check(ns.len == 6 && ns.Find(locate(11, 12, 1)) && !ns.Find(locate(12, 10, 1)), "facing north the footprint is two wide and three long")
	carriage_check(ew.len == 10 && ew.Find(locate(12, 11, 1)) && ew.Find(locate(14, 10, 1)) && !ew.Find(locate(15, 10, 1)), "facing east it is three long and two wide, with two tiles of lane ahead")
	carriage_check(isnull(carriage_cells(59, 10, 1, EAST, 0)), "a footprint off the map is no footprint")
	var/list/p = carriage_local_point(SOUTH, 96, 0)
	var/list/q = carriage_local_point(WEST, 96, 0)
	carriage_check(p[1] == 64 && p[2] == 0 && q[1] == 0 && q[2] == 0, "the front left corner faces the way the carriage does")
	qdel(horse)
	qdel(cow)
	qdel(calf)

/proc/carriage_checks()
	carriage_ground()
	carriage_pure_checks()

	// ---- A new carriage ----
	var/obj/structure/vehicle/carriage/C = new(locate(20, 30, 1))
	carriage_check(C.facing == SOUTH && C.dir == SOUTH && C.bound_width == 64 && C.bound_height == 96, "a new carriage faces south on a 2x3 footprint")
	carriage_check(istype(C.dwheel, /obj/item/vehicleparts/wheel/rope) && C.dwheel.loc == C && C.dwheel.origin == C && isnull(C.axis), "it keeps its reins and needs no axis")

	// ---- Boarding ----
	var/mob/living/human/carriage_probe/ann = carriage_person(19, 31, "Ann")
	var/mob/living/human/carriage_probe/bob = carriage_person(19, 30, "Bob", "Blues")
	carriage_check(C.Adjacent(ann) && !C.Adjacent(carriage_person(17, 31, "Far")), "anyone beside any tile of it is next to it")
	carriage_check(C.take_reins(ann) && C.driver == ann && ann.driver_vehicle == C && ann.buckled == C && ann.get_active_hand() == C.dwheel, "Ann takes the reins in her hand")
	carriage_check(ann.loc == C.loc && ann.dir == SOUTH && ann.pixel_y < 16, "and sits on the driver's bench at the front (the south end) ([ann.pixel_x],[ann.pixel_y])")
	C.take_seat(bob, C.free_seat())
	carriage_check(C.seats[1] == bob && bob.buckled == C && bob.loc == C.loc && (bob in C.ontop), "Bob takes the first seat")
	var/obj/structure/closet/crate/crate = new(locate(22, 30, 1))
	carriage_check(C.can_load(crate) && !C.can_load(C) && !C.can_load(new /obj/structure/vehicle/carriage(locate(40, 50, 1))), "a crate can be loaded; a carriage cannot")
	carriage_check(C.complete_load(crate, ann), "loose cargo loads into an available seat")
	carriage_check(C.seats[2] == crate && crate.anchored && !crate.density && (crate in C.ontop_o) && crate.layer > C.layer, "the crate rides in a seat, anchored and drawn above the bed")

	// State changes during a timed load must not move refused cargo or passengers.
	var/mob/living/human/carriage_probe/passenger = carriage_person(22, 31, "Waiting passenger")
	var/turf/passenger_origin = passenger.loc
	var/obj/structure/chair/chair = new(passenger_origin)
	chair.buckled_mob = passenger
	passenger.buckled = chair
	carriage_check(!C.complete_load(passenger, ann) && passenger.loc == passenger_origin && passenger.buckled == chair && chair.buckled_mob == passenger, "loading preserves a passenger's other seat")
	passenger.buckled = null
	passenger.anchored = TRUE
	carriage_check(!C.complete_load(passenger, ann) && passenger.loc == passenger_origin, "loading leaves an anchored passenger in place")
	chair.buckled_mob = null
	qdel(chair)
	qdel(passenger)
	var/list/extra_cargo = list()
	while (C.free_seat())
		var/obj/structure/closet/crate/extra = new(locate(22, 30, 1))
		extra_cargo += extra
		C.take_seat(extra, C.free_seat())
	var/obj/structure/closet/crate/waiting = new(locate(22, 30, 1))
	var/turf/cargo_origin = waiting.loc
	carriage_check(!C.complete_load(waiting, ann) && waiting.loc == cargo_origin && !(waiting in C.seats) && !waiting.anchored, "a full carriage leaves refused cargo at its origin")
	qdel(waiting)
	for (var/obj/structure/closet/crate/extra in extra_cargo)
		C.let_off(extra)
		qdel(extra)

	// ---- Harness ----
	carriage_check(C.team_pull() == 0 && C.load_ratio() == INFINITY, "with no team it has no pull")
	C.urge(ann)
	carriage_check(!C.gear && !C.moving, "and urging gets nowhere")
	var/mob/living/simple_animal/horse/h1 = new(locate(19, 29, 1))
	var/mob/living/simple_animal/horse/h2 = new(locate(20, 29, 1))
	var/mob/living/simple_animal/cattle/cow/ox = new(locate(21, 29, 1))
	// Bred horses roll a stamina that scales draft hunger (horse_breeding.dm);
	// 50 is the even cost these checks measure.
	h1.stamina = 50
	h2.stamina = 50
	var/turf/second_lane_row = locate(C.x + 1, C.y - 2, C.z)
	second_lane_row.ChangeTurf(/turf/wall, FALSE, FALSE)
	carriage_check(C.lane_depth(ox) == 1 && C.can_fit_lane(ox), "an incoming ox only needs the clear first row")
	carriage_check(C.lane_depth(h1) == 2 && !C.can_fit_lane(h1), "an incoming horse needs the blocked second row before it is hitched")
	second_lane_row = locate(C.x + 1, C.y - 2, C.z)
	second_lane_row.ChangeTurf(/turf/floor/plating/road, FALSE, FALSE)
	carriage_check(isnull(C.hitch_refusal(h1)) && C.can_fit_lane(h1), "a horse can go in harness with both rows clear")
	C.hitch(h1)
	carriage_check(findtext(C.hitch_refusal(ox), "Horses and oxen"), "an ox is not put in with horses")
	C.hitch(h2)
	carriage_check(C.team.len == 2 && h1.buckled == C && h2.buckled == C && h1.loc == C.loc && C.team_pull() == 4 && C.lane_depth() == 2, "two horses in harness pull 4 and stand in a two-tile lane")
	carriage_check(h1.pixel_y < 0 && h2.pixel_y < 0 && h1.pixel_x != h2.pixel_x && h1.dir == SOUTH, "they are drawn side by side ahead of it ([h1.pixel_x],[h1.pixel_y] / [h2.pixel_x],[h2.pixel_y])")
	carriage_check(C.overlays.len == 3 && C.pixel_x == -16, "one rank of harness is drawn ahead of it and a lap rug over each of the two seated people ([C.overlays.len])")
	carriage_check(findtext(C.status_text(), "Top pace: canter"), "it reads its best pace ([C.status_text()])")

	// ---- Urging and stepping ----
	C.urge(ann)
	carriage_check(C.gear == 1 && C.moving, "the reins start it at a walk")
	C.stopmovementloop()
	carriage_check(!C.gear && !C.moving, "and stopping it stands it")
	C.gear = 1
	var/hunger = h1.simplehunger
	var/turf/was = C.loc
	carriage_check(carriage_step(C) && C.loc == get_step(was, SOUTH), "a step takes it one tile south")
	carriage_check(ann.loc == C.loc && bob.loc == C.loc && crate.loc == C.loc && h1.loc == C.loc && h2.loc == C.loc, "everyone and everything aboard goes with it")
	carriage_check(carriage_glides_together(C), "and glides with it at one glide_size ([C.glide_size])")
	carriage_check(C.vehicle_m_delay >= 7 && C.vehicle_m_delay < 9, "a walk on a road takes about 7 ds a tile ([C.vehicle_m_delay])")
	carriage_check(h1.simplehunger == hunger - 1, "the work makes the horses hungry")
	var/obj/item/animal_tack/harness/tack = new(h2)
	hunger = h2.simplehunger
	C.gear = 3
	carriage_step(C)
	carriage_check(h2.simplehunger == hunger - 0.5, "a harness halves it")
	carriage_check(C.vehicle_m_delay < 3, "at a canter a step is quick ([C.vehicle_m_delay])")
	qdel(tack)
	h1.stamina = 80
	h2.stamina = 20
	carriage_check(h1.animal_draft_hunger_cost() < h2.animal_draft_hunger_cost(), "a hardier horse gets less hungry hauling")
	h1.stamina = 50
	h2.stamina = 50

	// ---- What stops it ----
	var/turf/wall_turf = locate(C.x + 1, C.y - 3, 1)
	wall_turf.ChangeTurf(/turf/wall, FALSE, FALSE)
	C.gear = 1
	was = C.loc
	carriage_check(!carriage_step(C) && C.loc == was, "a wall in the team's lane stops it")
	wall_turf.ChangeTurf(/turf/floor/plating/road, FALSE, FALSE)
	var/mob/living/human/carriage_probe/walker = carriage_person(C.x, C.y - 3, "Walker", "Blues")
	var/health = walker.health
	C.gear = 2
	carriage_check(!carriage_step(C) && walker.health < health, "a person in the way is run into and stops it")
	qdel(walker)
	var/turf/deep = locate(C.x, C.y - 3, 1)
	deep.ChangeTurf(/turf/floor/beach/water/deep, FALSE, FALSE)
	carriage_check(!carriage_step(C), "deep water stops it")
	new /obj/covers/wood(deep)
	carriage_check(carriage_step(C), "a bridge over it does not")

	// ---- Load ----
	var/fast = C.step_interval(C.loc, get_step(C.loc, SOUTH))
	for (var/i = 1 to 10)
		var/obj/item/stack/material/iron/bars = new(crate)
		bars.amount = 50
	var/heavy_ratio = C.load_ratio()
	carriage_check(heavy_ratio > 1 && C.step_interval(C.loc, get_step(C.loc, SOUTH)) > fast, "a crate full of iron slows the team ([heavy_ratio])")
	C.let_off(h2)
	carriage_check(C.team_pull() == 2 && !C.gear && !(h2 in C.team) && h2.buckled != C && h2.loc != C.loc, "taking a horse out of harness leaves one pulling and stands the carriage")
	carriage_check(C.load_ratio() > heavy_ratio, "and one horse feels the load more")
	h2.forceMove(locate(50, 50, 1))
	for (var/obj/item/I in crate)
		qdel(I)
	C.urge(ann)
	C.urge(ann)
	C.urge(ann)
	carriage_check(C.gear == 2, "one horse can only trot")
	C.stopmovementloop()

	// ---- Turning ----
	C.dir = EAST
	C.updatepassdir()
	carriage_check(C.facing == EAST && C.dir == EAST && C.bound_width == 96 && C.bound_height == 64, "turning east lays it out three long and two wide")
	carriage_check(ann.dir == EAST && h1.pixel_x > 64, "with the driver and the horse facing east ahead of it")
	var/turf/block = locate(C.x, C.y + 2, 1)
	block.ChangeTurf(/turf/wall, FALSE, FALSE)
	C.dir = NORTH
	C.updatepassdir()
	carriage_check(C.facing == EAST && C.dir == EAST, "it will not turn north into a wall")
	block.ChangeTurf(/turf/floor/plating/road, FALSE, FALSE)
	C.gear = 3
	C.dir = WEST
	C.updatepassdir()
	carriage_check(C.facing == EAST, "nor turn round at a canter")
	C.gear = 1
	C.updatepassdir()
	C.dir = WEST
	C.updatepassdir()
	carriage_check(C.facing == WEST && C.bound_width == 96, "at a walk it can")
	C.gear = 0

	// ---- Papers ----
	var/datum/craft/vehicle/carriage/craft = C.carriage_craft()
	carriage_check(craft && craft == C.carriage_craft() && (craft in vehicle_crafts) && !(craft in crafts), "its craft is made once and kept off the ships' list")
	carriage_check(craft.body.placed() && craft.body.cells().len == 6 && craft.body.heading() == WEST, "its body is its footprint, facing as it does")
	craft.register = new /datum/craft_register/carriage_probe
	var/datum/craft_register/R = craft.register
	craft.papers_action(ann, R, "Register it to Reds", C.loc)
	carriage_check(R.party == party_train_faction_party("Reds") && R.role_of(ann) == CRAFT_ROLE_CAPTAIN, "Ann registers it to the Reds")
	var/list/titles = craft.role_titles(R)
	carriage_check(titles["coachman"] == CRAFT_ROLE_HELMSMAN && titles["master"] == CRAFT_ROLE_CAPTAIN, "its roles are a carriage's")
	carriage_check(findtext(craft.fleet_text(ann, get_turf(C)), "here"), "it is on the Reds' vehicle list ([craft.fleet_text(ann, get_turf(C))])")
	carriage_owners_about = FALSE
	C.let_off(ann)
	C.take_reins(bob)
	carriage_check(C.driver == bob && !C.carriage_papers_allow(bob), "with no owner about the team will not go for a stranger")
	C.urge(bob)
	carriage_check(!C.gear, "so his urging does nothing")
	R.set_role("Bob", CRAFT_ROLE_HELMSMAN)
	C.urge(bob)
	carriage_check(C.gear == 1, "signed on as coachman, he drives it")
	C.stopmovementloop()
	craft.rename("Mail Coach")
	C.before_save()
	carriage_check(length(C.register_state) && C.name == "Mail Coach", "the carriage saves its papers and takes its name")
	qdel(craft)
	C.craft = null
	C.after_load()
	var/datum/craft/vehicle/carriage/craft2 = C.carriage_craft(FALSE)
	carriage_check(craft2 && craft2 != craft && craft2.register && craft2.register.crew["Bob"] == CRAFT_ROLE_HELMSMAN && craft2.name == "Mail Coach", "a load brings back its papers, crew and name")

	// ---- Getting off ----
	C.let_off(bob)
	carriage_check(!C.driver && !bob.buckled && !bob.driver && bob.driver_vehicle == null && C.dwheel.loc == C && bob.pixel_x == 0 && bob.loc != C.loc && C.Adjacent(bob), "getting off leaves the reins and puts him on his feet beside it")
	var/mob/living/human/carriage_probe/cat = carriage_person(C.x - 1, C.y, "Cat")
	C.take_seat(cat, C.free_seat())
	cat.death()
	C.check_aboard()
	carriage_check(cat in C.seats, "a passenger who dies stays in the seat")
	h1.death()
	C.take_reins(ann)
	C.gear = 1
	carriage_check(!carriage_step(C) && !(h1 in C.team) && h1.buckled != C, "a dead horse is cut loose and the carriage stops")

	// ---- Destroyed ----
	var/datum/craft/vehicle/carriage/craft3 = C.carriage_craft()
	qdel(C)
	carriage_check(!ann.buckled && !ann.driver && !crate.anchored && crate.density && !(craft3 in vehicle_crafts), "a destroyed carriage lets everyone off and takes its papers with it")

// Hand carts (code/game/objects/structures/hand_cart.dm): the handles turn
// toward the puller and the load sets how much the cart slows them.
/proc/carriage_cart_checks()
	var/mob/living/human/carriage_probe/pat = carriage_person(40, 40, "Pat")
	var/obj/structure/closet/crate/cart/wooden/cart = new(locate(41, 40, 1))
	var/obj/structure/closet/crate/plain = new(locate(45, 45, 1))
	carriage_check(cart.dir == WEST, "a new cart shows its handles to the west as before")
	var/empty = cart.drag_delay(pat)
	carriage_check(empty > 0 && empty < plain.drag_delay(pat), "an empty cart drags more easily than a crate")
	for (var/i in 1 to 4)
		var/obj/item/stack/material/wood/W = new(cart)
		W.amount = 50
	var/loaded = cart.drag_delay(pat)
	carriage_check(loaded > empty, "a loaded cart drags harder than an empty one")
	for (var/i in 1 to 40)
		var/obj/item/stack/material/wood/W = new(cart)
		W.amount = 50
	carriage_check(cart.drag_delay(pat) == 3, "a cart's drag is capped")
	cart.pulledby = pat
	pat.forceMove(locate(39, 40, 1))
	cart.Move(locate(40, 40, 1), WEST)
	carriage_check(cart.dir == WEST, "pulled west, the handles point west")
	pat.forceMove(locate(39, 41, 1))
	cart.Move(locate(39, 40, 1), WEST)
	carriage_check(cart.dir == NORTH, "the handles turn north toward the puller")
	pat.forceMove(locate(41, 41, 1))
	cart.Move(locate(40, 40, 1), EAST)
	carriage_check(cart.dir == EAST, "a puller off to the side leaves the handles along the step")
	pat.forceMove(locate(40, 39, 1))
	cart.Move(locate(40, 40, 1), SOUTH)
	carriage_check(cart.dir == EAST, "a cart that did not move keeps its handles")
	cart.pulledby = null

// Hitched carts (code/game/objects/structures/cart_hitch.dm): a cart trails a
// horse into the tile it leaves and rolls behind a carriage's rear, its load
// slows the leader, and it comes loose when it cannot follow. A seated
// passenger takes the reins from a driver who cannot drive.
/proc/carriage_hitch_checks()
	var/mob/living/simple_animal/horse/mare = new(locate(10, 10, 1))
	var/obj/structure/closet/crate/cart/wooden/cart = new(locate(11, 10, 1))
	carriage_check(isnull(cart.hitch_refusal(mare)) && cart.hitch_to(mare), "a cart beside a horse hitches to it")
	carriage_check(mare.hitched_cart == cart && cart.hitched_to == mare && cart.loc == locate(11, 10, 1) && cart.dir == WEST, "it stays put with its handles toward the horse")
	mare.forceMove(locate(9, 10, 1))
	carriage_check(cart.loc == locate(10, 10, 1) && cart.dir == WEST, "the horse steps west and the cart rolls into the tile it left")
	mare.forceMove(locate(9, 11, 1))
	carriage_check(cart.loc == locate(10, 10, 1) && cart.dir == WEST, "a step that keeps it beside the horse leaves it there, handles to the side it is on")
	mare.forceMove(locate(9, 12, 1))
	carriage_check(cart.loc == locate(9, 11, 1) && cart.dir == NORTH, "a step away pulls it after the horse")
	carriage_check(!cart.Move(locate(10, 11, 1), EAST) && cart.loc == locate(9, 11, 1), "nobody can push or pull a hitched cart away")
	var/empty_drag = mare.hitch_drag()
	carriage_check(empty_drag > 0 && empty_drag == cart.drag_delay(mare) / 2, "the cart slows the horse by its drag over the horse's pull ([empty_drag])")
	for (var/i in 1 to 4)
		var/obj/item/stack/material/wood/W = new(cart)
		W.amount = 50
	carriage_check(mare.hitch_drag() > empty_drag, "a loaded cart slows the horse more")
	var/obj/structure/closet/crate/cart/wooden/other = new(locate(8, 12, 1))
	carriage_check(findtext(other.hitch_refusal(mare), "already pulls a cart"), "a horse pulls one cart at a time")
	var/obj/structure/vehicle/carriage/far = new(locate(40, 10, 1))
	carriage_check(findtext(far.hitch_refusal(mare), "cart hitched behind it"), "a horse with a cart cannot also go in harness")
	mare.forceMove(locate(9, 20, 1))
	carriage_check(isnull(cart.hitched_to) && isnull(mare.hitched_cart) && cart.loc == locate(9, 11, 1), "a cart left far behind comes loose")
	mare.forceMove(locate(9, 12, 1))
	carriage_check(cart.hitch_to(mare), "it can be hitched again")
	cart.unhitch()
	carriage_check(isnull(cart.hitched_to) && cart.Move(get_step(cart, EAST), EAST), "unhitched, it can be pulled again")
	carriage_check(cart.hitch_to(mare), "and hitched once more")
	mare.stat = DEAD
	mare.forceMove(locate(9, 14, 1))
	carriage_check(isnull(cart.hitched_to), "a dead horse lets the cart go")

	// ---- Behind a carriage ----
	carriage_ground()
	var/obj/structure/vehicle/carriage/C = new(locate(30, 30, 1))
	var/mob/living/human/carriage_probe/dee = carriage_person(29, 31, "Dee")
	var/mob/living/human/carriage_probe/eli = carriage_person(29, 30, "Eli")
	C.take_reins(dee)
	C.take_seat(eli, C.free_seat())
	var/mob/living/simple_animal/horse/h1 = new(locate(30, 29, 1))
	var/mob/living/simple_animal/horse/h2 = new(locate(31, 29, 1))
	C.hitch(h1)
	C.hitch(h2)
	var/obj/structure/closet/crate/cart/wooden/wagon = new(locate(32, 34, 1))
	carriage_check(findtext(wagon.hitch_refusal(C), "round behind"), "a cart off to the side of the rear is told to come round")
	wagon.forceMove(locate(31, 34, 1))
	var/before = C.load_weight()
	carriage_check(isnull(wagon.hitch_refusal(C)) && wagon.hitch_to(C), "a cart just behind the carriage hitches to it")
	carriage_check(wagon.loc == locate(30, 33, 1) && wagon.pixel_x == 16 && wagon.dir == SOUTH && C.hitched_cart == wagon, "it rolls centred behind the rear wheels, handles toward the carriage")
	carriage_check(C.load_weight() == before + 30 + wagon.cart_load(), "the team draws the cart's weight too")
	C.gear = 1
	carriage_check(carriage_step(C) && C.loc == locate(30, 29, 1) && wagon.loc == locate(30, 32, 1), "a step south takes the cart one tile south behind it")
	carriage_check(C.try_turn(EAST) && C.facing == EAST && wagon.loc == locate(29, 29, 1) && wagon.pixel_y == 16 && wagon.pixel_x == 0 && wagon.dir == EAST, "turning east swings the cart round behind the new rear")
	carriage_check(carriage_step(C) && C.loc == locate(31, 29, 1) && wagon.loc == locate(30, 29, 1), "and it follows the next step east")
	var/turf/behind_north = locate(31, 28, 1)
	behind_north.ChangeTurf(/turf/wall, FALSE, FALSE)
	carriage_check(!C.try_turn(NORTH) && C.facing == EAST && wagon.hitched_to == C, "a turn is refused when the cart would have nowhere to go")

	// ---- Taking the reins ----
	dee.stat = UNCONSCIOUS
	carriage_check(!C.driver_ready(), "a driver knocked out cannot drive")
	C.attack_hand(eli)
	carriage_check(C.driver == eli && eli.driver_vehicle == C && eli.get_active_hand() == C.dwheel && (dee in C.seats) && !dee.driver && dee.buckled == C, "a seated passenger takes the reins and the driver moves to that seat")
	dee.stat = CONSCIOUS
	carriage_check(!C.take_reins_from_driver(dee) && C.driver == eli, "a passenger cannot take the reins from a driver who is driving")
	C.driver_died(eli)
	carriage_check(isnull(C.driver) && C.dwheel.loc == C && !eli.buckled, "a driver who dies is let off and leaves the reins")
	carriage_check(C.retake_controls(dee) && C.driver == dee && dee.get_active_hand() == C.dwheel && !(dee in C.seats), "a seated passenger takes the reins when nobody drives")

	qdel(C)
	carriage_check(isnull(wagon.hitched_to) && wagon.pixel_x == 0 && wagon.pixel_y == 0, "a destroyed carriage lets its cart go")

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.stat_set_event = new
		GLOB.global_listen_count = list()
		GLOB.event_sources_count = list()
		GLOB.event_listen_count = list()
		movementMachine = new
		map = new /obj/map_metadata/carriage_probe
		if (!all_species.len)
			makeDatumRefLists()
		carriage_checks()
		carriage_cart_checks()
		carriage_hitch_checks()
	catch(var/exception/e)
		carriage_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "checks" = carriage_checks, "failures" = carriage_failures, "runtime_error" = carriage_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
