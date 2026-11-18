// Behaviour probe for code/modules/wiremod. run.py compiles this file together
// with the production Wiremod sources and nothing else, so everything the module
// expects from the rest of Civ13 is a small stand-in here. Each stand-in keeps the
// contract of the real proc that matters to the module (noted where it does).
#define islist(A) istype(A, /list)
#define isatom(A) istype(A, /atom)
#define PROC_REF(X) (nameof(.proc/##X))
#define CALLBACK new /datum/callback
#define QDELETED(X) (!X || X.gc_destroyed)
#define QDEL_NULL(item) qdel(item); item = null
#define STATUS_INTERACTIVE 2
#define STATUS_CLOSE -1
#define ITEM_SIZE_TINY 1
#define ITEM_SIZE_SMALL 2
#define TIMER_STOPPABLE 8
#define to_chat(target, message) probe_chat(target, message)
#define CONSCIOUS 0
#define DEAD 2

var/failures = 0
var/checks = 0
var/list/chat_log = list()
var/list/active_timers = list()
var/next_timer_id = 0
var/crash_calls = 0
var/datum/probe_globals/GLOB = new

/datum/probe_globals
	var/datum/probe_nanomanager/nanomanager = new

// As the real one: returns how many open windows it refreshed. `watchers` is
// the number of editors the probe pretends are open.
/datum/probe_nanomanager
	var/updates = 0
	var/watchers = 0

/datum/probe_nanomanager/proc/update_uis(datum/owner)
	updates++
	return watchers

/proc/probe_chat(target, message)
	chat_log += "[message]"

/proc/stack_trace(message)
	CRASH(message)

/proc/trim(text)
	var/static/regex/edges = regex(@"^\s+|\s+$", "g")
	return edges.Replace(text, "")

/proc/get_turf(atom/target)
	while(target && !isturf(target))
		target = target.loc
	return target

// Civ13's qdel() calls Destroy() once and leaves the object to the garbage
// collector. The probe does the same and never hard-deletes, so an object that
// is still referenced afterwards stays findable by its ref: that is the leak check.
/datum
	var/gc_destroyed = 0
	var/should_save = TRUE

/datum/proc/Destroy()
	return

/atom/movable/Destroy()
	loc = null
	return ..()

/proc/qdel(datum/target)
	if(!istype(target) || target.gc_destroyed)
		return
	target.gc_destroyed = 1
	target.Destroy()

/datum/callback
	var/datum/object
	var/delegate

/datum/callback/New(datum/target, procname)
	object = target
	delegate = procname

/datum/callback/proc/Invoke()
	if(object && !object.gc_destroyed)
		return call(object, delegate)()

// The waiting proc holds only the id, so a cancelled timer keeps nothing alive.
/proc/addtimer(datum/callback/callback, wait, flags)
	var/id = "[++next_timer_id]"
	active_timers[id] = callback
	probe_timer(id, wait)
	return id

/proc/probe_timer(id, wait)
	set waitfor = FALSE
	sleep(wait)
	var/datum/callback/pending = active_timers[id]
	if(pending)
		active_timers -= id
		pending.Invoke()

/proc/deltimer(id)
	active_timers -= id

/datum/proc/ui_interact(mob/user, ui_key = "main", datum/nanoui/ui = null, force_open = TRUE, datum/nanoui/master_ui = null, datum/topic_state/state = null)
	return

/datum/proc/ui_actions(ui_key)
	return list()

/datum/proc/ui_action_fields(ui_key, action)
	return null

/datum/proc/ui_act(action, list/params, mob/user, datum/nanoui/ui)
	return FALSE

/datum/proc/open_tgui(mob/user, ui_key, template, title, width, height, list/data, datum/nanoui/ui, force_open = TRUE, state, keep_interaction = FALSE, auto_update = FALSE)
	return

/datum/nanoui
/datum/topic_state

/datum/topic_state/proc/can_use_topic(src_object, mob/user)
	return STATUS_CLOSE

/atom/proc/Adjacent(atom/neighbor)
	var/turf/here = get_turf(src)
	var/turf/there = get_turf(neighbor)
	return here && there && get_dist(here, there) <= 1

/atom/proc/attackby(obj/item/used, mob/user)
	return FALSE

// The real examine prints its text and returns a number, not a list.
/atom/proc/examine(mob/user)
	to_chat(user, "That's [src].")
	return TRUE

/atom/proc/AltClick(mob/user)
	return

/atom/movable/proc/forceMove(atom/destination)
	loc = destination
	return TRUE

/obj/item
	var/w_class = 3

/obj/item/proc/attack_self(mob/user)
	return

/mob
	var/stat = CONSCIOUS
	var/is_restrained = FALSE
	var/obj/item/held
	var/drops = 0

/mob/proc/restrained()
	return is_restrained

// As in Civ13: the item leaves the hand slot and lands in the target.
/mob/proc/drop_from_inventory(obj/item/dropped, atom/target)
	drops++
	if(held == dropped)
		held = null
	dropped.forceMove(target ? target : loc)
	return TRUE

/mob/proc/put_in_hands(obj/item/taken)
	taken.forceMove(src)
	held = taken
	return TRUE

/mob/living
/mob/observer

/turf/probe_floor
/world
	turf = /turf/probe_floor
	maxx = 5
	maxy = 5
	maxz = 1

/world/OpenPort(port)
	if(port == "none")
		return ..()
	return FALSE

// A component whose trigger always fails, to prove one bad component cannot
// leave a circuit stuck.
/obj/item/circuit_component/probe_crash
	display_name = "Probe Crash"
	var/datum/port/input/trigger_input

/obj/item/circuit_component/probe_crash/populate_ports()
	trigger_input = add_input_port("Trigger", PORT_TYPE_ANY, trigger = PROC_REF(explode))

/obj/item/circuit_component/probe_crash/proc/explode(datum/port/input/input)
	crash_calls++
	CRASH("probe component failure")

/proc/check(condition, message)
	checks++
	if(!condition)
		failures++
		world.log << "FAIL [message]"

/proc/act(obj/item/integrated_circuit/circuit, mob/user, action, list/params)
	try
		circuit.ui_act(action, params ? params : list(), user, null)
	catch(var/exception/failure)
		failures++
		world.log << "FAIL ui_act [action] raised: [failure]"

/proc/print(obj/item/integrated_circuit/circuit, mob/user, typepath)
	var/before = length(circuit.attached_components)
	act(circuit, user, "print_component", list("component_to_print" = "[typepath]", "rel_x" = 10, "rel_y" = 20))
	if(length(circuit.attached_components) != before + 1)
		return null
	return circuit.attached_components[length(circuit.attached_components)]

// What the editor calls a component: the number its circuit gave it.
/proc/index_of(obj/item/integrated_circuit/circuit, obj/item/circuit_component/component)
	return component.circuit_id

/proc/wire(obj/item/integrated_circuit/circuit, mob/user, obj/item/circuit_component/source, output_index, obj/item/circuit_component/sink, input_index)
	act(circuit, user, "add_connection", list(
		"input_component_id" = index_of(circuit, sink), "input_port_id" = input_index,
		"output_component_id" = index_of(circuit, source), "output_port_id" = output_index))
	var/datum/port/input/input_port = sink.input_ports[input_index]
	return input_port.connected_output == source.output_ports[output_index]

/proc/enter(obj/item/integrated_circuit/circuit, mob/user, obj/item/circuit_component/component, port_index, value)
	act(circuit, user, "set_component_input", list("component_id" = index_of(circuit, component), "port_id" = port_index, "input" = value))

/proc/input_value(obj/item/circuit_component/component, port_index)
	var/datum/port/input/input_port = component.input_ports[port_index]
	return input_port.value

/proc/output_value(obj/item/circuit_component/component, port_index = 1)
	var/datum/port/output/output_port = component.output_ports[port_index]
	return output_port.value

/proc/long_text(count)
	var/list/pieces = list()
	for(var/i in 1 to count)
		pieces += "a"
	return jointext(pieces, "")

