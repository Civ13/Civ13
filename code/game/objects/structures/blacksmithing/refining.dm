////Furnaces////
/obj/structure/furnace
	name = "bloomery"
	desc = "An industrial bloomery, used to smelter iron into sponge iron. Can also be used to recycle materials."
	icon = 'icons/obj/metallurgy.dmi'
	icon_state = "bloomery"
	layer = 2.9
	density = TRUE
	anchored = TRUE
	flags = OPENCONTAINER | NOREACT
	var/base_state = "bloomery"
	var/on = FALSE
	var/fuel = 0
	var/iron = 0
	var/smelt_time = 250 // deciseconds per smelt
	var/tmp/blown_firing = FALSE // the firing under way started under a bellows blast
	not_movable = TRUE
	not_disassemblable = FALSE

/obj/structure/furnace/update_icon()
	if (on)
		icon_state = "[base_state]_on"
		set_light(4)
	else
		icon_state = base_state
		set_light(0)

// Manual bloomery and blast-furnace stacks share the same payment and credits.
/obj/structure/furnace/proc/accept_manual_stack(var/obj/item/I, var/mob/living/human/H)
	var/refusal = fuel_refusal(I)
	if (refusal)
		to_chat(H, SPAN_WARNING(refusal))
		return
	var/furnace_fuel = solid_fuel_value(I, fuel_rates())
	if (furnace_fuel)
		record_wood_fuel(I, furnace_fuel)
		fuel += furnace_fuel
		to_chat(H, "You place \the [I] in \the [src], refueling it.")

	else if (istype(I, /obj/item/stack/ore/iron))
		iron += I.amount
		to_chat(H, "You place \the [I] in \the [src].")

	else
		to_chat(H, "<span class = 'warning'>You can't smelt this.</span>")
		return

	H.remove_from_mob(I)
	I.loc = src
	visible_message("<span class = 'notice'>[H] puts [I] in \the [name].</span>")
	qdel(I)
	return

/obj/structure/furnace/proc/handle_structure_tool(var/obj/item/I, var/mob/living/human/H)
	if (istype(I, /obj/item/weapon/wrench) || (istype(I, /obj/item/weapon/hammer)))
		if (istype(I, /obj/item/weapon/wrench))
			if (timed_toggle_anchor(H))
				return TRUE
		else if (istype(I, /obj/item/weapon/hammer))
			if (!can_dismantle_with_hammer(H))
				return TRUE
			visible_message("<span class='warning'>[H] starts to deconstruct \the [src].</span>")
			playsound(src, 'sound/items/Ratchet.ogg', 100, TRUE)
			if (do_after(H,50,src) && !QDELETED(src))
				if (!can_dismantle_with_hammer(H))
					return TRUE
				visible_message("<span class='warning'>[H] deconstructs \the [src].</span>")
				empty()
				qdel(src)
				return TRUE

	return FALSE

/obj/structure/furnace/attackby(var/obj/item/I, var/mob/living/human/H)
	if (!I || !I.loc)
		return
	if (!istype(H))
		return
	if (H.a_intent == I_HELP)
		if (handle_structure_tool(I, H))
			return
		if (istype(I, /obj/item/stack/))
			accept_manual_stack(I, H)
			return
		else if (istype(I, /obj/item/weapon/material))
			var/obj/item/weapon/material/MT = I
			if (MT.get_material_name() == "wood")
				record_wood_fuel(I, 1)
				fuel += 1
				to_chat(H, "You break \the [MT] and put it into the [src], refueling it.")
				qdel(I)
			else if (MT.get_material_name() == "bronze")
				to_chat(H, "You smelt \the [MT] into bronze ingots.")
				new/obj/item/stack/material/bronze(src.loc)
				qdel(I)
			else if (MT.get_material_name() == "copper")
				to_chat(H, "You smelt \the [MT] into copper ingots.")
				new/obj/item/stack/material/copper(src.loc)
				qdel(I)
			else if (MT.get_material_name() == "tin")
				to_chat(H, "You smelt \the [MT] into tin ingots.")
				new/obj/item/stack/material/tin(src.loc)
				qdel(I)
			else if (MT.get_material_name() == "brass")
				to_chat(H, "You smelt \the [MT] into brass ingots.")
				new/obj/item/stack/material/brass(src.loc)
				qdel(I)
			else if (MT.get_material_name() == "zinc")
				to_chat(H, "You smelt \the [MT] into zinc ingots.")
				new/obj/item/stack/material/zinc(src.loc)
				qdel(I)
			else if (MT.get_material_name() == "iron")
				to_chat(H, "You smelt \the [MT] into iron ingots.")
				new/obj/item/stack/material/iron(src.loc)
				qdel(I)
			else if (MT.get_material_name() == "steel")
				to_chat(H, "You smelt \the [MT] into steel sheets.")
				new/obj/item/stack/material/steel(src.loc)
				qdel(I)
		else if (istype(I, /obj/item) && I.basematerials.len)
			to_chat(H, "You put \the [I] into \the [src] to recycle it.")
			if (I.basematerials[1] == "tin")
				new/obj/item/stack/material/tin(src.loc)
			qdel(I)

		else
			..()
	else
		..()

