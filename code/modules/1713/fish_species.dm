// More fish for the fishing grounds (docs/fishing-grounds.md, "Catch"):
// trout and catfish in fresh water, herring on the coast, tuna in the open
// sea. They are raw fish like any other: they roast, rot, bait a line and
// stock a fish pen. Sprites: icons/obj/food/fish_species.dmi, drawn by
// tests/sprites/create_fish_species.py.

/obj/item/weapon/reagent_containers/food/snacks/rawfish/trout
	name = "raw trout"
	desc = "A fresh trout, speckled, with a pink stripe down its side. Should probably cook it first."
	icon = 'icons/obj/food/fish_species.dmi'
	icon_state = "trout"
	rotten_icon_state = "rotten_trout"

// A big, slow bottom feeder: more meat on it than a trout.
/obj/item/weapon/reagent_containers/food/snacks/rawfish/catfish
	name = "raw catfish"
	desc = "A fresh catfish, broad-headed and whiskered. Should probably cook it first."
	icon = 'icons/obj/food/fish_species.dmi'
	icon_state = "catfish"
	rotten_icon_state = "rotten_catfish"
	var/fillets = 4

/obj/item/weapon/reagent_containers/food/snacks/rawfish/catfish/New()
	..()
	reagents.add_reagent("protein", 2)

// Small and plentiful.
/obj/item/weapon/reagent_containers/food/snacks/rawfish/herring
	name = "raw herring"
	desc = "A fresh herring, small and silver. Should probably cook it first."
	icon = 'icons/obj/food/fish_species.dmi'
	icon_state = "herring"
	rotten_icon_state = "rotten_herring"
	var/fillets = 2

/obj/item/weapon/reagent_containers/food/snacks/rawfish/herring/New()
	..()
	reagents.remove_reagent("protein", 1)

// The prize of the open sea: it takes a baited or towed line.
/obj/item/weapon/reagent_containers/food/snacks/rawfish/tuna
	name = "raw tuna"
	desc = "A fresh tuna, heavy and dark-backed. Should probably cook it first."
	icon = 'icons/obj/food/fish_species.dmi'
	icon_state = "tuna"
	rotten_icon_state = "rotten_tuna"
	w_class = ITEM_SIZE_NORMAL
	satisfaction = -2
	var/fillets = 6

/obj/item/weapon/reagent_containers/food/snacks/rawfish/tuna/New()
	..()
	reagents.add_reagent("protein", 6)

// Cuts a fish of an unusual size into its own number of fillets. Returns TRUE
// when W cut it.
/obj/item/weapon/reagent_containers/food/snacks/rawfish/proc/cut_fillets(obj/item/W, mob/user, count)
	if (roasted || rotten || !(istype(W, /obj/item/weapon/attachment/bayonet) || is_tool(W, TOOL_KNIFE) || is_tool(W, TOOL_HATCHET)))
		return FALSE
	for (var/i = 1 to count)
		new /obj/item/weapon/reagent_containers/food/snacks/fishfillet(get_turf(src))
	to_chat(user, "You cut \the [src] into [count] fillets.")
	qdel(src)
	return TRUE

/obj/item/weapon/reagent_containers/food/snacks/rawfish/catfish/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (!cut_fillets(W, user, fillets))
		..()

/obj/item/weapon/reagent_containers/food/snacks/rawfish/herring/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (!cut_fillets(W, user, fillets))
		..()

/obj/item/weapon/reagent_containers/food/snacks/rawfish/tuna/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (!cut_fillets(W, user, fillets))
		..()