/proc/test_datatypes()
	var/datum/circuit_datatype/number = circuit_datatype_for(PORT_TYPE_NUMBER)
	var/datum/circuit_datatype/boolean = circuit_datatype_for(PORT_TYPE_BOOLEAN)
	var/datum/circuit_datatype/string = circuit_datatype_for(PORT_TYPE_STRING)
	var/datum/circuit_datatype/any = circuit_datatype_for(PORT_TYPE_ANY)
	var/datum/circuit_datatype/list_type = circuit_datatype_for(PORT_TYPE_LIST)
	check(number.convert("12.5") == 12.5 && number.convert(7) == 7, "number port converts text and keeps numbers")
	check(isnull(number.convert("abc")) && isnull(number.convert(list(1))), "number port rejects text that is not a number")
	check(isnull(number.convert(1e30 * 1e30)) && isnull(number.convert("1e999")), "number port rejects infinity")
	check(boolean.convert("Yes") == TRUE && boolean.convert("no") == FALSE && boolean.convert(5) == TRUE && boolean.convert(0) == FALSE, "boolean port conversion")
	check(string.convert(5) == "5" && string.convert("x") == "x", "string port conversion")
	check(length(string.convert(long_text(PORT_MAX_STRING_LENGTH + 50))) <= PORT_MAX_STRING_LENGTH, "string port caps its length")
	var/mob/living/someone = new
	check(isnull(any.convert(someone)) && isnull(string.convert(someone)) && isnull(any.convert(world)), "ports never hold a game object")
	var/list/big = list()
	for(var/i in 1 to CIRCUIT_MAX_LIST_LENGTH + 100)
		big += i
	var/list/capped = list_type.convert(big)
	check(islist(capped) && length(capped) <= CIRCUIT_MAX_LIST_LENGTH && capped[1] == 1, "list port caps its length")
	var/list/mixed = any.convert(list(1, "two", someone, list(3)))
	check(islist(mixed) && length(mixed) == 2, "lists drop objects and nested lists")
	check(isnull(list_type.convert("text")), "list port rejects non-lists")
	check(isnull(circuit_datatype_for("/datum")) && isnull(circuit_datatype_for(3)), "unknown datatypes have no handler")
	// The submitted port returned FALSE here: `a || b in list` binds as `(a || b) in list`.
	check(number.can_receive_from_datatype(PORT_TYPE_NUMBER), "number input accepts a number output")
	check(number.can_receive_from_datatype(PORT_TYPE_BOOLEAN) && boolean.can_receive_from_datatype(PORT_TYPE_NUMBER), "number and boolean interconnect")
	check(!number.can_receive_from_datatype(PORT_TYPE_STRING) && !number.can_receive_from_datatype(PORT_TYPE_LIST), "number input rejects text and lists")
	check(string.can_receive_from_datatype(PORT_TYPE_NUMBER) && any.can_receive_from_datatype(PORT_TYPE_LIST), "string and any inputs accept other types")
	check(list_type.can_receive_from_datatype(PORT_TYPE_LIST) && !list_type.can_receive_from_datatype(PORT_TYPE_STRING), "list input accepts only lists")
	qdel(someone)

/proc/test_connections(mob/living/user)
	var/obj/item/integrated_circuit/circuit = new(user)
	var/obj/item/integrated_circuit/other = new(user)
	var/obj/item/circuit_component/operator/arithmetic/first = print(circuit, user, /obj/item/circuit_component/operator/arithmetic)
	var/obj/item/circuit_component/operator/arithmetic/second = print(circuit, user, /obj/item/circuit_component/operator/arithmetic)
	var/obj/item/circuit_component/operator/arithmetic/third = print(circuit, user, /obj/item/circuit_component/operator/arithmetic)
	var/obj/item/circuit_component/operator/string_concat/text = print(circuit, user, /obj/item/circuit_component/operator/string_concat)
	var/obj/item/circuit_component/operator/arithmetic/foreign = print(other, user, /obj/item/circuit_component/operator/arithmetic)
	check(first && second && third && text && foreign, "editor prints components")
	if(!first || !second || !third || !text || !foreign)
		return
	check(first.loc == circuit && first.parent == circuit && first.rel_x == 10 && first.rel_y == 20, "printed component sits in the circuit at the requested place")
	enter(circuit, user, first, 1, 2)
	enter(circuit, user, first, 2, 3)
	check(output_value(first) == 5, "arithmetic adds manual inputs")
	check(wire(circuit, user, first, 1, second, 1), "number output connects to number input")
	check(second.input_a.value == 5, "connecting copies the current output value")
	check(second.input_a in first.result.connected_inputs, "output records its connected input")
	enter(circuit, user, second, 1, 99)
	check(second.input_a.value == 5, "a wired input ignores manual values")
	enter(circuit, user, second, 2, 10)
	check(output_value(second) == 15, "values propagate through a connection")
	enter(circuit, user, first, 1, 20)
	check(output_value(second) == 33, "a changed input propagates downstream")
	check(wire(circuit, user, third, 1, second, 1), "an input can be rewired to another output")
	check(!(second.input_a in first.result.connected_inputs), "rewiring removes the input from the old output")
	check(!wire(circuit, user, text, 1, second, 2), "text output cannot feed a number input")
	check(wire(circuit, user, first, 1, text, 1), "number output can feed a text input")
	check(text.input_a.value == "23", "number arrives as text")
	check(!second.input_b.connect(foreign.result), "ports of different circuits cannot be connected")
	act(circuit, user, "remove_connection", list("component_id" = index_of(circuit, second), "is_input" = 1, "port_id" = 1))
	check(isnull(second.input_a.connected_output) && !(second.input_a in third.result.connected_inputs), "remove_connection clears both ends of an input link")
	act(circuit, user, "remove_connection", list("component_id" = index_of(circuit, first), "is_input" = 0, "port_id" = 1))
	check(isnull(text.input_a.connected_output) && !length(first.result.connected_inputs), "remove_connection clears every link of an output")
	// Removing a component cleans up its connections.
	wire(circuit, user, first, 1, second, 1)
	wire(circuit, user, first, 1, text, 1)
	wire(circuit, user, third, 1, first, 2)
	var/first_ref = "\ref[first]"
	var/count = length(circuit.attached_components)
	act(circuit, user, "detach_component", list("component_id" = index_of(circuit, first)))
	check(length(circuit.attached_components) == count - 1 && !(first in circuit.attached_components), "detach removes the component")
	check(isnull(second.input_a.connected_output) && isnull(text.input_a.connected_output), "detach clears links into other components")
	check(!length(third.result.connected_inputs), "detach clears links out of other components")
	check(first.gc_destroyed && isnull(first.loc) && user.held != first, "a component printed in the editor is deleted on removal, not handed out")
	first = null
	sleep(1)
	check(isnull(locate(first_ref)), "a removed component is garbage collected")
	qdel(circuit)
	qdel(other)