/obj/structure/furnace/attack_hand(var/mob/living/human/H)
	if (!on && has_firing_fuel())
		visible_message("<span class = 'notice'>[H] turns the [name] on.</span>")
		note_smelting(H, src)
		start_smelt()
		accolade_meet_mob(H, "smelter")
	else if (!on && firing_refusal())
		to_chat(H, SPAN_WARNING(firing_refusal()))
	else if (!on)
		to_chat(H, "<span class = 'warning'>The [name] doesn't have enough fuel! This firing needs [firing_fuel_cost()] and it holds [round(fuel, 0.1)]. Fill it with charcoal or wood.</span>")


// One 25 second smelt; factory_machines.dm starts it from automation too.
/obj/structure/furnace/proc/start_smelt()
	on = TRUE
	blown_firing = bellows_blowing()
	burn_structure_fuel(firing_fuel_cost())
	update_icon()
	spawn (smelt_time)
		if (QDELETED(src))
			return
		on = FALSE
		update_icon()
		visible_message("<span class = 'notice'>The [name] finishes smelting.</span>")
		process()

/obj/structure/furnace/process()
	if (iron > 0)
		// A hard blast lets the bloom soak up carbon: some comes out steely.
		var/steely = blown_firing ? steely_bloom_count(iron) : 0
		if (iron - steely > 0)
			spawn_stack(/obj/item/stack/ore/iron_sponge, src.loc, iron - steely)
		if (steely > 0)
			spawn_stack(/obj/item/stack/ore/iron_sponge/steely, src.loc, steely)
		iron = 0
		return
/obj/structure/furnace/verb/empty()
	set category = null
	set name = "Empty"
	set src in range(1)
	if (iron > 0)
		spawn_stack(/obj/item/stack/ore/iron, src.loc, iron)
		iron = 0


////////ADVANCED METALLURGY STUFF/////////
/obj/structure/furnace/blast_furnace
	name = "blast furnace"
	desc = "An industrial blast furnace, used to make advanced alloys."
	icon = 'icons/obj/metallurgy.dmi'
	icon_state = "blast_furnace"
	base_state = "blast_furnace"

/obj/structure/furnace/blast_furnace/attackby(var/obj/item/I, var/mob/living/human/H)
	if (!I || !I.loc)
		return
	if (!istype(H))
		return
	if (H.a_intent == I_HELP)
		if (handle_structure_tool(I, H))
			return
		if (istype(I, /obj/item/stack/))
			accept_manual_stack(I, H)
			return
		else if (istype(I, /obj/item/weapon/material))
			var/obj/item/weapon/material/MT = I
			if (MT.get_material_name() == "wood")
				record_wood_fuel(I, 1)
				fuel += 1
				to_chat(H, "You break \the [MT] and put it into the [src], refueling it.")
				qdel(I)
	else
		..()

/obj/structure/furnace/blast_furnace/process()
	if (iron > 0)
		spawn_stack(/obj/item/stack/ore/iron_pig, src.loc, iron)
		iron = 0
		return

