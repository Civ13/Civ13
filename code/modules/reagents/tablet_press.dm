// Constructed tablets reuse the pill maker's buffer, never its legacy Topic transfers.
/proc/tablet_press_year_allowed()
	if (!map || !istext(map.age))
		return FALSE
	var/year = text2num(map.age)
	return isnum(year) && year == round(year) && "[year]" == map.age && year > 1843

/proc/tablet_press_build_allowed(mob/living/human/user, result_path)
	if (result_path != /obj/structure/chem_master/tablet_press/constructed)
		return TRUE
	return user && tablet_press_year_allowed() && map.is_node_done(user.civilization, "pharmacology")

/proc/tablet_press_finite(value)
	return isnum(value) && value == value && value - value == 0

// Raw data, not get_data(): preserve false, empty values and nested list contents.
/datum/tablet_metadata
	should_save = FALSE
	var/ok = TRUE
	var/value

/datum/tablet_metadata/New(input)
	value = copy_value(input, list(), 0, list(0, 0))

/datum/tablet_metadata/proc/copy_value(input, list/ancestors, depth, list/budget)
	if (isnull(input) || tablet_press_finite(input))
		return input
	if (istext(input))
		budget[2] += length(input)
		if (budget[2] > 4096)
			ok = FALSE
		return input
	if (!islist(input) || depth >= 4 || (input in ancestors))
		ok = FALSE
		return null
	var/list/original = input
	budget[1] += original.len
	if (budget[1] > 128)
		ok = FALSE
		return null
	var/list/path = ancestors.Copy()
	path.len++
	path[path.len] = original
	var/list/result = list()
	for (var/i = 1, i <= original.len, i++)
		var/key = original[i]
		var/copied = copy_value(key, path, depth + 1, budget)
		result.len++
		result[result.len] = copied
		if (istext(key) && !isnull(original[key]))
			result[key] = copy_value(original[key], path, depth + 1, budget)
		else if (!isnull(key) && !istext(key) && !isnum(key) && !isnull(original[key]))
			ok = FALSE
	return result

/proc/tablet_metadata_equal(left, right)
	if (isnull(left) || isnull(right))
		return isnull(left) && isnull(right)
	if (isnum(left) != isnum(right) || istext(left) != istext(right))
		return FALSE
	if (islist(left) != islist(right))
		return FALSE
	if (!islist(left))
		return left == right
	var/list/A = left
	var/list/B = right
	if (A.len != B.len)
		return FALSE
	for (var/i = 1, i <= A.len, i++)
		if (!tablet_metadata_equal(A[i], B[i]))
			return FALSE
		var/key = A[i]
		if (istext(key) && !tablet_metadata_equal(A[key], B[key]))
			return FALSE
	return TRUE

// Snapshots retain real reagent objects and the original list, including traces.
/datum/tablet_buffer_state
	should_save = FALSE
	var/datum/reagents/buffer
	var/atom/owner
	var/list/order
	var/list/listing
	var/list/volumes = list()
	var/list/data_refs = list()
	var/list/types = list()
	var/list/ids = list()
	var/list/phases = list()
	var/total
	var/maximum
	var/ok = TRUE

/datum/tablet_buffer_state/New(datum/reagents/source)
	buffer = source
	if (!source || !source.reagent_list || source.reagent_list.len > 128)
		ok = FALSE
		return
	owner = source.my_atom
	listing = source.reagent_list
	order = listing.Copy()
	total = source.total_volume
	maximum = source.maximum_volume
	var/sum = 0
	for (var/datum/reagent/R in order)
		if (!R || R.gcDestroyed || R.gc_destroyed || R.holder != source || !tablet_press_finite(R.volume) || R.volume <= 0)
			ok = FALSE
			return
		volumes[R] = R.volume
		data_refs[R] = R.data
		types[R] = R.type
		ids[R] = R.id
		phases[R] = R.reagent_state
		sum += R.volume
	if (!tablet_press_finite(maximum) || maximum < 0 || !tablet_press_finite(total) || total != sum || total > maximum || total < 0)
		ok = FALSE