/proc/test_components(mob/living/user)
	var/obj/item/integrated_circuit/circuit = new(user)
	var/obj/item/circuit_component/operator/arithmetic/math = print(circuit, user, /obj/item/circuit_component/operator/arithmetic)
	enter(circuit, user, math, 1, 7.5)
	enter(circuit, user, math, 2, 2)
	var/list/expected = list("Subtract" = 5.5, "Multiply" = 15, "Divide" = 3.75, "Modulo" = 1.5, "Power" = 56.25, "Minimum" = 2, "Maximum" = 7.5, "Add" = 9.5)
	for(var/operation in expected)
		enter(circuit, user, math, 3, operation)
		check(output_value(math) == expected[operation], "arithmetic [operation]")
	enter(circuit, user, math, 3, "Explode")
	check(math.operation.value == "Add", "an option input ignores a value outside its choices")
	enter(circuit, user, math, 3, "Divide")
	enter(circuit, user, math, 2, 0)
	check(isnull(output_value(math)), "division by zero gives no value")
	enter(circuit, user, math, 3, "Power")
	enter(circuit, user, math, 1, -8)
	enter(circuit, user, math, 2, 0.5)
	check(isnull(output_value(math)), "a negative base with a fractional power gives no value")
	enter(circuit, user, math, 1, 10)
	enter(circuit, user, math, 2, 5000)
	check(isnull(output_value(math)), "an overflowing power gives no value")

	var/obj/item/circuit_component/operator/comparison/compare = print(circuit, user, /obj/item/circuit_component/operator/comparison)
	enter(circuit, user, compare, 1, 3)
	enter(circuit, user, compare, 2, 4)
	enter(circuit, user, compare, 3, "Less Than")
	check(output_value(compare) == TRUE, "comparison less than")
	enter(circuit, user, compare, 3, "Greater Than or Equal")
	check(output_value(compare) == FALSE, "comparison greater than or equal")
	enter(circuit, user, compare, 1, "same")
	enter(circuit, user, compare, 2, "same")
	enter(circuit, user, compare, 3, "Equal")
	check(output_value(compare) == TRUE, "comparison of equal text")

	var/obj/item/circuit_component/operator/logic/gate = print(circuit, user, /obj/item/circuit_component/operator/logic)
	enter(circuit, user, gate, 1, 1)
	enter(circuit, user, gate, 2, 0)
	check(output_value(gate) == FALSE, "logic AND")
	enter(circuit, user, gate, 3, "OR")
	check(output_value(gate) == TRUE, "logic OR")
	enter(circuit, user, gate, 3, "XOR")
	check(output_value(gate) == TRUE, "logic XOR")
	enter(circuit, user, gate, 2, "garbage")
	check(gate.input_b.value == 0, "a boolean input rejects text that is not a truth value")

	var/obj/item/circuit_component/operator/string_concat/join = print(circuit, user, /obj/item/circuit_component/operator/string_concat)
	enter(circuit, user, join, 1, "red,")
	enter(circuit, user, join, 2, "Green,blue")
	check(output_value(join) == "red,Green,blue", "string concat")
	var/obj/item/circuit_component/string_case/case = print(circuit, user, /obj/item/circuit_component/string_case)
	wire(circuit, user, join, 1, case, 1)
	check(output_value(case) == "red,green,blue", "string case lower")
	enter(circuit, user, case, 2, "Upper")
	check(output_value(case) == "RED,GREEN,BLUE", "string case upper")
	var/obj/item/circuit_component/string_contains/contains = print(circuit, user, /obj/item/circuit_component/string_contains)
	wire(circuit, user, join, 1, contains, 1)
	enter(circuit, user, contains, 2, "green")
	check(output_value(contains) == TRUE, "string contains")
	enter(circuit, user, contains, 2, "purple")
	check(output_value(contains) == FALSE, "string does not contain")
	var/obj/item/circuit_component/string_replace/replace = print(circuit, user, /obj/item/circuit_component/string_replace)
	wire(circuit, user, join, 1, replace, 1)
	enter(circuit, user, replace, 2, ",")
	enter(circuit, user, replace, 3, " and ")
	check(output_value(replace) == "red and Green and blue", "string replace with a longer replacement")
	enter(circuit, user, replace, 3, "")
	check(output_value(replace) == "redGreenblue", "string replace with nothing")
	var/obj/item/circuit_component/string_to_number/to_number = print(circuit, user, /obj/item/circuit_component/string_to_number)
	enter(circuit, user, to_number, 1, "42")
	check(output_value(to_number) == 42, "string to number")
	enter(circuit, user, to_number, 1, "forty-two")
	check(isnull(output_value(to_number)), "string to number rejects words")

	var/obj/item/circuit_component/string_split/split = print(circuit, user, /obj/item/circuit_component/string_split)
	wire(circuit, user, join, 1, split, 1)
	var/list/parts = output_value(split)
	check(islist(parts) && length(parts) == 3 && parts[2] == "Green", "string split")
	var/obj/item/circuit_component/length/size = print(circuit, user, /obj/item/circuit_component/length)
	wire(circuit, user, split, 1, size, 1)
	check(output_value(size) == 3, "length of a list")
	var/obj/item/circuit_component/list_index/pick_entry = print(circuit, user, /obj/item/circuit_component/list_index)
	wire(circuit, user, split, 1, pick_entry, 1)
	enter(circuit, user, pick_entry, 2, 3)
	check(output_value(pick_entry) == "blue", "list index")
	enter(circuit, user, pick_entry, 2, 4)
	check(isnull(output_value(pick_entry)), "list index past the end gives no value")
	enter(circuit, user, pick_entry, 2, 0.5)
	check(isnull(output_value(pick_entry)), "list index below one gives no value")
	var/obj/item/circuit_component/list_add/append = print(circuit, user, /obj/item/circuit_component/list_add)
	wire(circuit, user, split, 1, append, 1)
	enter(circuit, user, append, 2, "black")
	var/list/appended = output_value(append)
	check(length(appended) == 4 && appended[4] == "black" && length(output_value(split)) == 3, "list add appends to a copy")
	var/obj/item/circuit_component/list_remove/drop = print(circuit, user, /obj/item/circuit_component/list_remove)
	wire(circuit, user, append, 1, drop, 1)
	enter(circuit, user, drop, 2, "red")
	var/list/dropped = output_value(drop)
	check(length(dropped) == 3 && !("red" in dropped) && length(output_value(append)) == 4, "list remove takes from a copy")
	var/obj/item/circuit_component/operator/list_concat/merge = print(circuit, user, /obj/item/circuit_component/operator/list_concat)
	wire(circuit, user, split, 1, merge, 1)
	wire(circuit, user, drop, 1, merge, 2)
	check(length(output_value(merge)) == 6, "list concat")

	var/obj/item/circuit_component/random/dice = print(circuit, user, /obj/item/circuit_component/random)
	enter(circuit, user, dice, 1, 3)
	enter(circuit, user, dice, 2, 5)
	check(isnull(output_value(dice)), "random waits for its trigger")
	var/in_range = TRUE
	for(var/i in 1 to 20)
		act(circuit, user, "set_component_input", list("component_id" = index_of(circuit, dice), "port_id" = 3))
		var/rolled = output_value(dice)
		if(!isnum(rolled) || rolled < 3 || rolled > 5 || rolled != round(rolled))
			in_range = FALSE
	check(in_range, "random stays inside its bounds when its signal input is pressed")
	enter(circuit, user, dice, 1, -1e30)
	enter(circuit, user, dice, 2, 1e30)
	act(circuit, user, "set_component_input", list("component_id" = index_of(circuit, dice), "port_id" = 3))
	check(isnum(output_value(dice)) && abs(output_value(dice)) <= 1e7, "random clamps absurd bounds")

	// Variables.
	act(circuit, user, "add_variable", list("variable_name" = "score", "variable_datatype" = PORT_TYPE_NUMBER, "is_list" = 0, "is_assoc_list" = 0))
	check(length(circuit.circuit_variables) == 1 && circuit.circuit_variables["score"], "add_variable creates a variable")
	var/before = length(circuit.attached_components)
	act(circuit, user, "add_setter_or_getter", list("variable" = "score", "is_setter" = 1, "rel_x" = 0, "rel_y" = 0))
	act(circuit, user, "add_setter_or_getter", list("variable" = "score", "is_setter" = 0, "rel_x" = 0, "rel_y" = 0))
	check(length(circuit.attached_components) == before + 2, "setter and getter nodes are added")
	if(length(circuit.attached_components) == before + 2)
		var/obj/item/circuit_component/variable/setter/setter = circuit.attached_components[before + 1]
		var/obj/item/circuit_component/variable/getter/getter = circuit.attached_components[before + 2]
		enter(circuit, user, setter, 1, 12)
		check(output_value(getter) == 12, "a setter updates every getter of its variable")
		var/datum/circuit_variable/variable = circuit.circuit_variables["score"]
		act(circuit, user, "remove_variable", list("variable_name" = "score"))
		check(!length(circuit.circuit_variables) && length(circuit.attached_components) == before, "remove_variable deletes the variable and its nodes")
		check(setter.gc_destroyed && getter.gc_destroyed && variable.gc_destroyed && !length(variable.listeners), "variable nodes are deleted with their variable")
	// The editor data must always be valid JSON for the window.
	var/encoded = json_encode(circuit.circuit_editor_data())
	var/decoded
	try
		decoded = json_decode(encoded)
	catch
		decoded = null
	check(islist(decoded) && length(decoded["components"]) == length(circuit.attached_components), "editor data is valid JSON")
	check(!findtext(encoded, "inf") && !findtext(encoded, "nan"), "editor data holds no non-finite numbers")
	var/list/first_view = decoded ? decoded["components"][1] : null
	var/list/option_port = first_view ? first_view["input_ports"][3] : null
	check(option_port && option_port["type"] == "option" && ("Divide" in option_port["datatype_data"]), "operation inputs are sent as dropdown choices")
	qdel(circuit)

