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

var/added_plants_to_rations = FALSE

/proc/new_ration(faction, sort)

	if (!added_plants_to_rations)
		german_rations_solids += (typesof(/obj/item/weapon/reagent_containers/food/snacks/grown) - /obj/item/weapon/reagent_containers/food/snacks/grown)
		pirates_rations_solids += (typesof(/obj/item/weapon/reagent_containers/food/snacks/grown) - /obj/item/weapon/reagent_containers/food/snacks/grown)
		added_plants_to_rations = TRUE

	switch (faction)
		if (BRITISH)
			switch (sort)
				if ("solid")
					var/solid = pick(german_rations_solids)
					if (prob(50))
						while (istype(solid, /obj/item/weapon/reagent_containers/food/snacks/grown))
							solid = pick(german_rations_solids)
					var/obj/food = new solid
					food.pixel_x = FALSE
					food.pixel_y = FALSE
					return food
				if ("liquid")
					var/liquid = pick(german_rations_liquids)
					var/obj/food = new liquid
					food.pixel_x = FALSE
					food.pixel_y = FALSE
					return food
				if ("dessert")
					var/dessert = pick(german_rations_desserts)
					var/obj/food = new dessert
					food.pixel_x = FALSE
					food.pixel_y = FALSE
					return food
				if ("meat")
					var/meat = pick(german_rations_meat)
					var/obj/food = new meat
					food.pixel_x = FALSE
					food.pixel_y = FALSE
					return food
		if (PIRATES)
			switch (sort)
				if ("solid")
					var/solid = pick(pirates_rations_solids)
					if (prob(50))
						while (istype(solid, /obj/item/weapon/reagent_containers/food/snacks/grown))
							solid = pick(pirates_rations_solids)
					var/obj/food = new solid
					food.pixel_x = FALSE
					food.pixel_y = FALSE
					return food
				if ("liquid")
					var/liquid = pick(pirates_rations_liquids)
					var/obj/food = new liquid
					food.pixel_x = FALSE
					food.pixel_y = FALSE
					return food
				if ("dessert")
					var/dessert = pick(pirates_rations_desserts)
					var/obj/food = new dessert
					food.pixel_x = FALSE
					food.pixel_y = FALSE
					return food
				if ("meat")
					var/meat = pick(pirates_rations_meat)
					var/obj/food = new meat
					food.pixel_x = FALSE
					food.pixel_y = FALSE
					return food