/datum/tablet_buffer_state/proc/valid()
	if (!ok || !buffer || buffer.gcDestroyed || buffer.gc_destroyed || buffer.my_atom != owner || buffer.reagent_list != listing || buffer.total_volume != total || buffer.maximum_volume != maximum)
		return FALSE
	if (listing.len != order.len || order.len != volumes.len)
		return FALSE
	for (var/i = 1, i <= order.len, i++)
		if (listing[i] != order[i])
			return FALSE
	for (var/datum/reagent/R in order)
		if (!R || R.gcDestroyed || R.gc_destroyed || R.holder != buffer || R.type != types[R] || R.id != ids[R] || R.volume != volumes[R] || R.data != data_refs[R] || R.reagent_state != phases[R])
			return FALSE
	return TRUE

/datum/tablet_buffer_state/proc/find_exact(id)
	var/datum/reagent/found
	for (var/datum/reagent/R in order)
		if (!R)
			return null
		if (R.id == id)
			if (found)
				return null
			found = R
	return found

/datum/tablet_buffer_state/proc/restore()
	buffer.reagent_list = listing
	buffer.total_volume = total
	for (var/datum/reagent/R in order)
		R.volume = volumes[R]
		R.holder = buffer

// Only these exact two types enter new transfers. No ethanol-family ID removal.
/proc/tablet_reagent_type(id)
	if (id == "calcium_carbonate")
		return /datum/reagent/calcium_carbonate
	if (id == "aspirin")
		return /datum/reagent/aspirin
	return null

/obj/structure/chem_master/tablet_press
	name = "tablet press"
	desc = "Presses one unit of calcium carbonate and four units of aspirin from its internal buffer into a tablet."
	flags = OPENCONTAINER | NOREACT
	var/tmp/datum/tablet_transfer/tablet_action

/obj/structure/chem_master/tablet_press/constructed
	not_disassemblable = TRUE

/obj/structure/chem_master/tablet_press/persistence_runtime_var(key)
	return key == "tablet_action" || ..()

/obj/structure/chem_master/tablet_press/after_load()
	tablet_action = null
	return ..()

/obj/structure/chem_master/tablet_press/proc/can_operate(mob/living/human/user)
	if (gcDestroyed || gc_destroyed || !anchored || !user || user.stat || user.restrained() || !tablet_press_year_allowed())
		return FALSE
	if (!get_turf(src) || !get_turf(user) || user.z != z || get_dist(src, user) > 1)
		return FALSE
	return map.is_node_done(user.civilization, "pharmacology")

/obj/structure/chem_master/tablet_press/attackby(obj/item/W, mob/living/human/user)
	if (tablet_action)
		return
	if (istype(W, /obj/item/weapon/wrench))
		anchored = !anchored
		return
	if (!can_operate(user) || beaker || !istype(W, /obj/item/weapon/reagent_containers/glass))
		return
	if (!user.item_is_in_hands(W) || !user.drop_from_inventory(W, src) || W.loc != src)
		return
	beaker = W
	updateUsrDialog()

/obj/structure/chem_master/tablet_press/attack_hand(mob/living/human/user)
	if (!can_operate(user))
		to_chat(user, SPAN_WARNING("Anchor the press and meet its historical and Pharmacology admission first."))
		return
	user.set_using_object(src)
	var/dat = "Internal buffer: [reagents.total_volume]/120 units.<br>"
	dat += "<a href='?src=\ref[src];tablet=1'>Press one aspirin tablet (1 carbonate + 4 aspirin)</a><br>"
	if (beaker)
		dat += "<a href='?src=\ref[src];load_carbonate=1'>Load 1 carbonate</a> | <a href='?src=\ref[src];load_aspirin=1'>Load 4 aspirin</a><br>"
		dat += "<a href='?src=\ref[src];return_carbonate=1'>Return 1 carbonate</a> | <a href='?src=\ref[src];return_aspirin=1'>Return 4 aspirin</a><br>"
		dat += "<a href='?src=\ref[src];eject=1'>Eject beaker (retains buffer)</a>"
	else
		dat += "Insert a glass beaker for loading or recovery."
	user << browse(dat, "window=tablet_press;size=500x240")