/proc/test_limits(mob/living/user)
	var/obj/item/integrated_circuit/circuit = new(user)
	// A component wired to itself.
	var/obj/item/circuit_component/operator/arithmetic/loop = print(circuit, user, /obj/item/circuit_component/operator/arithmetic)
	enter(circuit, user, loop, 2, 1)
	wire(circuit, user, loop, 1, loop, 1)
	chat_log.Cut()
	enter(circuit, user, loop, 1, 0)
	act(circuit, user, "remove_connection", list("component_id" = 1, "is_input" = 1, "port_id" = 1))
	enter(circuit, user, loop, 1, 0)
	wire(circuit, user, loop, 1, loop, 1)
	var/looped = output_value(loop)
	check(isnum(looped) && looped > 0 && looped <= CIRCUIT_MAX_EXECUTIONS + 2, "a feedback loop stops at the execution limit (reached [looped])")
	check(!circuit.is_executing && !length(circuit.execution_queue), "the circuit is idle after a feedback loop")
	check(circuit.overloaded_until > world.time, "a feedback loop overloads the circuit")
	check(length(chat_log) && findtext(chat_log[length(chat_log)], "overload"), "the holder is told about the overload")
	var/frozen = output_value(loop)
	enter(circuit, user, loop, 2, 5)
	check(output_value(loop) == frozen, "an overloaded circuit ignores inputs")
	sleep(CIRCUIT_OVERLOAD_COOLDOWN + 2)
	act(circuit, user, "remove_connection", list("component_id" = 1, "is_input" = 1, "port_id" = 1))
	enter(circuit, user, loop, 1, 1)
	check(output_value(loop) == 6, "the circuit works again after the overload passes")

	// Two list concatenators feeding each other double the list on every pass.
	var/obj/item/circuit_component/string_split/seed = print(circuit, user, /obj/item/circuit_component/string_split)
	var/obj/item/circuit_component/operator/list_concat/left = print(circuit, user, /obj/item/circuit_component/operator/list_concat)
	var/obj/item/circuit_component/operator/list_concat/right = print(circuit, user, /obj/item/circuit_component/operator/list_concat)
	wire(circuit, user, seed, 1, left, 2)
	wire(circuit, user, left, 1, right, 1)
	wire(circuit, user, left, 1, right, 2)
	wire(circuit, user, right, 1, left, 1)
	enter(circuit, user, seed, 1, "a,b,c,d")
	check(length(output_value(left)) <= CIRCUIT_MAX_LIST_LENGTH && length(output_value(right)) <= CIRCUIT_MAX_LIST_LENGTH, "a doubling list loop stays within the list limit")
	check(!circuit.is_executing, "the circuit is idle after a list loop")
	sleep(CIRCUIT_OVERLOAD_COOLDOWN + 2)
	var/started = world.timeofday

	// A replacement that would multiply a long text.
	var/obj/item/circuit_component/string_replace/bomb = print(circuit, user, /obj/item/circuit_component/string_replace)
	bomb.value_input.set_input(long_text(PORT_MAX_STRING_LENGTH - 1), FALSE)
	bomb.replacement.set_input(long_text(PORT_MAX_STRING_LENGTH - 1), FALSE)
	enter(circuit, user, bomb, 2, "a")
	check(length(output_value(bomb)) <= PORT_MAX_STRING_LENGTH && length(output_value(bomb)) > 0, "a multiplying replacement stays within the text limit")
	check(world.timeofday - started < 50, "the limit cases finish quickly")
	var/obj/item/circuit_component/string_split/splitter = print(circuit, user, /obj/item/circuit_component/string_split)
	splitter.value_input.set_input(long_text(PORT_MAX_STRING_LENGTH - 1), FALSE)
	enter(circuit, user, splitter, 2, "")
	enter(circuit, user, splitter, 2, "a")
	check(length(output_value(splitter)) <= CIRCUIT_MAX_LIST_LENGTH, "splitting a long text stays within the list limit")

	// A failing component must not leave the circuit stuck.
	var/obj/item/circuit_component/probe_crash/crash = new(circuit)
	check(circuit.add_component(crash), "a hand-built component can be added")
	var/raised = FALSE
	try
		crash.trigger_input.set_input(1)
	catch
		raised = TRUE
	check(raised && crash_calls == 1, "a component failure is still reported")
	check(!circuit.is_executing && !length(circuit.execution_queue), "a component failure leaves the circuit idle")
	enter(circuit, user, loop, 1, 2)
	check(output_value(loop) == 7, "the circuit keeps working after a component failure")

	// Component and variable counts.
	for(var/i in 1 to CIRCUIT_MAX_COMPONENTS + 5)
		act(circuit, user, "print_component", list("component_to_print" = "/obj/item/circuit_component/operator/logic", "rel_x" = 0, "rel_y" = 0))
	check(length(circuit.attached_components) == CIRCUIT_MAX_COMPONENTS && length(circuit.contents) == CIRCUIT_MAX_COMPONENTS, "the component limit holds and refused components are not left behind")
	for(var/i in 1 to 40)
		act(circuit, user, "add_variable", list("variable_name" = "v[i]", "variable_datatype" = PORT_TYPE_ANY, "is_list" = 1))
	check(length(circuit.circuit_variables) <= 32, "the variable limit holds ([length(circuit.circuit_variables)])")
	act(circuit, user, "add_setter_or_getter", list("variable" = "v1", "is_setter" = 0, "rel_x" = 0, "rel_y" = 0))
	check(length(circuit.attached_components) == CIRCUIT_MAX_COMPONENTS && length(circuit.contents) == CIRCUIT_MAX_COMPONENTS, "variable nodes respect the component limit")
	qdel(circuit)

/proc/test_delay(mob/living/user)
	var/obj/item/integrated_circuit/circuit = new(user)
	var/obj/item/circuit_component/delay/timer = print(circuit, user, /obj/item/circuit_component/delay)
	var/obj/item/circuit_component/random/dice = print(circuit, user, /obj/item/circuit_component/random)
	check(wire(circuit, user, timer, 1, dice, 3), "delay output connects to a signal input")
	enter(circuit, user, timer, 1, 0)
	act(circuit, user, "set_component_input", list("component_id" = index_of(circuit, timer), "port_id" = 2))
	check(timer.timer_id && isnull(output_value(dice)), "delay does not fire at once")
	sleep(CIRCUIT_DELAY_MIN * 10 - 3)
	check(isnull(output_value(dice)), "delay holds for at least the minimum delay")
	sleep(6)
	check(isnum(output_value(dice)) && !timer.timer_id, "delay fires its output after the delay")
	// Retriggering restarts the wait; it never stacks timers.
	enter(circuit, user, timer, 1, 2)
	for(var/i in 1 to 5)
		act(circuit, user, "set_component_input", list("component_id" = index_of(circuit, timer), "port_id" = 2))
	check(length(active_timers) == 1, "retriggering a delay keeps one timer")
	enter(circuit, user, timer, 1, 1e9)
	act(circuit, user, "set_component_input", list("component_id" = index_of(circuit, timer), "port_id" = 2))
	check(length(active_timers) == 1, "a huge delay is accepted as the maximum")
	act(circuit, user, "detach_component", list("component_id" = index_of(circuit, timer)))
	check(!length(active_timers), "deleting a waiting delay cancels its timer")
	qdel(circuit)

