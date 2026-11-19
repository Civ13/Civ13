// A list loop walks a list one entry at a time. On each entry it puts the entry
// and its position on its outputs and fires Next Index; whatever is wired from
// there runs, and may fire Accept Entry. Only once that chain has settled does
// the loop move on, so a comparison wired between the two can decide each entry.
//
// Filter List keeps the accepted entries and gives them as a list; For Each
// does the same walk without building a list.
/obj/item/circuit_component/list_loop
	display_name = "List Loop"
	category = "List"
	desc = "Walks a list one entry at a time."

	var/datum/port/input/list_input
	var/datum/port/input/trigger
	var/datum/port/input/accept_entry
	var/datum/port/output/element_output
	var/datum/port/output/index_output
	var/datum/port/output/next_index
	var/datum/port/output/filtered_output
	var/datum/port/output/on_finished
	var/datum/port/output/on_failed

	var/list/source = list()
	var/list/filtered = list()
	var/current_index = 0
	var/entries_taken = 0
	var/accepted = FALSE
	var/running = FALSE

/obj/item/circuit_component/list_loop/populate_ports()
	list_input = add_input_port("List Input", PORT_TYPE_LIST)
	trigger = add_input_port("Trigger", PORT_TYPE_SIGNAL, trigger = PROC_REF(start_run))
	accept_entry = add_input_port("Accept Entry", PORT_TYPE_SIGNAL, trigger = PROC_REF(accept_current))
	element_output = add_output_port("Element", PORT_TYPE_ANY)
	index_output = add_output_port("Index", PORT_TYPE_NUMBER)
	next_index = add_output_port("Next Index", PORT_TYPE_SIGNAL)
	on_finished = add_output_port("On Finished", PORT_TYPE_SIGNAL)
	on_failed = add_output_port("On Failed", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/list_loop/proc/start_run(datum/port/input/input)
	// A run already under way is left to finish: a second trigger must not
	// leave an old step waiting behind the new one.
	if(running)
		return
	var/list/entries = list_input.value
	if(!islist(entries))
		fail_run()
		return
	source = entries.Copy()
	filtered = list()
	current_index = 0
	entries_taken = 0
	running = TRUE
	walk_step()

/obj/item/circuit_component/list_loop/proc/accept_current(datum/port/input/input)
	if(running)
		accepted = TRUE

/obj/item/circuit_component/list_loop/proc/walk_step()
	if(!running)
		return
	current_index++
	if(current_index > length(source))
		finish_run()
		return
	entries_taken++
	if(entries_taken > CIRCUIT_MAX_LOOP_STEPS)
		fail_run()
		return
	accepted = FALSE
	element_output.set_output(source[current_index])
	index_output.set_output(current_index)
	next_index.set_output(COMPONENT_SIGNAL)
	// The chain from Next Index is still queued behind this call, so the step
	// that reads Accept Entry has to wait for the queue to drain.
	if(!running)
		return
	if(!parent)
		advance()
		return
	if(!parent.queue_continuation(CALLBACK(src, PROC_REF(advance))))
		running = FALSE

/obj/item/circuit_component/list_loop/proc/advance()
	if(!running)
		return
	if(accepted && length(filtered) < CIRCUIT_MAX_LIST_LENGTH)
		filtered += source[current_index]
	walk_step()

/obj/item/circuit_component/list_loop/proc/finish_run()
	running = FALSE
	if(filtered_output)
		filtered_output.set_output(filtered)
	on_finished.set_output(COMPONENT_SIGNAL)
	source = list()

/obj/item/circuit_component/list_loop/proc/fail_run()
	running = FALSE
	source = list()
	filtered = list()
	on_failed.set_output(COMPONENT_SIGNAL)

/obj/item/circuit_component/list_loop/removed_from_circuit(obj/item/integrated_circuit/circuit)
	running = FALSE
	source = list()

/obj/item/circuit_component/list_loop/Destroy()
	running = FALSE
	source = list()
	filtered = list()
	return ..()

/obj/item/circuit_component/list_loop/filter_list
	name = "filter list component"
	display_name = "Filter List"
	desc = "Walks List Input one entry at a time when a signal reaches Trigger. Each entry is put on Element with its Index and Next Index fires; a signal on Accept Entry during that step keeps the entry. On Finished fires at the end with the kept entries on Filtered List, and On Failed when the list is not a list or the walk is too long."

/obj/item/circuit_component/list_loop/filter_list/populate_ports()
	..()
	filtered_output = add_output_port("Filtered List", PORT_TYPE_LIST)

/obj/item/circuit_component/list_loop/for_each
	name = "for each component"
	display_name = "For Each"
	desc = "Walks List Input one entry at a time when a signal reaches Trigger, with each entry on Element and its Index. Next Index fires for each step and On Finished at the end. It keeps nothing; use Filter List to build a list of the accepted entries."