// Never dispatch a crafted href to chem_master/Topic's free pill/bottle paths.
/obj/structure/chem_master/tablet_press/Topic(href, href_list)
	var/mob/living/human/user = usr
	if (tablet_action || !can_operate(user))
		return TRUE
	if (href_list["tablet"])
		press_tablet(user)
	else if (href_list["eject"])
		if (beaker && beaker.loc == src)
			beaker.loc = get_turf(src)
			beaker = null
	else if (beaker && beaker.loc == src && beaker.reagents)
		if (href_list["load_carbonate"])
			move_stock(user, beaker.reagents, reagents, list("calcium_carbonate" = 1))
		else if (href_list["load_aspirin"])
			move_stock(user, beaker.reagents, reagents, list("aspirin" = 4))
		else if (href_list["return_carbonate"])
			move_stock(user, reagents, beaker.reagents, list("calcium_carbonate" = 1))
		else if (href_list["return_aspirin"])
			move_stock(user, reagents, beaker.reagents, list("aspirin" = 4))
	updateUsrDialog()
	return TRUE

/obj/structure/chem_master/tablet_press/proc/move_stock(mob/living/human/user, datum/reagents/source, datum/reagents/target, list/cost)
	if (tablet_action || !can_operate(user))
		return FALSE
	var/datum/tablet_transfer/action = new(src, user, source, target, cost)
	tablet_action = action
	var/success = action.commit()
	if (tablet_action == action)
		tablet_action = null
	qdel(action)
	return success

/obj/structure/chem_master/tablet_press/proc/press_tablet(mob/living/human/user)
	if (tablet_action || !can_operate(user))
		return FALSE
	// The empty base constructor adds no reagent. Never use /pill/aspirin.
	var/obj/item/weapon/reagent_containers/pill/product = new(null)
	product.flags |= NOREACT
	product.reagents.my_atom = null
	var/datum/tablet_transfer/action = new(src, user, reagents, product.reagents, list("calcium_carbonate" = 1, "aspirin" = 4), product)
	tablet_action = action
	var/success = action.commit()
	if (!success)
		qdel(product)
	if (tablet_action == action)
		tablet_action = null
	qdel(action)
	return success

/obj/structure/chem_master/tablet_press/Destroy()
	tablet_action = null
	if (beaker && beaker.loc == src && get_turf(src))
		beaker.loc = get_turf(src)
	beaker = null
	return ..()

// A local two-reagent transaction, not a generic change to chemistry holders.
/datum/tablet_transfer
	should_save = FALSE
	var/obj/structure/chem_master/tablet_press/machine
	var/mob/living/human/actor
	var/turf/site
	var/obj/item/weapon/reagent_containers/vessel
	var/obj/item/weapon/reagent_containers/pill/product
	var/datum/tablet_buffer_state/source
	var/datum/tablet_buffer_state/target
	var/list/cost
	var/list/source_items = list()
	var/list/target_items = list()
	var/list/metadata = list()
	var/list/source_after
	var/list/target_after
	var/list/after_volumes = list()
	var/list/created = list()
	var/list/retired = list()
	var/datum/reagents/staging
	var/save_epoch
	var/committed = FALSE
	var/prepared = FALSE

/datum/tablet_transfer/New(obj/structure/chem_master/tablet_press/owner, mob/living/human/user, datum/reagents/from, datum/reagents/to, list/amounts, obj/item/weapon/reagent_containers/pill/output)
	machine = owner
	actor = user
	site = get_turf(owner)
	vessel = owner.beaker
	product = output
	source = new(from)
	target = new(to)
	cost = amounts.Copy()
	save_epoch = persistence_admission_identity

/datum/tablet_transfer/proc/valid()
	if (committed || !machine || machine.tablet_action != src || !machine.can_operate(actor) || get_turf(machine) != site || !isturf(machine.loc))
		return FALSE
	if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required || save_epoch != persistence_admission_identity)
		return FALSE
	if (!source.valid() || !target.valid() || source.buffer == target.buffer || machine.beaker != vessel)
		return FALSE
	if (product)
		return source.buffer == machine.reagents && product.type == /obj/item/weapon/reagent_containers/pill && !product.loc && product.reagents == target.buffer && !target.owner && target.total == 0
	return vessel && vessel.loc == machine && ((source.buffer == machine.reagents && target.buffer == vessel.reagents) || (source.buffer == vessel.reagents && target.buffer == machine.reagents))

