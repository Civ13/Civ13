/* the only reason this exists is because apparently 'new pick(listoftypes)'
	is invalid code - Kachnov */

// BRITISH RATIONS

var/list/german_rations_solids = list(/obj/item/weapon/reagent_containers/food/snacks/sliceable/bread,
/obj/item/weapon/reagent_containers/food/snacks/sliceable/cheesewheel,
/obj/item/weapon/reagent_containers/food/snacks/sandwich,
/obj/item/weapon/reagent_containers/food/snacks/mint,
/obj/item/weapon/reagent_containers/food/snacks/sausage,
/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/german
)

var/list/german_rations_liquids = list(
/obj/item/weapon/reagent_containers/food/snacks/mushroomsoup,
/obj/item/weapon/reagent_containers/food/snacks/stew,
)

var/list/german_rations_desserts = list(
/obj/item/weapon/reagent_containers/food/snacks/sliceable/carrotcake,
/obj/item/weapon/reagent_containers/food/snacks/appletart,
)

var/list/german_rations_meat = list(
/obj/item/weapon/reagent_containers/food/snacks/meat
)

// pirates RATIONS

var/list/pirates_rations_solids = list(/obj/item/weapon/reagent_containers/food/snacks/sliceable/bread,
/obj/item/weapon/reagent_containers/food/snacks/sliceable/cheesewheel,
/obj/item/weapon/reagent_containers/food/snacks/sandwich,
/obj/item/weapon/reagent_containers/food/snacks/mint,
/obj/item/weapon/reagent_containers/food/snacks/sausage,
/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/pirates
)

var/list/pirates_rations_liquids = list(
/obj/item/weapon/reagent_containers/food/snacks/mushroomsoup,
/obj/item/weapon/reagent_containers/food/snacks/beetsoup,
)

// blin no dessert in mother russia
var/list/pirates_rations_desserts = list(

)

var/list/pirates_rations_meat = list(
/obj/item/weapon/reagent_containers/food/snacks/bearmeat,
/obj/item/weapon/reagent_containers/food/snacks/meat
)