/proc/test_untrusted_input(mob/living/user)
	var/obj/item/integrated_circuit/circuit = new(user)
	var/obj/item/circuit_component/operator/arithmetic/math = print(circuit, user, /obj/item/circuit_component/operator/arithmetic)
	var/obj/item/circuit_component/operator/arithmetic/second = print(circuit, user, /obj/item/circuit_component/operator/arithmetic)
	enter(circuit, user, math, 1, 4)
	enter(circuit, user, math, 2, 4)
	var/atoms_before = length(world.contents)
	// Only listed component types can be created.
	for(var/bad_type in list("/mob/living", "/obj/item/compact_remote", "/obj/item/circuit_component", "/obj/item/circuit_component/variable/getter", "/obj/item/circuit_component/operator", "/obj/item/circuit_component/arithmetic", "/obj/item/circuit_component/compact_remote", "/datum", "", 5, "/obj/item/circuit_component/operator/arithmetic/"))
		act(circuit, user, "print_component", list("component_to_print" = bad_type, "rel_x" = 0, "rel_y" = 0))
	check(length(circuit.attached_components) == 2 && length(world.contents) == atoms_before, "print_component only creates listed component types")
	// Component and port numbers.
	for(var/bad_index in list(0, -1, 1.5, 4, 999999, "abc", "", "1e9", "-0", "1.5", 1e30))
		act(circuit, user, "detach_component", list("component_id" = bad_index))
		act(circuit, user, "set_component_coordinates", list("component_id" = bad_index, "rel_x" = 5, "rel_y" = 5))
		act(circuit, user, "set_component_input", list("component_id" = bad_index, "port_id" = 1, "input" = 77))
		act(circuit, user, "set_component_input", list("component_id" = 1, "port_id" = bad_index, "input" = 77))
		act(circuit, user, "get_component_value", list("component_id" = bad_index, "port_id" = 1))
		act(circuit, user, "get_component_value", list("component_id" = 1, "port_id" = bad_index))
		act(circuit, user, "set_examined_component", list("component_id" = bad_index, "x" = 1, "y" = 1))
		act(circuit, user, "remove_connection", list("component_id" = bad_index, "is_input" = 1, "port_id" = 1))
		act(circuit, user, "remove_connection", list("component_id" = 1, "is_input" = 0, "port_id" = bad_index))
		act(circuit, user, "add_connection", list("input_component_id" = bad_index, "input_port_id" = 1, "output_component_id" = 1, "output_port_id" = 1))
		act(circuit, user, "add_connection", list("input_component_id" = 2, "input_port_id" = bad_index, "output_component_id" = 1, "output_port_id" = bad_index))
	check(length(circuit.attached_components) == 2 && math.input_a.value == 4 && output_value(math) == 8, "out-of-range component and port numbers change nothing")
	check(isnull(second.input_a.connected_output) && isnull(circuit.examined_component), "out-of-range numbers make no links")
	// Missing fields and wrong value types.
	for(var/action in circuit.ui_actions("main"))
		act(circuit, user, action, list())
		act(circuit, user, action, list("component_id" = list(1), "port_id" = circuit, "input" = user, "variable" = 1, "variable_name" = 2, "display_name" = 3, "component_to_print" = /obj/item/circuit_component/operator/arithmetic, "is_input" = "maybe", "variable_datatype" = 4))
	act(circuit, user, "not_an_action", list("component_id" = 1))
	act(circuit, user, "set_component_input", null)
	check(length(circuit.attached_components) == 2 && !length(circuit.circuit_variables), "requests with missing or mistyped fields are ignored")
	// Manual values.
	enter(circuit, user, math, 1, "abc")
	enter(circuit, user, math, 1, "1e999")
	enter(circuit, user, math, 1, long_text(PORT_MAX_STRING_LENGTH + 10))
	check(math.input_a.value == 4, "a number input rejects text, infinity and oversized input")
	act(circuit, user, "set_component_input", list("component_id" = 1, "port_id" = 1, "input" = 9, "marked_atom" = 1))
	check(math.input_a.value == 4, "entity inputs are refused")
	act(circuit, user, "set_component_input", list("component_id" = 1, "port_id" = 1, "set_null" = 1))
	check(isnull(math.input_a.value), "set_null clears an unwired input")
	act(circuit, user, "set_component_input", list("component_id" = 1, "port_id" = 3, "set_null" = 1))
	check(math.operation.value == "Add", "set_null leaves an option input on a valid choice")
	// Variable names: a number must never index the variable list by position.
	act(circuit, user, "add_variable", list("variable_name" = "kept", "variable_datatype" = PORT_TYPE_NUMBER))
	act(circuit, user, "remove_variable", list("variable_name" = 1))
	act(circuit, user, "add_setter_or_getter", list("variable" = 1, "is_setter" = 1))
	act(circuit, user, "add_setter_or_getter", list("variable" = "missing", "is_setter" = 0))
	check(length(circuit.circuit_variables) == 1 && length(circuit.attached_components) == 2, "a number is never accepted as a variable name")
	act(circuit, user, "add_variable", list("variable_name" = "kept", "variable_datatype" = PORT_TYPE_NUMBER))
	act(circuit, user, "add_variable", list("variable_name" = "", "variable_datatype" = PORT_TYPE_NUMBER))
	act(circuit, user, "add_variable", list("variable_name" = "   ", "variable_datatype" = PORT_TYPE_NUMBER))
	act(circuit, user, "add_variable", list("variable_name" = "typed", "variable_datatype" = PORT_TYPE_LIST))
	act(circuit, user, "add_variable", list("variable_name" = "typed", "variable_datatype" = "/datum"))
	act(circuit, user, "add_variable", list("variable_name" = "typed", "variable_datatype" = PORT_TYPE_SIGNAL))
	check(length(circuit.circuit_variables) == 1, "duplicate, empty and mistyped variables are refused")
	act(circuit, user, "add_variable", list("variable_name" = "<img src=x>", "variable_datatype" = PORT_TYPE_NUMBER))
	var/markup_free = TRUE
	for(var/variable_name in circuit.circuit_variables)
		if(findtext(variable_name, "<") || findtext(variable_name, ">"))
			markup_free = FALSE
	check(markup_free, "variable names carry no markup")
	// The label reaches chat and examine text, which render HTML.
	act(circuit, user, "set_display_name", list("display_name" = "<b onmouseover=x>Door&opener</b>\[icon\]"))
	check(!findtext(circuit.name, "<") && !findtext(circuit.name, ">") && !findtext(circuit.name, "&") && !findtext(circuit.name, "\["), "the circuit label carries no markup ([circuit.name])")
	check(findtext(circuit.name, "Dooropener") && length(circuit.name) < 60, "the circuit label keeps its plain text")
	act(circuit, user, "set_display_name", list("display_name" = long_text(4000)))
	check(length(circuit.name) < 60, "the circuit label is length limited")
	act(circuit, user, "set_display_name", list("display_name" = ""))
	check(circuit.name == initial(circuit.name), "an empty label restores the item name")
	// Coordinates are clamped.
	act(circuit, user, "set_component_coordinates", list("component_id" = 1, "rel_x" = 1e30, "rel_y" = "-1e30"))
	check(math.rel_x == 10000 && math.rel_y == -10000, "component coordinates are clamped")
	act(circuit, user, "move_screen", list("screen_x" = "x", "screen_y" = 1e30))
	check(circuit.screen_x == 0 && circuit.screen_y == 10000, "screen coordinates are clamped")
	// Examine prints text; it must not raise.
	var/examined = FALSE
	try
		circuit.examine(user)
		examined = TRUE
	catch
		examined = FALSE
	check(examined, "examining a circuit does not raise")

	// Who may use the editor.
	var/mob/living/stranger = new(locate(5, 5, 1))
	var/mob/observer/ghost = new(user.loc)
	var/mob/living/neighbour = new(locate(2, 1, 1))
	var/count = length(circuit.attached_components)
	act(circuit, stranger, "detach_component", list("component_id" = 1))
	act(circuit, ghost, "detach_component", list("component_id" = 1))
	act(circuit, neighbour, "detach_component", list("component_id" = 1))
	act(circuit, null, "detach_component", list("component_id" = 1))
	check(length(circuit.attached_components) == count, "a distant player, a ghost and a bystander cannot edit a held circuit")
	user.stat = DEAD
	act(circuit, user, "detach_component", list("component_id" = 1))
	user.stat = CONSCIOUS
	user.is_restrained = TRUE
	act(circuit, user, "detach_component", list("component_id" = 1))
	user.is_restrained = FALSE
	check(length(circuit.attached_components) == count, "a dead or restrained holder cannot edit")
	circuit.forceMove(user.loc)
	act(circuit, stranger, "detach_component", list("component_id" = 1))
	check(length(circuit.attached_components) == count, "a distant player cannot edit a circuit on the ground")
	act(circuit, neighbour, "detach_component", list("component_id" = 2))
	check(length(circuit.attached_components) == count - 1, "an adjacent player can edit a circuit on the ground")
	qdel(stranger)
	qdel(ghost)
	qdel(neighbour)
	qdel(circuit)

/proc/test_hand_components(mob/living/user)
	var/obj/item/integrated_circuit/circuit = new(user.loc)
	var/obj/item/circuit_component/operator/logic/loose = new(user)
	user.held = loose
	user.drops = 0
	circuit.attackby(loose, user)
	check(loose.parent == circuit && loose.loc == circuit && isnull(user.held) && user.drops == 1, "inserting a held component takes it out of the hand")
	check(!circuit.add_component(loose), "a component cannot be added twice")
	act(circuit, user, "detach_component", list("component_id" = 1))
	check(!loose.gc_destroyed && user.held == loose && isnull(loose.parent) && !length(circuit.attached_components), "a hand-inserted component returns to the hand")
	qdel(loose)
	qdel(circuit)

