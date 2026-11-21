// Full-source probe: mechanisms (mechanisms.dm).
// Rope on a trigger ties a cord to a door, castle trapdoor, bell or rock drop
// within seven tiles (at most four), or cuts one; a lever opens what it is
// tied to when thrown and shuts it when thrown back; a pull cord toggles; a
// pressure plate pulls for strangers and large animals but not the setter's
// people; a tripwire alarm pulls its cords; a rock drop hurts whoever stands
// under it once and is hung up again by hand; a locked door holds.
/world
	hub = ""
	visibility = 0
	maxx = 16
	maxy = 16
	maxz = 2
	fps = 20
	turf = /turf/floor/plating/mechanisms_probe
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/mechanisms_probe/New()
	map = src

/turf/floor/plating/mechanisms_probe

var/mechanisms_probe_checks = 0
var/mechanisms_runtime = null

/world/Error(exception/e)
	if (!mechanisms_runtime)
		mechanisms_runtime = "runtime [e] ([e.file]:[e.line])"

/proc/mechanisms_assert(ok, label)
	mechanisms_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/mechanisms_actor(tx, ty, name)
	var/mob/living/human/H = new(locate(tx, ty, 1))
	H.canmove = TRUE
	H.stat = CONSCIOUS
	H.real_name = name
	H.name = name
	H.hand = 0
	H.a_intent = I_HELP
	return H

/proc/mechanisms_hands(mob/living/human/H, obj/item/active)
	H.drop_l_hand()
	H.drop_r_hand()
	if (active)
		H.put_in_r_hand(active)

// An agent character answers the next prompt with answer.
/proc/mechanisms_answer(mob/living/human/H, answer)
	var/datum/agent_character/C = agent_characters[H]
	if (!C)
		C = new /datum/agent_character
		agent_characters[H] = C
	C.pending_choice = answer
	C.pending_choice_until = world.time + 600

/proc/mechanisms_door(tx, ty)
	var/turf/N = locate(tx, ty + 1, 1)
	var/turf/S = locate(tx, ty - 1, 1)
	N.density = TRUE
	S.density = TRUE
	var/obj/structure/simple_door/D = new /obj/structure/simple_door/key_door/anyone/wood(locate(tx, ty, 1))
	sleep(10)
	return D

