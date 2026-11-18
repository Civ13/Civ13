// Full-game probe for integrated circuits: the whole of civ13.dme (without maps)
// with real items, mobs, windows, qdel and timers. Every editor action goes
// through the real window transport as an agent body's button press.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/wiremod/game_probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 10
	maxy = 10
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/mob/living/human/wiremod_probe/New()
	return
/mob/living/human/wiremod_probe/update_icons()
	return
/mob/living/human/wiremod_probe/movement_delay()
	return 1
var/wiremod_failures = 0
var/wiremod_runtime_error = FALSE
/proc/wiremod_check(condition, label)
	if (!condition)
		wiremod_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	wiremod_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		// The registration counts cleanup_events() works from (~cleanup.dm).
		GLOB.global_listen_count = list()
		GLOB.event_sources_count = list()
		GLOB.event_listen_count = list()
		movementMachine = new
		if (!GLOB.nanomanager)
			GLOB.nanomanager = new
		wiremod_checks()
	catch(var/exception/e)
		wiremod_check(FALSE, "exception [e] [e.file]:[e.line] [e.desc]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = wiremod_failures, "runtime_error" = wiremod_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/wiremod_press(datum/agent_character/C, list/req)
	req["screen"] = 1
	try
		return agent_control.agent_screen(C, req, TRUE)
	catch(var/exception/e)
		return "refused: [e.desc]"

// Everything the open editor window was last sent, as the JSON it receives.
// (agent_screen_rows() cuts long data short.)
/proc/wiremod_window(mob/M)
	var/datum/nanoui/ui = agent_find_screen(M, 1)
	return ui ? json_encode(ui.agent_screen_data()) : ""

/proc/wiremod_build(datum/agent_character/C, mob/living/human/H)
	var/obj/item/circuit_shell/compact_remote/remote = new(H)
	wiremod_check(isnull(remote.circuit), "a compact remote starts without an integrated circuit")
	var/obj/item/integrated_circuit/circuit = new(H)
	H.put_in_hands(circuit)
	remote.attackby(circuit, H)
	wiremod_check(circuit.loc == remote, "the circuit moves into the remote")
	wiremod_check(circuit.attached_components.len == 1 && circuit.attached_components[1] == remote.remote_input, "the remote attaches its signal source")
	wiremod_check(!circuit.should_save && !remote.should_save, "the circuit and remote stay out of saves")
	remote.AltClick(H)
	var/list/rows = agent_screen_rows(H)
	wiremod_check(rows.len == 1 && rows[1]["status"] == "interactive" && rows[1]["template"] == "wiremod_circuit.tmpl", "Alt-click opens the editor for the holder")
	wiremod_check(rows.len && ("print_component" in rows[1]["actions"]) && findtext(rows[1]["data"], "Compact Remote") && findtext(rows[1]["data"], "\"datatype_data\":\[\"Add\""), "the editor lists its actions, the remote's source and the operation choices")
	wiremod_press(C, list("act" = "print_component", "component_to_print" = "/obj/item/circuit_component/random", "rel_x" = 200, "rel_y" = 40))
	wiremod_press(C, list("act" = "print_component", "component_to_print" = "/obj/item/circuit_component/operator/arithmetic", "rel_x" = 40, "rel_y" = 290))
	wiremod_press(C, list("act" = "print_component", "component_to_print" = "/obj/item/circuit_component/delay", "rel_x" = 400, "rel_y" = 290))
	wiremod_press(C, list("act" = "print_component", "component_to_print" = "/mob/living/human", "rel_x" = 0, "rel_y" = 0))
	wiremod_press(C, list("act" = "print_component", "component_to_print" = "/obj/item/circuit_shell/compact_remote", "rel_x" = 0, "rel_y" = 0))
	wiremod_check(circuit.attached_components.len == 4 && circuit.contents.len == 4, "the editor prints listed components and nothing else")
	if (circuit.attached_components.len != 4)
		return null
	var/obj/item/circuit_component/random/dice = circuit.attached_components[2]
	var/obj/item/circuit_component/operator/arithmetic/math = circuit.attached_components[3]
	var/obj/item/circuit_component/delay/timer = circuit.attached_components[4]
	wiremod_check(dice.rel_x == 200 && dice.rel_y == 40 && dice.printed, "a printed component lands where it was dropped")
	// Signal -> Random trigger, Random result -> Arithmetic A, B = 10.
	wiremod_press(C, list("act" = "add_connection", "input_component_id" = 2, "input_port_id" = 3, "output_component_id" = 1, "output_port_id" = 2))
	wiremod_press(C, list("act" = "add_connection", "input_component_id" = 3, "input_port_id" = 1, "output_component_id" = 2, "output_port_id" = 1))
	wiremod_press(C, list("act" = "set_component_input", "component_id" = 3, "port_id" = 2, "input" = 10))
	wiremod_press(C, list("act" = "set_component_input", "component_id" = 2, "port_id" = 1, "input" = 1))
	wiremod_press(C, list("act" = "set_component_input", "component_id" = 2, "port_id" = 2, "input" = 6))
	wiremod_check(dice.trigger.connected_output == circuit.attached_components[1].output_ports[2] && math.input_a.connected_output == dice.result && math.input_b.value == 10, "connections and typed values arrive through the window transport")
	// A text output cannot feed a number input.
	wiremod_press(C, list("act" = "add_connection", "input_component_id" = 3, "input_port_id" = 2, "output_component_id" = 1, "output_port_id" = 1))
	wiremod_check(isnull(math.input_b.connected_output), "an incompatible connection is refused")
	remote.attack_self(H)
	wiremod_check(isnum(dice.result.value) && dice.result.value >= 1 && dice.result.value <= 6 && math.result.value == dice.result.value + 10, "pressing the remote rolls the die and adds ten ([math.result.value])")
	// The typed values above refreshed the open editor in this same tick, so
	// the run this press sets off is held for a timed refresh instead of
	// sending the whole editor again at once.
	rows = agent_screen_rows(H)
	wiremod_check(rows.len && findtext(rows[1]["data"], "\"connected_to\":\[\"output-2-1\"\]") && !isnull(circuit.editor_refresh_timer) && circuit.next_editor_refresh > world.time, "a run right after a refresh is held for a timed refresh")
	// This fixture runs no timer subsystem, so the probe does what the timer does.
	deltimer(circuit.editor_refresh_timer)
	circuit.refresh_editor_now()
	rows = agent_screen_rows(H)
	wiremod_check(isnull(circuit.editor_refresh_timer) && rows.len && findtext(rows[1]["data"], "\"current_data\":[dice.result.value]"), "the held refresh shows the editor the final state")
	// The Operation dropdown: the editor sends the chosen text for the option
	// port, exactly as a click on "Multiply" does (tgui/scripts/wiremod-browser-smoke.mjs).
	wiremod_check(math.operation.value == "Add" && findtext(rows[1]["data"], "\"type\":\"option\"") && findtext(rows[1]["data"], "\"color\":\"violet\""), "the operation input reaches the window as a violet option port")
	wiremod_press(C, list("act" = "set_component_input", "component_id" = 3, "port_id" = 3, "input" = "Multiply"))
	wiremod_check(math.operation.value == "Multiply", "choosing Multiply in the dropdown reaches the component through the window transport")
	remote.attack_self(H)
	wiremod_check(isnum(dice.result.value) && math.result.value == dice.result.value * 10, "the remote now rolls the die and multiplies by ten ([math.result.value])")
	wiremod_press(C, list("act" = "set_component_input", "component_id" = 3, "port_id" = 3, "input" = "Explode"))
	wiremod_check(math.operation.value == "Multiply", "a text that is not one of the choices is ignored")
	wiremod_press(C, list("act" = "set_component_input", "component_id" = 3, "port_id" = 3, "input" = "Add"))
	// The info button.
	wiremod_press(C, list("act" = "set_examined_component", "component_id" = 3, "x" = 150, "y" = 90))
	deltimer(circuit.editor_refresh_timer)
	circuit.refresh_editor_now()
	var/window = wiremod_window(H)
	wiremod_check(findtext(window, "\"examined_name\":\"Arithmetic\"") && findtext(window, "\"examined_desc\":\"Works out a number from A and B") && findtext(window, "\"content\":\"In: Operation (option)\"") && findtext(window, "\"examined_rel_x\":150"), "the info button sends the component's description and its ports to the window")
	wiremod_press(C, list("act" = "remove_examined_component"))
	// Out-of-range and malformed requests change nothing and raise nothing.
	for (var/bad in list("0", "-1", "99", "1.5", "abc", "1e9"))
		wiremod_press(C, list("act" = "detach_component", "component_id" = bad))
		wiremod_press(C, list("act" = "set_component_input", "component_id" = bad, "port_id" = 1, "input" = 5))
		wiremod_press(C, list("act" = "add_connection", "input_component_id" = bad, "input_port_id" = bad, "output_component_id" = 1, "output_port_id" = bad))
	wiremod_press(C, list("act" = "detach_component", "component_id" = 1))
	wiremod_press(C, list("act" = "remove_variable", "variable_name" = 1))
	wiremod_press(C, list("act" = "add_setter_or_getter", "variable" = 1, "is_setter" = 1))
	wiremod_check(circuit.attached_components.len == 4, "bad component numbers and the fixed signal source are left alone")
	wiremod_check(findtext(wiremod_press(C, list("act" = "toggle")), "refused") == 1, "an action the editor does not offer is refused by the transport")
	// A label with markup.
	wiremod_press(C, list("act" = "set_display_name", "display_name" = "<b>Dice</b> roller"))
	wiremod_check(circuit.display_name == "bDiceb roller" && circuit.name == "integrated circuit (bDiceb roller)", "a label keeps only plain characters ([circuit.name])")
	circuit.examine(H)
	// A feedback loop: Arithmetic result back into its own B.
	wiremod_press(C, list("act" = "add_connection", "input_component_id" = 3, "input_port_id" = 2, "output_component_id" = 3, "output_port_id" = 1))
	wiremod_check(circuit.overloaded_until > world.time && !circuit.is_executing && !circuit.execution_queue.len && isnum(math.result.value), "a feedback loop overloads the circuit instead of hanging")
	wiremod_press(C, list("act" = "remove_connection", "component_id" = 3, "is_input" = 1, "port_id" = 2))
	wiremod_check(isnull(math.input_b.connected_output), "the loop can be unwired while overloaded")
	// Variables.
	wiremod_press(C, list("act" = "add_variable", "variable_name" = "last roll", "variable_datatype" = "number", "is_list" = 0, "is_assoc_list" = 0))
	wiremod_press(C, list("act" = "add_setter_or_getter", "variable" = "last roll", "is_setter" = 1, "rel_x" = 10, "rel_y" = 10))
	wiremod_check(circuit.circuit_variables.len == 1 && circuit.attached_components.len == 5, "a variable and its setter are added")
	// Components are named by a number that outlives removals: the setter is 5.
	wiremod_press(C, list("act" = "print_component", "component_to_print" = "/obj/item/circuit_component/operator/logic", "rel_x" = 0, "rel_y" = 0))
	var/obj/item/circuit_component/operator/logic/gate = circuit.attached_components[circuit.attached_components.len]
	wiremod_press(C, list("act" = "detach_component", "component_id" = 5))
	wiremod_check(circuit.attached_components.len == 5 && gate.circuit_id == 6 && circuit.attached_components[5] == gate, "removing the fifth component leaves the sixth in fifth place under its own number")
	wiremod_press(C, list("act" = "set_component_coordinates", "component_id" = 5, "rel_x" = 900, "rel_y" = 900))
	wiremod_check(gate.rel_x == 0 && gate.rel_y == 0, "a request for the removed component's number does not reach the one that took its place")
	wiremod_press(C, list("act" = "set_component_coordinates", "component_id" = 6, "rel_x" = 300, "rel_y" = 200))
	rows = agent_screen_rows(H)
	wiremod_check(gate.rel_x == 300 && gate.rel_y == 200 && rows.len && findtext(rows[1]["data"], "\"id\":6") && findtext(rows[1]["data"], "\"ref\":\"input-6-1\"") && !findtext(rows[1]["data"], "\"id\":5"), "the window names components and ports by those numbers")
	// Delay: started by the remote's signal, cancelled by deleting the remote.
	wiremod_press(C, list("act" = "add_connection", "input_component_id" = 4, "input_port_id" = 2, "output_component_id" = 1, "output_port_id" = 2))
	circuit.overloaded_until = 0
	remote.attack_self(H)
	wiremod_check(!isnull(timer.timer_id), "the delay starts a real timer")
	wiremod_check(H.l_hand != remote && H.r_hand != remote, "the probe holds the remote in its contents, not a hand slot")
	// Entities: the press above left the presser on the User output as a weak
	// reference, and the editor marks what the player holds.
	var/obj/item/circuit_component/compact_remote/source = circuit.attached_components[1]
	wiremod_check(source.user_output.value == WEAKREF(H) && istype(source.user_output.value, /datum/weakref), "the User output holds the presser's weak reference, never the mob")
	wiremod_press(C, list("act" = "print_component", "component_to_print" = "/obj/item/circuit_component/direction", "rel_x" = 500, "rel_y" = 40))
	var/obj/item/circuit_component/direction/finder = circuit.attached_components[circuit.attached_components.len]
	wiremod_press(C, list("act" = "set_component_input", "component_id" = finder.circuit_id, "port_id" = 1, "marked_atom" = 1))
	wiremod_check(finder.target_input.value == WEAKREF(H) && finder.distance_output.value == 0, "with empty hands a player marks themselves on an entity input")
	var/obj/item/integrated_circuit/marked = new(locate(7, 5, 1))
	marked.name = "<i>marked</i>"
	if (H.hand)
		H.r_hand = marked
	else
		H.l_hand = marked
	wiremod_press(C, list("act" = "set_component_input", "component_id" = finder.circuit_id, "port_id" = 1, "marked_atom" = 1))
	wiremod_check(finder.target_input.value == WEAKREF(marked) && finder.direction_output.value == "east" && finder.distance_output.value == 2, "the item in the other hand is marked, and found two tiles east ([finder.direction_output.value], [finder.distance_output.value])")
	wiremod_press(C, list("act" = "set_component_input", "component_id" = finder.circuit_id, "port_id" = 1, "input" = "\ref[H]"))
	wiremod_check(finder.target_input.value == WEAKREF(marked), "an entity input takes no typed value, a ref included")
	deltimer(circuit.editor_refresh_timer)
	circuit.refresh_editor_now()
	window = wiremod_window(H)
	wiremod_check(findtext(window, "\"name\":\"Target\",\"type\":\"entity\",\"color\":\"purple\"") && findtext(window, "\"current_data\":\"<i>marked<") && !findtext(window, "\ref[marked]") && !findtext(window, "\ref[H]"), "the window is sent an entity as its name, never a reference")
	var/list/listeners = GLOB.destroyed_event.event_sources[marked]
	wiremod_check(listeners && (finder.target_input in listeners), "the port holding the marked item listens for its deletion")
	H.l_hand = null
	H.r_hand = null
	var/marked_ref = "\ref[marked]"
	listeners = null
	qdel(marked)
	marked = null
	wiremod_check(isnull(finder.target_input.value), "deleting the marked item empties the input")
	wiremod_press(C, list("act" = "set_component_input", "component_id" = finder.circuit_id, "port_id" = 1, "marked_atom" = 1))
	// A screwdriver takes the circuit out and leaves the remote's button behind.
	var/obj/item/weapon/screwdriver/driver = new(H)
	H.a_intent = "help"
	remote.attackby(driver, H)
	wiremod_check(isnull(remote.circuit) && circuit.loc != remote && !QDELETED(remote.remote_input), "a screwdriver takes the circuit out and the remote keeps its button")
	remote.attackby(circuit, H)
	wiremod_check(remote.circuit == circuit && circuit.loc == remote && (remote.remote_input in circuit.attached_components), "the circuit goes back in with its signal source")
	qdel(driver)
	// Everything the remote owns, by ref.
	var/list/refs = list("\ref[remote]", "\ref[circuit]", marked_ref)
	for (var/obj/item/circuit_component/component in circuit.attached_components)
		refs += "\ref[component]"
		for (var/datum/port/port in component.input_ports + component.output_ports)
			refs += "\ref[port]"
	for (var/variable_name in circuit.circuit_variables)
		refs += "\ref[circuit.circuit_variables[variable_name]]"
	qdel(remote)
	wiremod_check(QDELETED(circuit) && QDELETED(dice) && QDELETED(timer) && isnull(timer.timer_id) && !circuit.attached_components.len, "deleting the remote deletes its circuit and components and cancels the delay")
	wiremod_check(!agent_open_screens(H).len, "deleting the remote closes its editor")
	var/port_listeners = 0
	for (var/datum/port/listener in GLOB.destroyed_event.event_sources[H])
		port_listeners++
	wiremod_check(!port_listeners && !QDELETED(H), "deleting the remote stops its ports listening for the presser, who is untouched")
	return refs

/proc/wiremod_checks()
	var/mob/living/human/wiremod_probe/H = new(locate(5, 5, 1))
	H.species = new /datum/species/human
	H.stat = CONSCIOUS
	H.canmove = TRUE
	var/datum/agent_character/C = new
	C.body = H
	agent_characters[H] = C
	usr = H
	var/list/refs = wiremod_build(C, H)
	if (!refs)
		return
	// Without the garbage process, qdel parks each object in delayed_garbage
	// until that process starts. Emptying it leaves only real references, and
	// nothing hard-deletes here: an object still findable is still referenced.
	delayed_garbage.Cut()
	delayed_hard_garbage.Cut()
	sleep(5)
	var/alive = 0
	for (var/ref in refs)
		var/datum/survivor = locate(ref)
		if (survivor)
			alive++
			world.log << "still referenced: [survivor.type]"
		survivor = null
	wiremod_check(refs.len >= 20 && !alive, "every object of the deleted remote is released ([alive] of [refs.len] still referenced)")
	// A loose circuit on the ground: a neighbour may edit it, a ghost may not.
	var/obj/item/integrated_circuit/loose = new(locate(6, 5, 1))
	loose.attack_self(H)
	wiremod_check(agent_open_screens(H).len == 1, "an adjacent player can open a circuit on the ground")
	wiremod_check(wiremod_circuit_state.can_use_topic(loose, new /mob/observer/ghost(locate(6, 5, 1))) == STATUS_CLOSE, "a ghost cannot use the editor")
	H.forceMove(locate(1, 1, 1))
	wiremod_check(wiremod_circuit_state.can_use_topic(loose, H) == STATUS_CLOSE, "a distant player cannot use the editor")
	var/before = loose.attached_components.len
	loose.ui_act("print_component", list("component_to_print" = "/obj/item/circuit_component/operator/logic"), H, null)
	wiremod_check(loose.attached_components.len == before, "a distant player's request is ignored")
	qdel(loose)