/datum/tablet_transfer/proc/prepare()
	if (!valid() || !cost.len || cost.len > 2)
		return FALSE
	staging = new(5)
	source_after = source.order.Copy()
	target_after = target.order.Copy()
	for (var/datum/reagent/R in source.order)
		after_volumes[R] = R.volume
	for (var/datum/reagent/R in target.order)
		after_volumes[R] = R.volume
	var/credit = 0
	for (var/id in cost)
		var/path = tablet_reagent_type(id)
		var/amount = cost[id]
		var/datum/reagent/R = source.find_exact(id)
		var/datum/reagent/T = target.find_exact(id)
		var/datum/reagent/registered = chemical_reagents_list[id]
		if (!path || !R || R.type != path || !registered || registered.type != path || !tablet_press_finite(amount) || amount <= 0 || amount != round(amount) || R.volume != round(R.volume) || R.volume < amount)
			return FALSE
		var/datum/tablet_metadata/data = new(R.data)
		if (!data.ok)
			return FALSE
		metadata[id] = data
		if (T && (T.type != path || T.volume != round(T.volume) || T.reagent_state != R.reagent_state || !tablet_metadata_equal(T.data, R.data)))
			return FALSE
		// Duplicate IDs or a mismatched selected phase are not silently normalized.
		if (R.reagent_state != registered.reagent_state)
			return FALSE
		for (var/datum/reagent/existing in target.order)
			if (existing.id == id && existing != T)
				return FALSE
		var/list/accepted = list()
		if (!staging.add_reagent(id, amount, data.value, TRUE, accepted) || accepted["amount"] != amount)
			return FALSE
		var/datum/reagent/incoming
		for (var/datum/reagent/candidate in staging.reagent_list)
			if (candidate.id == id)
				incoming = candidate
		if (!incoming || incoming.type != path || incoming.volume != amount || !tablet_metadata_equal(incoming.data, R.data))
			return FALSE
		source_items[id] = R
		target_items[id] = T
		after_volumes[R] = R.volume - amount
		if (after_volumes[R] == 0)
			source_after -= R
			retired += R
		if (T)
			after_volumes[T] = T.volume + amount
		else
			created += incoming
			target_after += incoming
			after_volumes[incoming] = amount
		credit += amount
	if (target.total + credit > target.maximum || staging.total_volume != credit)
		return FALSE
	prepared = TRUE
	return TRUE

/datum/tablet_transfer/proc/ready()
	if (!prepared || !valid())
		return FALSE
	for (var/id in cost)
		var/datum/reagent/R = source_items[id]
		var/datum/tablet_metadata/data = metadata[id]
		if (!R || !tablet_metadata_equal(R.data, data.value))
			return FALSE
	return TRUE

// No notifications, touch, reactions, ID-family removal or cleanup in this phase.
/datum/tablet_transfer/proc/apply()
	for (var/datum/reagent/R in source_after)
		R.volume = after_volumes[R]
	for (var/datum/reagent/R in retired)
		R.volume = 0
		R.holder = null
	for (var/datum/reagent/R in target_after)
		R.volume = after_volumes[R]
		R.holder = target.buffer
	source.buffer.reagent_list = source_after
	target.buffer.reagent_list = target_after
	source.buffer.total_volume = sum_volume(source_after)
	target.buffer.total_volume = sum_volume(target_after)

/datum/tablet_transfer/proc/sum_volume(list/order)
	var/total = 0
	for (var/datum/reagent/R in order)
		total += R.volume
	return total