/proc/mechanisms_probe_run()
	config = new
	config.webhook_can_fire = FALSE
	makeDatumRefLists()
	GLOB.all_observable_events = list()
	GLOB.global_listen_count = list()
	GLOB.event_sources_count = list()
	GLOB.event_listen_count = list()
	GLOB.moved_event = new
	GLOB.dir_set_event = new
	GLOB.destroyed_event = new
	GLOB.stat_set_event = new
	GLOB.name_set_event = new
	movementMachine = new
	map = new /obj/map_metadata/mechanisms_probe

	var/mob/living/human/builder = mechanisms_actor(4, 4, "Builder")
	builder.civilization = "Riverfolk"
	var/obj/structure/simple_door/door = mechanisms_door(8, 4)
	var/obj/structure/bell/bell = new(locate(4, 9, 1))
	var/obj/structure/rock_drop/drop = new(locate(10, 10, 1))
	var/obj/structure/castle_trapdoor/trap = new(locate(12, 4, 1))
	var/obj/structure/mechanism/lever/lever = new(locate(5, 4, 1))

	// What a cord can work.
	mechanisms_assert(mechanism_actuatable(door) && mechanism_actuatable(bell) && mechanism_actuatable(drop) && mechanism_actuatable(trap), "actuatable_kinds")
	mechanisms_assert(!mechanism_actuatable(lever) && !mechanism_actuatable(builder), "triggers_not_actuators")
	mechanisms_assert(mechanism_actuator_on(get_turf(door)) == door, "found_on_tile")
	mechanisms_assert(mechanism_offset_words(lever, get_turf(bell)) == "5 north, 1 west", "offset_words")

	// Tying a cord with rope, as an agent answering the prompt.
	var/obj/item/stack/material/rope/rope = new(null, 10)
	mechanisms_hands(builder, rope)
	mechanisms_answer(builder, "Tie a cord to [door.name] (3 east)")
	mechanism_rope_on_trigger(lever, rope, builder)
	mechanisms_assert(lever.links == "3,0" && rope.amount == 9, "tied_door")
	mechanisms_answer(builder, "Tie a cord to [trap.name] (7 east)")
	mechanism_rope_on_trigger(lever, rope, builder)
	mechanisms_assert(lever.links == "3,0;7,0" && rope.amount == 8, "tied_trapdoor")

	// Thrown, the lever opens the door and drops the trapdoor; thrown back, it shuts them.
	lever.attack_hand(builder)
	sleep(15)
	mechanisms_assert(lever.thrown && door.state && !door.density && trap.open, "lever_thrown_opens")
	lever.next_pull = 0
	lever.attack_hand(builder)
	sleep(15)
	mechanisms_assert(!lever.thrown && !door.state && door.density && !trap.open, "lever_back_shuts")

	// A locked door holds against the cord.
	door.locked = TRUE
	lever.next_pull = 0
	lever.attack_hand(builder)
	sleep(15)
	mechanisms_assert(!door.state && trap.open, "locked_door_holds")
	door.locked = FALSE
	lever.next_pull = 0
	lever.attack_hand(builder)
	sleep(15)

	// Cutting a cord gives the rope back.
	mechanisms_answer(builder, "Cut the cord to [trap.name] (7 east)")
	mechanism_rope_on_trigger(lever, rope, builder)
	mechanisms_assert(lever.links == "3,0", "cut_trapdoor")
	var/obj/item/stack/material/rope/back = locate() in get_turf(builder)
	mechanisms_assert(back && back.amount == 1, "rope_back")

	// Out of reach and the cord limit.
	mechanisms_assert(!length(mechanism_link_turfs(lever, "")), "no_links_empty")
	lever.links = "1,1;1,2;1,3;1,4"
	mechanisms_answer(builder, "Tie a cord to [bell.name] (5 north, 1 west)")
	mechanism_rope_on_trigger(lever, rope, builder)
	mechanisms_assert(lever.links == "1,1;1,2;1,3;1,4", "four_cords_at_most")
	lever.links = "3,0"

	// A pull cord toggles the door, rings the bell and lets the rock drop go.
	var/obj/structure/mechanism/pull_cord/cord = new(locate(4, 5, 1))
	cord.links = "4,-1;0,4;6,5"
	var/mob/living/human/victim = mechanisms_actor(10, 10, "Victim")
	var/before = victim.getBruteLoss()
	cord.attack_hand(builder)
	sleep(15)
	mechanisms_assert(door.state, "cord_opens")
	mechanisms_assert(bell.next_ring > world.time, "cord_rings")
	mechanisms_assert(!drop.loaded && drop.icon_state == "rock_drop_empty", "cord_drops")
	mechanisms_assert(victim.getBruteLoss() > before, "drop_hurts")
	var/after_first = victim.getBruteLoss()
	cord.attack_hand(builder)
	sleep(5)
	mechanisms_assert(door.state, "cord_waits_between_pulls")
	cord.next_pull = 0
	bell.next_ring = 0
	cord.attack_hand(builder)
	sleep(15)
	mechanisms_assert(!door.state && victim.getBruteLoss() == after_first, "cord_shuts_empty_drop_harmless")

	// Hung up again by hand.
	var/mob/living/human/hauler = mechanisms_actor(10, 9, "Hauler")
	drop.attack_hand(hauler)
	mechanisms_assert(drop.loaded && drop.icon_state == "rock_drop", "drop_rehung")

	// A pressure plate set from the hand knows its setter's people.
	var/obj/item/mechanism_kit/pressure_plate/kit = new
	var/mob/living/human/setter = mechanisms_actor(6, 8, "Setter")
	setter.civilization = "Riverfolk"
	mechanisms_hands(setter, kit)
	kit.attack_self(setter)
	var/obj/structure/mechanism/pressure_plate/plate = locate() in locate(6, 8, 1)
	mechanisms_assert(istype(plate) && QDELETED(kit) && plate.owner_civilization == "Riverfolk", "plate_set")
	plate.links = "-2,1"
	mechanisms_assert(plate.is_friend(builder) && !plate.presses(builder), "friend_safe")
	var/mob/living/human/stranger = mechanisms_actor(7, 8, "Stranger")
	stranger.civilization = "Hillfolk"
	mechanisms_assert(plate.presses(stranger), "stranger_presses")
	bell.next_ring = 0
	plate.Crossed(builder)
	mechanisms_assert(bell.next_ring == 0, "friend_no_pull")
	plate.Crossed(stranger)
	mechanisms_assert(bell.next_ring > world.time, "stranger_pulls")
	var/obj/item/weapon/storage/box/small_thing = new(locate(6, 8, 1))
	mechanisms_assert(!plate.presses(small_thing), "items_dont_press")

	// A tripwire alarm pulls its cords too.
	var/obj/structure/tripwire_alarm/wire = new(locate(2, 9, 1))
	wire.set_owner(setter)
	wire.links = "2,0"
	bell.next_ring = 0
	wire.trip(stranger)
	mechanisms_assert(bell.next_ring > world.time, "tripwire_pulls")

	// A cord never opens a trapdoor under someone; it does once they step off.
	var/obj/structure/simple_door/key_door/anyone/trapdoor/hatch = new(locate(14, 14, 1))
	sleep(10)
	var/mob/living/human/stander = mechanisms_actor(14, 14, "Stander")
	mechanisms_assert(!mechanism_actuate(hatch, null) && !hatch.state, "trapdoor_not_under_someone")
	qdel(stander)
	mechanisms_assert(mechanism_actuate(hatch, null), "trapdoor_opens_when_clear")
	sleep(12)
	mechanisms_assert(hatch.state, "trapdoor_open")

	// A pulley block carries cords one level up; without it the cord hangs slack.
	var/obj/structure/bell/upper_bell = new(locate(5, 6, 2))
	var/obj/structure/mechanism/lever/upper_lever = new(locate(2, 2, 1))
	var/mob/living/human/rigger = mechanisms_actor(2, 3, "Rigger")
	mechanisms_assert(!(upper_bell in mechanism_reachable_actuators(upper_lever)), "no_pulley_no_upstairs")
	var/obj/structure/mechanism_pulley/pulley = new(locate(3, 2, 1))
	mechanisms_assert(upper_bell in mechanism_reachable_actuators(upper_lever), "pulley_reaches_upstairs")
	mechanisms_assert(mechanism_offset_words(upper_lever, get_turf(upper_bell)) == "4 north, 3 east, one level up", "upstairs_words")
	var/obj/item/stack/material/rope/rope2 = new(null, 5)
	mechanisms_hands(rigger, rope2)
	mechanisms_answer(rigger, "Tie a cord to [upper_bell.name] (4 north, 3 east, one level up)")
	mechanism_rope_on_trigger(upper_lever, rope2, rigger)
	mechanisms_assert(upper_lever.links == "3,4,1", "upstairs_entry")
	upper_bell.next_ring = 0
	upper_lever.attack_hand(rigger)
	mechanisms_assert(upper_bell.next_ring > world.time, "rings_upstairs")
	qdel(pulley)
	upper_bell.next_ring = 0
	upper_lever.thrown = FALSE
	upper_lever.next_pull = 0
	upper_lever.attack_hand(rigger)
	mechanisms_assert(upper_bell.next_ring == 0, "slack_without_pulley")

	// Clock alarms: a water clock pulls at its hour, a tower clock every hour.
	var/obj/structure/water_clock/wclock = new(locate(3, 12, 1))
	wclock.water = 60
	wclock.links = "1,0"
	var/obj/structure/bell/clock_bell = new(locate(4, 12, 1))
	var/h = mechanism_hour24()
	wclock.alarm_hour = (h + 5) % 24
	wclock.last_hour = (h + 23) % 24
	clock_bell.next_ring = 0
	wclock.process_interval(2)
	mechanisms_assert(clock_bell.next_ring == 0 && wclock.last_hour == h, "water_clock_waits_for_its_hour")
	wclock.alarm_hour = h
	wclock.last_hour = (h + 23) % 24
	wclock.process_interval(2)
	mechanisms_assert(clock_bell.next_ring > world.time, "water_clock_alarm_pulls")
	clock_bell.next_ring = 0
	wclock.process_interval(2)
	mechanisms_assert(clock_bell.next_ring == 0, "water_clock_once_an_hour")
	mechanisms_assert(mechanism_alarm_name(-1) == "off" && mechanism_alarm_name(24) == "every hour" && mechanism_alarm_name(0) == "at 12 AM" && mechanism_alarm_name(13) == "at 1 PM", "alarm_names")
	var/obj/structure/tower_clock/tclock = new(locate(3, 16, 1))
	tclock.wound = 60
	tclock.links = "1,-4"
	tclock.alarm_hour = 24
	tclock.last_hour = (clock_hour() % 12) + 1
	clock_bell.next_ring = 0
	tclock.process_interval(2)
	mechanisms_assert(clock_bell.next_ring > world.time, "tower_clock_hourly_pulls")

	// Transmission (transmission.dm): line shafts carry a mover's drive,
	// machines share its strength, a long wooden run binds, a clutch throws
	// out, a gear box carries drive down a level and a rope drive across.
	var/mob/living/human/treader = mechanisms_actor(2, 12, "Treader")
	var/obj/structure/workshop_machine/mover/treadwheel/tread = new(locate(2, 12, 2))
	treader.forceMove(locate(2, 12, 2))
	var/obj/structure/workshop_machine/potters_wheel/wheel = new(locate(2, 13, 2))
	mechanisms_assert(abs(mechanical_drive_factor(wheel) - 0.65) < 0.001, "mover_drives_beside_it")
	var/list/shafts = list()
	for (var/sx = 3, sx <= 10, sx++)
		shafts += new /obj/structure/workshop_machine/transmission/line_shaft(locate(sx, 12, 2))
	var/obj/structure/workshop_machine/masons_saw/saw = new(locate(10, 13, 2))
	mechanisms_assert(abs(mechanical_drive_factor(saw) - 0.825) < 0.001, "shaft_carries_shared_drive")
	mechanisms_assert(abs(mechanical_drive_factor(wheel) - 0.825) < 0.001, "draw_slows_every_machine")
	var/obj/structure/workshop_machine/transmission/line_shaft/extra = new(locate(11, 12, 2))
	var/list/load = mechanical_drive_load(saw)
	mechanisms_assert(load[4] && mechanical_drive_factor(saw) == 1, "wooden_run_binds_past_eight")
	mechanisms_assert(abs(mechanical_drive_factor(wheel) - 0.65) < 0.001, "bound_run_leaves_mover_beside")
	qdel(extra)
	var/obj/structure/workshop_machine/transmission/line_shaft/middle = shafts[4]
	qdel(middle)
	var/obj/structure/workshop_machine/transmission/line_shaft/clutch/clutch = new(locate(6, 12, 2))
	clutch.set_engaged(FALSE)
	mechanisms_assert(mechanical_drive_factor(saw) == 1 && abs(mechanical_drive_factor(wheel) - 0.65) < 0.001, "clutch_out_stops_the_rest")
	mechanisms_assert(mechanism_actuatable(clutch) && mechanism_actuate(clutch, TRUE) && clutch.engaged, "cord_throws_clutch_in")
	mechanisms_assert(abs(mechanical_drive_factor(saw) - 0.825) < 0.001, "clutch_in_carries")
	new /obj/structure/workshop_machine/transmission/gear_box(locate(10, 11, 2))
	new /obj/structure/workshop_machine/transmission/gear_box(locate(10, 11, 1))
	var/obj/structure/workshop_machine/masons_saw/low_saw = new(locate(11, 11, 1))
	mechanisms_assert(abs(mechanical_drive_factor(low_saw) - (1 - 0.35 / 3)) < 0.001, "gear_box_carries_down")
	var/obj/structure/workshop_machine/transmission/rope_drive/near_wheel = new(locate(11, 13, 2))
	var/obj/structure/workshop_machine/transmission/rope_drive/far_wheel = new(locate(15, 15, 2))
	var/obj/structure/workshop_machine/masons_saw/far_saw = new(locate(15, 16, 2))
	mechanisms_assert(mechanical_drive_factor(far_saw) == 1, "rope_drive_needs_its_rope")
	near_wheel.tie_to(far_wheel)
	mechanisms_assert(far_wheel.partner() == near_wheel && mechanical_drive_factor(far_saw) < 1, "rope_drive_carries")
	treader.forceMove(locate(1, 16, 2))
	mechanisms_assert(mechanical_drive_factor(far_saw) == 1 && tread.current_capacity() == 0, "still_mover_drives_nothing")
	for (var/state in list("line_shaft", "line_shaft_iron", "gear_box", "clutch", "clutch_engaged", "rope_drive"))
		mechanisms_assert(state in icon_states('icons/obj/transmission.dmi'), "icon_[state]")

	// The new art is in the icon file.
	var/list/states = icon_states('icons/obj/mechanisms.dmi')
	for (var/state in list("lever", "lever_pulled", "pull_cord", "pull_cord_pulled", "pressure_plate", "pressure_plate_pressed", "rock_drop", "rock_drop_empty", "pulley"))
		mechanisms_assert(state in states, "icon_[state]")

/world/New()
	OpenPort("none")
	var/error = null
	try
		mechanisms_probe_run()
	catch (var/exception/probe_error)
		error = "[probe_error.name] ([probe_error.file]:[probe_error.line])"
	if (!error && mechanisms_runtime)
		error = mechanisms_runtime
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("checks" = mechanisms_probe_checks, "error" = error, "byond_build" = byond_build)), "receipt.json")
	del(world)