////////ADVANCED METALLURGY STUFF/////////
/obj/structure/furnace/kiln
	name = "clay kiln"
	desc = "A clay brick kiln, used for metallurgy."
	icon = 'icons/obj/metallurgy.dmi'
	icon_state = "clay_kiln"
	base_state = "clay_kiln"

/obj/structure/furnace/kiln/stone
	name = "stone kiln"
	desc = "A stone kiln, used for metallurgy."
	icon_state = "stone_kiln"
	base_state = "stone_kiln"

/obj/structure/furnace/kiln/sandstone
	name = "sandstone kiln"
	desc = "A sandstone kiln, used for metallurgy."
	icon_state = "sandstone_kiln"
	base_state = "sandstone_kiln"

/obj/structure/furnace/kiln/attackby(var/obj/item/I, var/mob/living/human/H)
	if (!I || !I.loc)
		return
	if (!istype(H))
		return
	if (H.a_intent == I_HELP)
		if (handle_structure_tool(I, H))
			return
		if (istype(I, /obj/item/stack/))
			var/kiln_fuel = solid_fuel_value(I, furnace_fuel_rates)
			if (kiln_fuel)
				record_wood_fuel(I, kiln_fuel)
				fuel += kiln_fuel
				to_chat(H, "You place \the [I] in \the [src], refueling it.")
				qdel(I)
				return

			for (var/obj/item/weapon/clay/mold/MCC in contents)
				to_chat(H, "<span class = 'warning'>\The [name] is full.</span>")
				return

		if (accept_crucible(I, H))
			return
		if (accept_aging_steel(I, H)) // alloy_steels.dm
			return
		if (accept_alumina(I, H)) // composite_armour.dm
			return

		else if (istype(I, /obj/item/weapon/material))
			var/obj/item/weapon/material/MT = I
			if (MT.get_material_name() == "wood")
				record_wood_fuel(I, 1)
				fuel += 1
				to_chat(H, "You break \the [MT] and put it into the [src], refueling it.")
				qdel(I)
		if (istype(I, /obj/item/weapon/clay/mold))
			var/obj/item/weapon/clay/mold/MC = I
			if (MC.fired && MC.capacity == 0 && MC.max_capacity > 0 && MC.contents_materials.len)
				H.remove_from_mob(I)
				I.loc = src
				visible_message("<span class = 'notice'>[H] puts [I] in \the [name].</span>")
				return

/obj/structure/furnace/kiln/process()
	fire_crucibles()
	age_steel() // alloy_steels.dm
	fire_alumina() // composite_armour.dm
	for (var/obj/item/weapon/clay/mold/MCC in contents)
		if (MCC.fired && MCC.capacity == 0 && MCC.max_capacity > 0 && MCC.contents_materials.len)
			if (("copper" in MCC.contents_materials) && ("tin" in MCC.contents_materials))
				MCC.capacity = min(MCC.contents_materials["copper"],MCC.contents_materials["tin"])
				MCC.contents_materials["copper"] -= MCC.capacity
				MCC.contents_materials["tin"] -= MCC.capacity
				MCC.current_material = "bronze"
			else if (("copper" in MCC.contents_materials) && ("zinc" in MCC.contents_materials))
				MCC.capacity = min(MCC.contents_materials["copper"],MCC.contents_materials["zinc"])
				MCC.contents_materials["copper"] -= MCC.capacity
				MCC.contents_materials["zinc"] -= MCC.capacity
				MCC.current_material = "brass"
			else
				for(var/i in MCC.contents_materials)
					MCC.capacity = MCC.contents_materials[i]
					MCC.current_material = i
					MCC.contents_materials[i] = 0
			// An alloy takes equal parts. The metal left over stays in the vessel
			// unmelted (it used to vanish) and melts on the next firing, once the
			// alloy has been poured out.
			var/list/left_over = list()
			for (var/i in MCC.contents_materials)
				if (MCC.contents_materials[i] > 0)
					left_over[i] = MCC.contents_materials[i]
			MCC.contents_materials = left_over
			MCC.loc = src.loc
			MCC.update_icon()