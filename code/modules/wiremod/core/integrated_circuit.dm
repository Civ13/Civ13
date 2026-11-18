// The circuit: its components and the queue that runs them. The editor window is
// in circuit_ui.dm and circuit variables are in variables.dm.

// The components the editor's component menu offers, and the only types
// print_component will create. Kept by hand on purpose: a new component type is
// not reachable by players until someone adds it here.
/proc/wiremod_available_components()
	return list(
		/obj/item/circuit_component/operator/arithmetic,
		/obj/item/circuit_component/operator/comparison,
		/obj/item/circuit_component/operator/logic,
		/obj/item/circuit_component/not,
		/obj/item/circuit_component/length,
		/obj/item/circuit_component/random,
		/obj/item/circuit_component/list_index,
		/obj/item/circuit_component/operator/list_concat,
		/obj/item/circuit_component/list_add,
		/obj/item/circuit_component/list_remove,
		/obj/item/circuit_component/operator/string_concat,
		/obj/item/circuit_component/string_contains,
		/obj/item/circuit_component/string_case,
		/obj/item/circuit_component/string_replace,
		/obj/item/circuit_component/string_split,
		/obj/item/circuit_component/string_to_number,
		/obj/item/circuit_component/delay,
		/obj/item/circuit_component/direction,
	)

// Every other component type, with the reason it is not in the menu. The tests
// require each /obj/item/circuit_component subtype to be in exactly one of the
// two lists, so a new type cannot be left out of both by accident.
/proc/wiremod_unlisted_components()
	return list(
		/obj/item/circuit_component/operator = "Base of the two-input components; it does nothing itself.",
		/obj/item/circuit_component/variable = "Base of the variable nodes; it does nothing itself.",
		/obj/item/circuit_component/variable/getter = "Made from the variable menu, tied to one variable.",
		/obj/item/circuit_component/variable/setter = "Made from the variable menu, tied to one variable.",
		/obj/item/circuit_component/compact_remote = "Built into a compact remote; every remote has exactly one.",
	)

/obj/item/integrated_circuit
	name = "integrated circuit"
	desc = "A programmable circuit board. Use it in hand to add components and connect their ports."
	icon = 'icons/obj/devices/circuitry_n_data.dmi'
	icon_state = "integrated_circuit"
	w_class = ITEM_SIZE_SMALL
	// Components, ports and links are live graph state; circuits are not written to saves.
	should_save = FALSE

	var/list/obj/item/circuit_component/attached_components = list()
	// The last circuit_id handed to a component. It only ever counts up.
	var/last_component_id = 0
	var/list/datum/circuit_variable/circuit_variables = list()
	var/list/execution_queue = list()
	var/on = TRUE
	var/grid_mode = TRUE
	var/screen_x = 0
	var/screen_y = 0
	var/is_executing = FALSE
	// TRUE once a propagation tried to queue more than CIRCUIT_MAX_EXECUTIONS calls.
	var/queue_overflowed = FALSE
	// world.time until which an overloaded circuit ignores its inputs.
	var/overloaded_until = 0
	// The player's label, shown in the editor and after the item's name.
	var/display_name = ""
	var/obj/item/circuit_component/examined_component
	var/examined_rel_x = 0
	var/examined_rel_y = 0
	// world.time before which an open editor is not sent another refresh, and the
	// timer that sends the one held back until then.
	var/next_editor_refresh = 0
	var/editor_refresh_timer

/obj/item/integrated_circuit/Destroy()
	if(editor_refresh_timer)
		deltimer(editor_refresh_timer)
		editor_refresh_timer = null
	execution_queue.Cut()
	examined_component = null
	for(var/obj/item/circuit_component/component in attached_components.Copy())
		qdel(component)
	attached_components.Cut()
	for(var/variable_name in circuit_variables)
		qdel(circuit_variables[variable_name])
	circuit_variables.Cut()
	return ..()