// Builds, uses and deletes a remote, and returns the refs of everything it
// owned. The objects are only reachable from this proc's frame afterwards, so
// once it returns nothing but a leak can keep them.
/proc/remote_lifecycle(mob/living/user)
	var/obj/item/compact_remote/remote = new(user)
	var/obj/item/integrated_circuit/circuit = remote.circuit
	check(circuit && circuit.loc == remote && length(circuit.attached_components) == 1, "a compact remote holds a circuit with its signal source")
	var/obj/item/circuit_component/compact_remote/source = remote.remote_input
	act(circuit, user, "detach_component", list("component_id" = 1))
	check(length(circuit.attached_components) == 1 && !source.gc_destroyed, "the remote's signal source cannot be removed")
	var/obj/item/circuit_component/random/dice = print(circuit, user, /obj/item/circuit_component/random)
	var/obj/item/circuit_component/operator/string_concat/greeting = print(circuit, user, /obj/item/circuit_component/operator/string_concat)
	var/obj/item/circuit_component/delay/timer = print(circuit, user, /obj/item/circuit_component/delay)
	check(dice && greeting && timer, "the remote's holder can edit its circuit")
	check(wire(circuit, user, source, 2, dice, 3) && wire(circuit, user, source, 1, greeting, 1) && wire(circuit, user, source, 2, timer, 2), "remote outputs connect")
	act(circuit, user, "add_variable", list("variable_name" = "who", "variable_datatype" = PORT_TYPE_ANY))
	act(circuit, user, "add_setter_or_getter", list("variable" = "who", "is_setter" = 1))
	act(circuit, user, "add_setter_or_getter", list("variable" = "who", "is_setter" = 0))
	var/obj/item/circuit_component/variable/setter/setter = circuit.attached_components[length(circuit.attached_components) - 1]
	wire(circuit, user, source, 1, setter, 1)
	act(circuit, user, "set_examined_component", list("component_id" = 2, "x" = 1, "y" = 1))
	enter(circuit, user, greeting, 2, " pressed it")
	user.name = "Probe Presser"
	remote.attack_self(user)
	check(isnum(output_value(dice)), "pressing the remote triggers its circuit")
	check(output_value(greeting) == "Probe Presser pressed it", "the remote reports who pressed it by name")
	var/datum/circuit_variable/variable = circuit.circuit_variables["who"]
	check(variable.value == "Probe Presser", "a variable stores the name, not the mob")
	var/holds_object = FALSE
	for(var/obj/item/circuit_component/component in circuit.attached_components)
		for(var/datum/port/port in component.input_ports + component.output_ports)
			if(istype(port.value, /datum))
				holds_object = TRUE
	check(!holds_object, "no port holds a reference to the presser")
	check(length(active_timers) == 1, "the pressed remote started its delay")

	// Deleting the remote frees the whole graph: nothing may keep a reference.
	var/list/refs = list("\ref[remote]", "\ref[circuit]", "\ref[variable]")
	for(var/obj/item/circuit_component/component in circuit.attached_components)
		refs += "\ref[component]"
		for(var/datum/port/port in component.input_ports + component.output_ports)
			refs += "\ref[port]"
	qdel(remote)
	check(circuit.gc_destroyed && source.gc_destroyed && dice.gc_destroyed && variable.gc_destroyed, "deleting the remote deletes its circuit, components and variables")
	check(!length(active_timers), "deleting the remote cancels its timers")
	return refs

/proc/test_remote_and_cleanup(mob/living/user)
	var/list/refs = remote_lifecycle(user)
	sleep(2)
	var/alive = 0
	for(var/ref in refs)
		var/datum/survivor = locate(ref)
		if(survivor)
			alive++
			world.log << "still referenced: [survivor.type]"
		survivor = null
	check(length(refs) >= 20 && !alive, "every object of a deleted remote is garbage collected ([alive] of [length(refs)] still referenced)")

// A component keeps the number the editor knows it by; a removed component's
// number is never given out again.
/proc/test_stable_ids(mob/living/user)
	var/obj/item/integrated_circuit/circuit = new(user)
	var/obj/item/circuit_component/operator/arithmetic/first = print(circuit, user, /obj/item/circuit_component/operator/arithmetic)
	var/obj/item/circuit_component/operator/arithmetic/second = print(circuit, user, /obj/item/circuit_component/operator/arithmetic)
	var/obj/item/circuit_component/operator/arithmetic/third = print(circuit, user, /obj/item/circuit_component/operator/arithmetic)
	check(first.circuit_id == 1 && second.circuit_id == 2 && third.circuit_id == 3, "components are numbered as they are added")
	wire(circuit, user, third, 1, first, 1)
	var/list/before = json_decode(json_encode(circuit.circuit_editor_data()))
	var/list/third_before = before["components"][3]
	check(third_before["id"] == 3 && third_before["output_ports"][1]["ref"] == "output-3-1", "the editor data names a component and its ports by its number")
	check(before["components"][1]["input_ports"][1]["connected_to"][1] == "output-3-1", "a wire is named by the numbers of its two components")
	act(circuit, user, "detach_component", list("component_id" = 2))
	check(second.gc_destroyed && length(circuit.attached_components) == 2 && circuit.attached_components[2] == third, "removing the second component moves the third up the list")
	check(third.circuit_id == 3 && first.circuit_id == 1, "the remaining components keep their numbers")
	var/list/after = json_decode(json_encode(circuit.circuit_editor_data()))
	var/list/third_after = after["components"][2]
	check(third_after["id"] == 3 && third_after["output_ports"][1]["ref"] == "output-3-1" && after["components"][1]["input_ports"][1]["connected_to"][1] == "output-3-1", "port and wire names do not change when another component is removed")
	// A request still in flight for the removed component must reach nothing.
	act(circuit, user, "set_component_coordinates", list("component_id" = 2, "rel_x" = 777, "rel_y" = 777))
	act(circuit, user, "set_component_input", list("component_id" = 2, "port_id" = 1, "input" = 55))
	act(circuit, user, "set_examined_component", list("component_id" = 2, "x" = 1, "y" = 1))
	act(circuit, user, "add_connection", list("input_component_id" = 2, "input_port_id" = 2, "output_component_id" = 1, "output_port_id" = 1))
	act(circuit, user, "detach_component", list("component_id" = 2))
	check(length(circuit.attached_components) == 2 && third.rel_x != 777 && first.rel_x != 777 && isnull(third.input_a.value) && isnull(third.input_b.connected_output) && isnull(circuit.examined_component), "a request for a removed component's number reaches no component")
	act(circuit, user, "set_component_coordinates", list("component_id" = 3, "rel_x" = 321, "rel_y" = 123))
	enter(circuit, user, third, 1, 8)
	check(third.rel_x == 321 && third.rel_y == 123 && third.input_a.value == 8, "a request for a kept number reaches the same component after a removal")
	var/obj/item/circuit_component/operator/logic/fourth = print(circuit, user, /obj/item/circuit_component/operator/logic)
	check(fourth && fourth.circuit_id == 4 && isnull(circuit.component_by_id(2)), "a removed component's number is not given to a new component")
	// A hand-inserted component gets a new number each time it goes in.
	var/obj/item/circuit_component/operator/logic/loose = new(user)
	circuit.add_component(loose)
	var/first_id = loose.circuit_id
	act(circuit, user, "detach_component", list("component_id" = first_id))
	check(first_id == 5 && loose.circuit_id == 0 && isnull(loose.parent), "a component taken out has no number")
	circuit.add_component(loose)
	check(loose.circuit_id == 6 && isnull(circuit.component_by_id(first_id)), "a component put back gets a new number")
	check(isnull(circuit.component_by_id(0)) && isnull(circuit.ui_component(0)) && isnull(circuit.ui_component(7)) && isnull(circuit.ui_component("6.5")), "numbers outside the ones handed out name nothing")
	// The count stops where whole numbers would stop being exact, rather than repeat.
	circuit.last_component_id = CIRCUIT_MAX_COMPONENT_ID
	check(CIRCUIT_MAX_COMPONENT_ID + 1 != CIRCUIT_MAX_COMPONENT_ID && CIRCUIT_MAX_COMPONENT_ID < 16777216, "the last component number is one whole numbers still count past")
	var/held = length(circuit.attached_components)
	chat_log.Cut()
	check(isnull(print(circuit, user, /obj/item/circuit_component/operator/logic)) && length(circuit.attached_components) == held && length(circuit.contents) == held && length(chat_log) == 1, "a circuit that has used up its numbers takes no more components")
	qdel(circuit)

// One table holds every action: its handler and its fields.
/proc/test_action_table(mob/living/user)
	var/obj/item/integrated_circuit/circuit = new(user)
	var/list/table = circuit.ui_action_table()
	var/list/actions = circuit.ui_actions("main")
	var/complete = length(table) >= 15 && length(actions) == length(table)
	var/list/handlers = list()
	for(var/action in table)
		var/list/entry = table[action]
		if(!(action in actions) || !islist(entry) || !length(entry) || entry[1] != "act_[action]" || !hascall(circuit, entry[1]))
			complete = FALSE
			world.log << "bad action entry: [action]"
			continue
		handlers += entry[1]
		var/list/fields = circuit.ui_action_fields("main", action)
		if(!islist(fields) || length(fields) != length(entry) - 1)
			complete = FALSE
		for(var/position in 2 to length(entry))
			if(!istext(entry[position]) || fields[position - 1] != entry[position])
				complete = FALSE
	check(complete, "every action has a handler named after it and its own fields")
	var/unregistered = 0
	for(var/handler in typesof(/obj/item/integrated_circuit/proc))
		var/handler_name = "[handler]"
		handler_name = copytext(handler_name, findlasttext(handler_name, "/") + 1)
		if(findtext(handler_name, "act_") == 1 && !(handler_name in handlers))
			unregistered++
			world.log << "handler without an action: [handler_name]"
	check(!unregistered, "every action handler is in the table")
	check(isnull(circuit.ui_action_fields("main", "not_an_action")) && isnull(circuit.ui_action_fields("main", 3)) && isnull(circuit.ui_action_fields("main", null)), "an unknown action has no fields")
	// A proc name is not an action: only table keys are dispatched.
	var/before = length(circuit.attached_components)
	act(circuit, user, "act_print_component", list("component_to_print" = "/obj/item/circuit_component/operator/logic"))
	act(circuit, user, "add_component", list("component_to_print" = "/obj/item/circuit_component/operator/logic"))
	act(circuit, user, "Destroy", list())
	act(circuit, user, 1, list())
	act(circuit, user, null, list())
	check(length(circuit.attached_components) == before && !circuit.gc_destroyed, "only the table's actions are dispatched")
	qdel(circuit)

