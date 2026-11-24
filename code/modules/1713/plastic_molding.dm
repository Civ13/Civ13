// Industrial plastics use game batch units, not real polymer chemistry.
// Pellets are process stock, never a material sheet or printer consumable.
/obj/item/stack/polymer_pellets
	name = "thermoplastic pellets"
	singular_name = "measure of thermoplastic pellets"
	desc = "A measure of solid thermoplastic feedstock. Load it into a plastics molding machine."
	icon = 'icons/obj/chemical.dmi'
	icon_state = "bottle-2"
	w_class = ITEM_SIZE_SMALL
	max_amount = 20
	value = 3

/obj/item/weapon/material/handle/molded
	desc = "A molded plastic tool handle. Fit a compatible tool head as you would a wooden handle."
	default_material = "plastic"

// Distinguish the dedicated catalog by its feedstock, not its player-facing name.
// The existing factory ports, buffering, power, progress and output are reused.
/proc/factory_plastic_molding(datum/factory_recipe/R)
	return R && R.inputs && R.inputs[/obj/item/stack/polymer_pellets]

/obj/structure/factory_fabricator/plastic_molder
	name = "plastics molding machine"
	desc = "A powered workshop machine with built-in injection molds, a blow mold, a film die and a sheet die. Set a product by hand and load thermoplastic pellets. Output goes onto the machine's tile."
	color = "#9ec1aa"
	powerneeded = 8

/obj/structure/factory_fabricator/plastic_molder/recipe_medium_allowed(datum/factory_recipe/R)
	return factory_plastic_molding(R)

/obj/structure/factory_fabricator/plastic_molder/set_recipe(name)
	if (persistence_admission_blocked())
		return FALSE
	return ..()

/obj/structure/factory_fabricator/plastic_molder/fab_step()
	if (persistence_admission_blocked())
		return
	return ..()

/obj/structure/factory_fabricator/plastic_molder/factory_accepts(obj/item/I, from_dir = 0)
	if (persistence_admission_blocked())
		return 0
	return ..()

/obj/structure/factory_fabricator/plastic_molder/proc/load_held_pellets(obj/item/stack/polymer_pellets/S, mob/living/human/H)
	var/datum/factory_recipe/R = current_recipe()
	if (!R || !anchored || !isturf(loc) || QDELETED(S) || !istype(H) || !H.Adjacent(src) || H.incapacitated() || H.restrained() || S.loc != H || !H.item_is_in_hands(S) || S.nodrop || S.nodrop_special_check() || persistence_admission_blocked())
		return 0
	var/cycle_cost = R.inputs[/obj/item/stack/polymer_pellets]
	var/amount = min(S.amount, 2 * cycle_cost - buffered(/obj/item/stack/polymer_pellets))
	if (amount < 1)
		return 0
	if (amount == S.amount)
		if (!H.transfer_held_item_to(S, src))
			return 0
	else
		// A partial transfer never removes or reselects the player's held stack.
		if (!S.use(amount))
			return 0
		new /obj/item/stack/polymer_pellets(src, amount, FALSE)
		S.update_icon()
		S.update_strings()
	fab_wake()
	return amount

/obj/structure/factory_fabricator/plastic_molder/attackby(obj/item/W, mob/user)
	if (!istype(W, /obj/item/stack/polymer_pellets))
		return ..()
	var/amount = load_held_pellets(W, user)
	if (amount)
		to_chat(user, SPAN_NOTICE("You load [amount] [amount == 1 ? "measure" : "measures"] of pellets into \the [src]."))
	else
		to_chat(user, SPAN_WARNING("No pellets loaded. Fix the machine in place, select a product, and check its input space."))
