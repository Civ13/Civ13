/* the only reason this exists is because apparently 'new pick(listoftypes)'
	is invalid code - Kachnov */

// GERMAN RATIONS

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

// soviet RATIONS

var/list/soviet_rations_solids = list(/obj/item/weapon/reagent_containers/food/snacks/sliceable/bread,
/obj/item/weapon/reagent_containers/food/snacks/sliceable/cheesewheel,
/obj/item/weapon/reagent_containers/food/snacks/sandwich,
/obj/item/weapon/reagent_containers/food/snacks/mint,
/obj/item/weapon/reagent_containers/food/snacks/sausage,
/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/soviet
)

var/list/soviet_rations_liquids = list(
/obj/item/weapon/reagent_containers/food/snacks/mushroomsoup,
/obj/item/weapon/reagent_containers/food/snacks/beetsoup,
)

// blin no dessert in mother russia
var/list/soviet_rations_desserts = list(

)

var/list/soviet_rations_meat = list(
/obj/item/weapon/reagent_containers/food/snacks/bearmeat,
/obj/item/weapon/reagent_containers/food/snacks/meat
)

var/added_plants_to_rations = FALSE

/proc/water_ration()
	var/obj/water = new /obj/item/weapon/reagent_containers/food/drinks/bottle/water/filled
	water.pixel_x = FALSE
	water.pixel_y = FALSE
	return water

/proc/vodka_ration()
	var/obj/vodka = new /obj/item/weapon/reagent_containers/food/drinks/bottle/vodka
	vodka.pixel_x = FALSE
	vodka.pixel_y = FALSE
	return vodka

/proc/beer_ration()
	var/obj/beer = new /obj/item/weapon/reagent_containers/food/drinks/bottle/small/beer
	beer.pixel_x = FALSE
	beer.pixel_y = FALSE
	return beer

/proc/new_ration(faction, sort)

	if (!added_plants_to_rations)
		german_rations_solids += (typesof(/obj/item/weapon/reagent_containers/food/snacks/grown) - /obj/item/weapon/reagent_containers/food/snacks/grown)
		soviet_rations_solids += (typesof(/obj/item/weapon/reagent_containers/food/snacks/grown) - /obj/item/weapon/reagent_containers/food/snacks/grown)
		added_plants_to_rations = TRUE

	switch (faction)
		if (GERMAN)
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
		if (SOVIET)
			switch (sort)
				if ("solid")
					var/solid = pick(soviet_rations_solids)
					if (prob(50))
						while (istype(solid, /obj/item/weapon/reagent_containers/food/snacks/grown))
							solid = pick(soviet_rations_solids)
					var/obj/food = new solid
					food.pixel_x = FALSE
					food.pixel_y = FALSE
					return food
				if ("liquid")
					var/liquid = pick(soviet_rations_liquids)
					var/obj/food = new liquid
					food.pixel_x = FALSE
					food.pixel_y = FALSE
					return food
				if ("dessert")
					var/dessert = pick(soviet_rations_desserts)
					var/obj/food = new dessert
					food.pixel_x = FALSE
					food.pixel_y = FALSE
					return food
				if ("meat")
					var/meat = pick(soviet_rations_meat)
					var/obj/food = new meat
					food.pixel_x = FALSE
					food.pixel_y = FALSE
					return food