// Every component type is either offered by the editor or listed as left out.
/proc/test_component_lists()
	var/list/available = wiremod_available_components()
	var/list/unlisted = wiremod_unlisted_components()
	var/list/unaccounted = typesof(/obj/item/circuit_component) - /obj/item/circuit_component - /obj/item/circuit_component/probe_crash
	var/both = 0
	var/bad = 0
	var/list/seen = list()
	for(var/typepath in available)
		if(!ispath(typepath, /obj/item/circuit_component) || (typepath in seen))
			bad++
		seen += typepath
		if(typepath in unlisted)
			both++
		unaccounted -= typepath
	for(var/typepath in unlisted)
		if(!ispath(typepath, /obj/item/circuit_component) || !istext(unlisted[typepath]) || length(unlisted[typepath]) < 10)
			bad++
		unaccounted -= typepath
	for(var/typepath in unaccounted)
		world.log << "component type in neither list: [typepath]"
	check(length(available) >= 16 && !bad && !both, "the two component lists hold component types, each once, each left-out type with a reason")
	check(!length(unaccounted), "every component type is offered or listed as left out ([length(unaccounted)] in neither)")
	var/list/catalog = wiremod_ui_component_catalog()
	var/usable = length(catalog) == length(available)
	for(var/list/entry in catalog)
		if(!length(entry["name"]) || !length(entry["input_ports"]) || !length(entry["output_ports"]) || entry["id"] != 0)
			usable = FALSE
		for(var/list/port in entry["input_ports"] + entry["output_ports"])
			if(port["ref"] != "")
				usable = FALSE
	check(usable, "every offered component has a name and ports, and menu entries carry no port names")

// One reading per datatype for what a player types.
/proc/test_manual_values(mob/living/user)
	// Each datatype is one handler that knows its own name and colour.
	var/list/colours = list(PORT_TYPE_ANY = "blue", PORT_TYPE_NUMBER = "green", PORT_TYPE_BOOLEAN = "yellow", PORT_TYPE_STRING = "orange", PORT_TYPE_SIGNAL = "purple", PORT_TYPE_LIST = "grey")
	var/registered = TRUE
	for(var/handler_type in typesof(/datum/circuit_datatype) - /datum/circuit_datatype)
		var/datum/circuit_datatype/fresh = new handler_type
		var/datum/circuit_datatype/known = circuit_datatype_for(fresh.datatype)
		if(!known || known.type != handler_type || known != circuit_datatype_for(fresh.datatype) || known.color != colours[fresh.datatype])
			registered = FALSE
		colours -= fresh.datatype
	check(registered && !length(colours), "every datatype has one handler with its own name and colour")
	check(wiremod_parse_boolean("On") == TRUE && wiremod_parse_boolean("off") == FALSE && wiremod_parse_boolean(2) == TRUE && wiremod_parse_boolean(0) == FALSE, "truth values are read from words and numbers")
	check(isnull(wiremod_parse_boolean("maybe")) && isnull(wiremod_parse_boolean(null)) && isnull(wiremod_parse_boolean(list(1))) && isnull(wiremod_parse_boolean(1e30 * 1e30)), "anything else is not a truth value")
	check(wiremod_ui_flag(1) == TRUE && wiremod_ui_flag("true") == TRUE && wiremod_ui_flag("maybe") == FALSE && wiremod_ui_flag(null) == FALSE, "a request flag that cannot be read is off")
	var/datum/circuit_datatype/boolean = circuit_datatype_for(PORT_TYPE_BOOLEAN)
	var/same_words = TRUE
	for(var/word in list("true", "yes", "on", "1", "TRUE", "false", "no", "off", "0", "Off", "maybe", "", "2"))
		var/typed = boolean.parse_manual(word)
		if(!isnull(typed) && typed != boolean.convert(word))
			same_words = FALSE
		if(isnull(typed) && boolean.convert(word) != FALSE)
			same_words = FALSE
	check(same_words, "a typed truth value and a wired one are read by the same words")
	var/obj/item/integrated_circuit/circuit = new(user)
	var/obj/item/circuit_component/operator/logic/gate = print(circuit, user, /obj/item/circuit_component/operator/logic)
	enter(circuit, user, gate, 1, "ON")
	check(gate.input_a.value == TRUE, "a boolean input takes a typed word")
	enter(circuit, user, gate, 1, "off")
	check(gate.input_a.value == FALSE, "a boolean input takes a typed negative")
	enter(circuit, user, gate, 1, 1)
	chat_log.Cut()
	enter(circuit, user, gate, 1, "garbage")
	check(gate.input_a.value == TRUE && length(chat_log) == 1 && findtext(chat_log[1], "Enter true or false."), "a boolean input refuses other text and says why")
	var/obj/item/circuit_component/operator/arithmetic/math = print(circuit, user, /obj/item/circuit_component/operator/arithmetic)
	enter(circuit, user, math, 1, "2.5")
	chat_log.Cut()
	enter(circuit, user, math, 1, "two")
	check(math.input_a.value == 2.5 && length(chat_log) == 1 && findtext(chat_log[1], "Enter a valid number."), "a number input takes typed digits and refuses words")
	var/obj/item/circuit_component/operator/comparison/compare = print(circuit, user, /obj/item/circuit_component/operator/comparison)
	enter(circuit, user, compare, 1, "12")
	check(compare.input_a.value == 12 && isnum(compare.input_a.value), "an untyped input reads plain digits as a number")
	enter(circuit, user, compare, 1, "012")
	check(compare.input_a.value == "012", "an untyped input keeps text that is not exactly a number")
	enter(circuit, user, compare, 1, 7)
	check(compare.input_a.value == 7, "an untyped input keeps a number")
	var/obj/item/circuit_component/operator/string_concat/join = print(circuit, user, /obj/item/circuit_component/operator/string_concat)
	enter(circuit, user, join, 1, 5)
	check(join.input_a.value == "5", "a text input turns a typed number into text")
	var/list/sent_types = circuit.circuit_editor_data()["global_basic_types"]
	var/settable = length(sent_types) == 4
	for(var/type_key in list(PORT_TYPE_NUMBER, PORT_TYPE_BOOLEAN, PORT_TYPE_STRING, PORT_TYPE_ANY))
		if(!(type_key in sent_types))
			settable = FALSE
	check(settable && !(PORT_TYPE_LIST in sent_types) && !(PORT_TYPE_SIGNAL in sent_types), "the editor is told the four types a player may set")
	enter(circuit, user, compare, 1, "apple")
	enter(circuit, user, compare, 3, "Less Than")
	enter(circuit, user, compare, 2, 3)
	check(isnull(output_value(compare)) || output_value(compare) == FALSE, "comparison: text and a number have no order")
	qdel(circuit)