/obj/item/integrated_circuit/proc/add_component(obj/item/circuit_component/component, mob/user)
	if(!istype(component) || component.parent || QDELETED(component) || QDELETED(src))
		return FALSE
	if(length(attached_components) >= CIRCUIT_MAX_COMPONENTS)
		if(user)
			to_chat(user, "<span class='warning'>The circuit is at its component limit.</span>")
		return FALSE
	if(last_component_id >= CIRCUIT_MAX_COMPONENT_ID)
		if(user)
			to_chat(user, "<span class='warning'>The circuit is worn out and takes no more components.</span>")
		return FALSE
	component.disconnect()
	if(ismob(component.loc))
		var/mob/holder = component.loc
		holder.drop_from_inventory(component, src)
	if(component.loc != src)
		component.forceMove(src)
	component.parent = src
	component.circuit_id = ++last_component_id
	attached_components += component
	component.rel_x = 48 + ((length(attached_components) - 1) * 24)
	component.rel_y = 64 + ((length(attached_components) - 1) * 24)
	return TRUE

// The attached component with this circuit_id, or null.
/obj/item/integrated_circuit/proc/component_by_id(id)
	for(var/obj/item/circuit_component/component as anything in attached_components)
		if(component.circuit_id == id)
			return component
	return null

// Unlinks a component. It stays inside the circuit unless a destination is
// given; the caller deletes it or hands it on.
/obj/item/integrated_circuit/proc/remove_component(obj/item/circuit_component/component, atom/destination = null)
	if(!component || component.parent != src)
		return FALSE
	if(examined_component == component)
		examined_component = null
	component.removed_from_circuit(src)
	component.disconnect()
	attached_components -= component
	component.parent = null
	component.circuit_id = 0
	if(destination)
		component.forceMove(destination)
	return TRUE

// Takes a component out for a user. One made in the editor is deleted; one
// inserted by hand goes back to the user.
/obj/item/integrated_circuit/proc/detach_component(obj/item/circuit_component/component, mob/user)
	if(!component || component.parent != src || !component.removable)
		return FALSE
	if(component.printed || !user)
		qdel(component)
		return TRUE
	remove_component(component, get_turf(src))
	user.put_in_hands(component)
	return TRUE

// Runs a component call and everything it sets off, breadth first. The queue is
// never trimmed while it runs, so its length is the number of calls this
// propagation has made: at CIRCUIT_MAX_EXECUTIONS the rest is dropped and the
// circuit overloads, which is what stops a feedback loop.
/obj/item/integrated_circuit/proc/queue_input(datum/port/input/input_port)
	if(!on || world.time < overloaded_until || !input_port || input_port.connected_component?.parent != src)
		return
	if(length(execution_queue) >= CIRCUIT_MAX_EXECUTIONS)
		queue_overflowed = TRUE
		return
	execution_queue += input_port
	if(is_executing)
		return
	is_executing = TRUE
	var/position = 0
	var/exception/failure
	try
		while(position < length(execution_queue))
			position++
			var/datum/port/input/next_input = execution_queue[position]
			if(next_input?.connected_component?.parent == src)
				next_input.connected_component.trigger_component(next_input)
	catch(var/exception/caught)
		failure = caught
	// Always reset, so a runtime in one component cannot leave the circuit
	// queueing forever behind a stuck flag.
	execution_queue.Cut()
	is_executing = FALSE
	if(queue_overflowed)
		queue_overflowed = FALSE
		overload()
	refresh_editor()
	if(failure)
		throw failure

/obj/item/integrated_circuit/proc/overload()
	overloaded_until = world.time + CIRCUIT_OVERLOAD_COOLDOWN
	var/atom/holder = loc
	while(holder && !ismob(holder) && !isturf(holder))
		holder = holder.loc
	if(ismob(holder))
		to_chat(holder, "<span class='warning'>[src] overloads and goes quiet for a few seconds. Something in it is feeding back on itself.</span>")

/obj/item/integrated_circuit/attackby(obj/item/item, mob/user)
	if(istype(item, /obj/item/circuit_component))
		var/obj/item/circuit_component/component = item
		if(add_component(component, user))
			to_chat(user, "<span class='notice'>You insert [component] into [src].</span>")
			refresh_editor()
			return TRUE
		return FALSE
	return ..()

/obj/item/integrated_circuit/attack_self(mob/user)
	ui_interact(user)

/obj/item/integrated_circuit/examine(mob/user)
	. = ..()
	to_chat(user, "It contains [length(attached_components)] component[length(attached_components) == 1 ? "" : "s"].")
	if(length(display_name))
		to_chat(user, "It is labelled \"[display_name]\".")