/datum/tablet_transfer/proc/balanced()
	if (source.buffer.reagent_list != source_after || target.buffer.reagent_list != target_after)
		return FALSE
	for (var/datum/reagent/R in source_after)
		if (R.holder != source.buffer || R.volume != after_volumes[R] || R.data != source.data_refs[R] || R.type != source.types[R] || R.id != source.ids[R] || R.reagent_state != source.phases[R])
			return FALSE
	for (var/datum/reagent/R in target.order)
		if (R.holder != target.buffer || R.volume != after_volumes[R] || R.data != target.data_refs[R] || R.type != target.types[R] || R.id != target.ids[R] || R.reagent_state != target.phases[R])
			return FALSE
	for (var/datum/reagent/R in created)
		var/datum/reagent/paid_input = source_items[R.id]
		if (!paid_input || R.type != paid_input.type || R.reagent_state != paid_input.reagent_state || !tablet_metadata_equal(R.data, paid_input.data))
			return FALSE
	for (var/id in cost)
		var/datum/reagent/R = source_items[id]
		var/datum/reagent/T = target_items[id]
		var/credited = T ? T.volume - target.volumes[T] : 0
		if (!T)
			for (var/datum/reagent/incoming in created)
				if (incoming.id == id)
					credited += incoming.volume
		if (source.volumes[R] - R.volume != cost[id] || credited != cost[id])
			return FALSE
	return source.buffer.total_volume == sum_volume(source_after) && target.buffer.total_volume == sum_volume(target_after)

/datum/tablet_transfer/proc/rollback()
	source.restore()
	target.restore()
	for (var/datum/reagent/R in created)
		R.holder = staging

/datum/tablet_transfer/proc/finish()
	// Created datums now belong to the target. Never destroy them with staging.
	for (var/datum/reagent/R in created)
		staging.reagent_list -= R
	for (var/datum/reagent/R in retired)
		qdel(R)
	if (source.owner)
		source.owner.on_reagent_change()
	if (target.owner)
		target.owner.on_reagent_change()
	source.buffer.handle_reactions()
	target.buffer.handle_reactions()

/datum/tablet_transfer/proc/commit_staged()
	if (!prepare() || !ready())
		return FALSE
	apply()
	if (!balanced())
		rollback()
		return FALSE
	committed = TRUE
	return TRUE

/datum/tablet_transfer/proc/commit()
	try
		if (!commit_staged())
			return FALSE
	catch (var/exception/error)
		if (!committed && prepared)
			rollback()
		world.log << "Tablet transaction failed before publication: [error]"
		return FALSE
	// Publication precedes external notifications. Callbacks see a paid tablet.
	if (product)
		product.name = "aspirin tablet"
		product.reagents.my_atom = product
		product.flags = initial(product.flags)
		product.loc = site
	try
		finish()
	catch (var/exception/notification_error)
		world.log << "Tablet transaction notification failed after balanced commit: [notification_error]"
	return TRUE

/datum/tablet_transfer/Destroy()
	if (staging)
		qdel(staging)
	staging = null
	return ..()

// Retained admission across the existing construction wait, before the builder's debit.
/datum/tablet_press_construction
	should_save = FALSE
	var/obj/item/stack/material/stock
	var/mob/living/human/actor
	var/datum/stack_recipe/recipe
	var/atom/source_loc
	var/turf/site
	var/material/stock_material
	var/amount
	var/quantity
	var/save_epoch

/datum/tablet_press_construction/New(obj/item/stack/material/input_stock, mob/living/human/user, datum/stack_recipe/selected_recipe, count)
	stock = input_stock
	actor = user
	recipe = selected_recipe
	quantity = count
	if (!stock || !actor)
		return
	source_loc = stock.loc
	site = get_turf(user)
	stock_material = stock.material
	amount = stock.amount
	save_epoch = persistence_admission_identity

/datum/tablet_press_construction/proc/valid()
	if (!stock || stock.gcDestroyed || stock.gc_destroyed || !actor || actor.stat || actor.restrained() || quantity != 1)
		return FALSE
	if (!recipe || recipe.result_type != /obj/structure/chem_master/tablet_press/constructed || recipe.req_amount != 20 || !tablet_press_build_allowed(actor, recipe.result_type))
		return FALSE
	if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required || save_epoch != persistence_admission_identity)
		return FALSE
	if (!site || get_turf(actor) != site || stock.loc != source_loc || !stock.crafting_stack_accessible(actor) || stock.material != stock_material || !istype(stock_material, /material/electronics))
		return FALSE
	if (!tablet_press_finite(amount) || amount != round(amount) || stock.amount != amount || amount < 20 || amount > stock.max_amount)
		return FALSE
	return !(locate(/obj/structure/chem_master/tablet_press/constructed) in site)