// A wire hands a list on without copying it; nothing may change a port's list.
/proc/test_list_handoff(mob/living/user)
	var/obj/item/integrated_circuit/circuit = new(user)
	var/obj/item/circuit_component/string_split/split = print(circuit, user, /obj/item/circuit_component/string_split)
	var/obj/item/circuit_component/list_add/append = print(circuit, user, /obj/item/circuit_component/list_add)
	var/obj/item/circuit_component/list_remove/drop = print(circuit, user, /obj/item/circuit_component/list_remove)
	var/obj/item/circuit_component/operator/list_concat/merge = print(circuit, user, /obj/item/circuit_component/operator/list_concat)
	var/obj/item/circuit_component/list_index/pick_entry = print(circuit, user, /obj/item/circuit_component/list_index)
	var/obj/item/circuit_component/length/size = print(circuit, user, /obj/item/circuit_component/length)
	var/obj/item/circuit_component/operator/comparison/compare = print(circuit, user, /obj/item/circuit_component/operator/comparison)
	var/obj/item/circuit_component/operator/string_concat/text = print(circuit, user, /obj/item/circuit_component/operator/string_concat)
	wire(circuit, user, split, 1, append, 1)
	wire(circuit, user, split, 1, drop, 1)
	wire(circuit, user, split, 1, merge, 1)
	wire(circuit, user, split, 1, merge, 2)
	wire(circuit, user, split, 1, pick_entry, 1)
	wire(circuit, user, split, 1, size, 1)
	wire(circuit, user, split, 1, compare, 1)
	wire(circuit, user, split, 1, compare, 2)
	check(!wire(circuit, user, split, 1, text, 1), "a list output still cannot feed a text input")
	enter(circuit, user, append, 2, "d")
	enter(circuit, user, drop, 2, "a")
	enter(circuit, user, pick_entry, 2, 2)
	enter(circuit, user, split, 1, "a,b,c")
	var/list/source = split.result.value
	check(islist(source) && length(source) == 3, "the split made a list")
	check(append.list_input.value == source && merge.input_a.value == source && size.value_input.value == source, "list and untyped inputs take the output's list as it is")
	check(jointext(source, ",") == "a,b,c", "no component changed the list it was handed")
	check(jointext(output_value(append), ",") == "a,b,c,d" && jointext(output_value(drop), ",") == "b,c" && length(output_value(merge)) == 6 && output_value(pick_entry) == "b" && output_value(size) == 3, "the list components still give their results")
	check(output_value(append) != source && output_value(drop) != source && output_value(merge) != source, "a result is a new list, never the input list")
	enter(circuit, user, compare, 3, "Equal")
	check(output_value(compare) == FALSE, "a list is not equal to a list, even the same one")
	enter(circuit, user, compare, 3, "Not Equal")
	check(output_value(compare) == TRUE, "a list is unequal to a list")
	// What a component hands to an output is copied on the way in.
	var/list/mine = list("x", "y")
	split.result.set_output(mine)
	mine += "z"
	check(length(split.result.value) == 2 && split.result.value != mine && append.list_input.value == split.result.value, "an output keeps its own copy of the list it is given")
	// A variable keeps its own copy too.
	act(circuit, user, "add_variable", list("variable_name" = "kept", "variable_datatype" = PORT_TYPE_ANY, "is_list" = 1))
	act(circuit, user, "add_setter_or_getter", list("variable" = "kept", "is_setter" = 1))
	var/obj/item/circuit_component/variable/setter/setter = circuit.attached_components[length(circuit.attached_components)]
	wire(circuit, user, split, 1, setter, 1)
	var/datum/circuit_variable/variable = circuit.circuit_variables["kept"]
	check(islist(variable.value) && length(variable.value) == 2 && variable.value != split.result.value, "a variable holds its own copy of a list")
	// No component the editor offers changes a list it is handed.
	split.result.set_output(list("p", "q", "r"))
	var/list/shared = split.result.value
	var/fed = 0
	for(var/typepath in wiremod_available_components())
		var/obj/item/circuit_component/offered = print(circuit, user, typepath)
		if(!offered)
			check(FALSE, "the circuit has room for [typepath]")
			continue
		for(var/position in 1 to length(offered.input_ports))
			var/datum/port/input/fed_port = offered.input_ports[position]
			if(wire(circuit, user, split, 1, offered, position) && fed_port.value == shared)
				fed++
		for(var/position in 1 to length(offered.input_ports))
			var/datum/port/input/fed_port = offered.input_ports[position]
			if(fed_port.datatype == PORT_TYPE_SIGNAL && !fed_port.connected_output)
				act(circuit, user, "set_component_input", list("component_id" = offered.circuit_id, "port_id" = position))
		act(circuit, user, "detach_component", list("component_id" = offered.circuit_id))
	check(fed >= 10 && split.result.value == shared && jointext(shared, ",") == "p,q,r", "no offered component changes a list it is handed ([fed] inputs fed)")
	// Every value in the circuit is still a plain bounded one.
	var/plain = TRUE
	for(var/obj/item/circuit_component/component in circuit.attached_components)
		for(var/datum/port/port in component.input_ports + component.output_ports)
			var/held = port.value
			if(islist(held))
				var/list/held_list = held
				if(length(held_list) > CIRCUIT_MAX_LIST_LENGTH)
					plain = FALSE
				for(var/entry in held_list)
					if(!isnum(entry) && !istext(entry))
						plain = FALSE
			else if(!isnull(held) && !isnum(held) && !istext(held))
				plain = FALSE
	check(plain, "every port still holds only plain bounded values")
	// A value that is not a list is converted on every hop as before.
	var/obj/item/circuit_component/operator/logic/gate = print(circuit, user, /obj/item/circuit_component/operator/logic)
	var/obj/item/circuit_component/operator/arithmetic/math = print(circuit, user, /obj/item/circuit_component/operator/arithmetic)
	enter(circuit, user, math, 1, 3)
	enter(circuit, user, math, 2, 4)
	wire(circuit, user, math, 1, gate, 1)
	wire(circuit, user, math, 1, text, 1)
	check(gate.input_a.value == TRUE && text.input_a.value == "7", "numbers are still converted for boolean and text inputs")
	qdel(circuit)

// A running circuit refreshes an open editor a few times a second at most, and
// always sends the last state.
/proc/test_refresh_coalescing(mob/living/user)
	var/datum/probe_nanomanager/manager = GLOB.nanomanager
	var/obj/item/integrated_circuit/circuit = new(user)
	var/obj/item/circuit_component/operator/arithmetic/math = print(circuit, user, /obj/item/circuit_component/operator/arithmetic)
	enter(circuit, user, math, 2, 1)
	sleep(CIRCUIT_UI_REFRESH_INTERVAL + 1)
	// Nobody watching: nothing is held back and no timer is kept.
	var/start = manager.updates
	for(var/i in 1 to 5)
		enter(circuit, user, math, 1, i)
	check(manager.updates == start + 5 && !length(active_timers) && isnull(circuit.editor_refresh_timer), "a circuit without an open editor keeps no refresh timer")
	// An open editor: the first change is sent at once, the rest together.
	manager.watchers = 1
	start = manager.updates
	for(var/i in 1 to 50)
		enter(circuit, user, math, 1, i)
	check(manager.updates == start + 1, "fifty runs in one tick send one refresh at once ([manager.updates - start])")
	check(length(active_timers) == 1 && !isnull(circuit.editor_refresh_timer), "the later runs are held for one timed refresh")
	check(output_value(math) == 51, "the circuit itself ran every time")
	sleep(CIRCUIT_UI_REFRESH_INTERVAL + 1)
	check(manager.updates == start + 2 && !length(active_timers) && isnull(circuit.editor_refresh_timer), "the held refresh is sent once, after the interval ([manager.updates - start])")
	sleep(CIRCUIT_UI_REFRESH_INTERVAL + 1)
	check(manager.updates == start + 2, "nothing more is sent while the circuit is idle")
	// Spread over a second: a few refreshes, not one per run.
	start = manager.updates
	for(var/i in 1 to 10)
		for(var/j in 1 to 10)
			enter(circuit, user, math, 1, i * j)
		sleep(1)
	sleep(CIRCUIT_UI_REFRESH_INTERVAL + 1)
	var/sent = manager.updates - start
	check(sent >= 2 && sent <= round(10 / CIRCUIT_UI_REFRESH_INTERVAL) + 2, "a hundred runs over a second send a few refreshes ([sent])")
	check(!length(active_timers), "no refresh timer is left behind")
	// A circuit deleted with a refresh pending cancels it.
	enter(circuit, user, math, 1, 1)
	enter(circuit, user, math, 1, 2)
	check(length(active_timers) == 1, "a refresh is pending")
	start = manager.updates
	qdel(circuit)
	check(!length(active_timers), "deleting the circuit cancels its pending refresh")
	sleep(CIRCUIT_UI_REFRESH_INTERVAL + 1)
	check(manager.updates == start, "a deleted circuit sends no refresh")
	manager.watchers = 0

/world/New()
	world.OpenPort("none")
	spawn(0)
		var/mob/living/user = new(locate(1, 1, 1))
		for(var/test in list(/proc/test_datatypes, /proc/test_connections, /proc/test_components, /proc/test_limits, /proc/test_delay, /proc/test_untrusted_input, /proc/test_hand_components, /proc/test_stable_ids, /proc/test_action_table, /proc/test_component_lists, /proc/test_manual_values, /proc/test_list_handoff, /proc/test_refresh_coalescing, /proc/test_remote_and_cleanup))
			try
				call(test)(user)
			catch(var/exception/failure)
				failures++
				world.log << "FAIL [test] raised: [failure] ([failure.file]:[failure.line])"
		if(!failures)
			world.log << "PASS wiremod ([checks] checks)"
		else
			world.log << "FAILED wiremod: [failures] of [checks] checks"
		shutdown()
