/obj/item/stack/farming/seeds
	name = "seeds"
	desc = "Some seeds."
	icon = 'icons/farming/seeds.dmi'
	icon_state = "seeds"
	w_class = ITEM_SIZE_TINY
	value = 0.1
	amount = 1
	max_amount = 100
	singular_name = "seed"
	var/plant = "plant_name" //plant that appears after sowing /obj/structure/farming/plant/plant_name
	var/list/biomes = list("tundra", "temperate", "sea", "desert", "jungle", "savanna", "taiga", "semiarid")
	var/list/seasons = list("WINTER", "SUMMER", "SPRING", "FALL", "Wet Season", "Dry Season")

//////////////////////////////////////////////////////////
/* Cash crop & plant seeds *//////////////////////////////
//////////////////////////////////////////////////////////
/obj/item/stack/farming/seeds/mushroom
	name = "mushroom spores"
	plant = "mushroom"
	icon_state = "mushroomseeds"
	seasons = list("WINTER", "SUMMER", "SPRING", "FALL", "Wet Season")
	biomes = list("temperate", "sea", "tundra", "taiga", "jungle", "savanna")

/obj/item/stack/farming/seeds/mushroompsy
	name = "strange mushroom spores"
	plant = "mushroompsy"
	icon_state = "mushroomseeds"
	seasons = list("WINTER", "SUMMER", "SPRING", "FALL", "Wet Season")
	biomes = list("temperate", "sea", "tundra", "taiga", "jungle", "savanna")

/obj/item/stack/farming/seeds/tobacco
	name = "tobacco seeds"
	plant = "tobacco"
	color = "#d88046" //orange brown
	biomes = list("desert", "jungle", "savanna", "semiarid")

/obj/item/stack/farming/seeds/juniper
	name = "juniper seeds"
	plant = "juniper"
	color = "#5F9EA0"
	biomes = list("taiga", "tundra", "temperate")

/obj/item/stack/farming/seeds/liquorice
	name = "liquorice seeds"
	plant = "liquorice"
	icon_state = "seeds_dark"
	biomes = list("desert", "semiarid", "temperate")

/obj/item/stack/farming/seeds/celery
	name = "celery seeds"
	plant = "celery"
	color = "#c38452"
	biomes = list("semiarid", "temperate")

/obj/item/stack/farming/seeds/redpepper
	name = "red pepper seeds"
	plant = "redpepper"
	icon_state = "seeds_dark"
	color = "#ff5959" //redish black
	biomes = list("desert", "temperate", "semiarid", "sea")

/obj/item/stack/farming/seeds/parsnip
	name = "parsnip seeds"
	plant = "parsnip"
	color = "#f3bc5f" //paletan
	biomes = list("temperate", "semiarid")

/obj/item/stack/farming/seeds/parsley
	name = "parsley seeds"
	plant = "parsley"
	icon_state = "seeds_dark"
	color = "#d3cdb4" //dark shaded yellow
	biomes = list("temperate", "semiarid", "sea")

/obj/item/stack/farming/seeds/sugarcane
	name = "sugarcane seeds"
	plant = "sugarcane"
	color = "#f8ed8b" //sugary yellow? pale.
	biomes = list("jungle", "savanna", "sea")

/obj/item/stack/farming/seeds/hemp
	name = "hemp seeds"
	plant = "hemp"
	color = "#7cfc00"  //lawn green, just like the t-shirts.
	biomes = list("jungle", "savanna", "sea", "semiarid", "desert")
	seasons = list("SUMMER", "SPRING", "FALL", "Wet Season", "Dry Season")

/obj/item/stack/farming/seeds/flax
	name = "flax seeds"
	plant = "flax"
	color = "#5f9ea0"  //cadet navy blue like its flowers.
	biomes = list("temperate", "taiga", "tundra")

/obj/item/stack/farming/seeds/tea
	name = "tea seeds"
	plant = "tea"
	color = "#008080" //tea(l)
	seasons = list("SUMMER", "SPRING", "FALL", "Wet Season", "Dry Season")
	biomes = list("jungle", "savanna", "sea", "semiarid")

/obj/item/stack/farming/seeds/peyote
	name = "peyote seeds"
	plant = "peyote"
	icon_state = "seeds_dark"
	color = "#8475d8" //black-blue
	biomes = list("desert")

/obj/item/stack/farming/seeds/poppy
	name = "poppy seeds"
	desc = "Seeds of the opium poppy."
	plant = "poppy"
	color = "#5f5c54" //grey
	biomes = list("jungle", "savanna", "desert")

/obj/item/stack/farming/seeds/coffee
	name = "coffee seeds"
	plant = "coffee"
	icon_state = "seeds_dark"
	color = "#e68c38" //coffee-brown
	biomes = list("jungle", "savanna", "desert", "semiarid")

/obj/item/stack/farming/seeds/tree
	name = "tree seeds"
	plant = "tree"
	icon_state = "seeds_dark"
	color = "#eeaf78" //orange-brown
	seasons = list("SUMMER", "SPRING", "FALL", "Wet Season", "Dry Season")

/obj/item/stack/farming/seeds/bamboo
	name = "bamboo seeds"
	plant = "bamboo"
	icon_state = "bambooseeds"
	biomes = list("jungle", "sea")
	seasons = list("WINTER", "SUMMER", "SPRING", "FALL", "Wet Season")

/obj/item/stack/farming/seeds/cotton
	name = "cotton seeds"
	plant = "cotton"
	color = "#e4e0dc" //creamy grey
	biomes = list("temperate", "desert", "sea", "semiarid")
	seasons = list("SUMMER", "SPRING", "Wet Season", "Dry Season")

/obj/item/stack/farming/seeds/coca
	name = "coca seeds"
	plant = "coca"
	color = "#90ee90" //light green
	biomes = list("jungle", "savanna")

/obj/item/stack/farming/seeds/herbs
	//Technically it's not a seed
	name = "herbs seeds"
	plant = "herbs"
	color = "#2e8d2e"
	biomes = list()

//////////////////////////////////////////////////////////
/* Vegtable seeds *///////////////////////////////////////
//////////////////////////////////////////////////////////
/obj/item/stack/farming/seeds/tomato
	name = "tomato seeds"
	plant = "tomato"
	color = "#cd5c5c" //indian red
	biomes = list("temperate", "sea", "semiarid", "desert", "jungle", "savanna")
	seasons = list("SUMMER", "SPRING", "Wet Season", "Dry Season")

/obj/item/stack/farming/seeds/cabbage
	name = "cabbage seeds"
	plant = "cabbage"
	color = "#8fbc8f" //dark sea green
	biomes = list("temperate", "tundra", "taiga", "sea", "semiarid")

/obj/item/stack/farming/seeds/potato
	name = "seed potato"
	desc = "a potato selected for breeding because of its characteristics."
	plant = "potato"
	icon_state = "potato"
	biomes = list("temperate", "taiga", "semiarid")

/*
/obj/item/stack/farming/seeds/sweetpotato
	name = "seed sweet potato"
	plant = "sweetpotato"
	icon_state = "potato"
	color = null
	biomes = list("jungle", "savanna", "sea")
	seasons = list("SUMMER", "SPRING", "Wet Season", "Dry Season")
*/

/obj/item/stack/farming/seeds/carrot
	name = "carrot seeds"
	plant = "carrot"
	icon_state = "seeds_dark"
	color = "#f88761"

/obj/item/stack/farming/seeds/corn
	name = "corn seeds"
	plant = "corn"
	color = "#ffff00" //yellow
	biomes = list("temperate", "jungle", "savanna", "desert", "sea", "semiarid", "taiga")
	seasons = list( "SUMMER", "SPRING", "Wet Season", "Dry Season")

/obj/item/stack/farming/seeds/beans
	name = "bean seeds"
	plant = "beans"
	color = "#bc8f8f" //rosy brown
	biomes = list("temperate", "savanna", "desert", "sea", "semiarid") 	//beans are notoriously frost vunerable
	seasons = list( "SUMMER", "SPRING", "Wet Season", "Dry Season")

/obj/item/stack/farming/seeds/zucchini
	name = "zucchini seeds"
	plant = "zucchini"
	icon_state = "seeds_dark"
	color = "#d6d0b5" //dark shaded yellow
	biomes = list("jungle", "sea")

//////////////////////////////////////////////////////////
/* Grains seeds*//////////////////////////////////////////
//////////////////////////////////////////////////////////
/obj/item/stack/farming/seeds/wheat
	name = "wheat seeds"
	plant = "wheat"
	color = "#b87333" //copper
	seasons = list( "SUMMER", "SPRING", "FALL", "Wet Season")
	biomes = list("temperate", "tundra", "taiga", "sea")

/obj/item/stack/farming/seeds/barley
	name = "barley seeds"
	plant = "barley"
	icon_state = "seeds_dark"
	color = "#e0d6af"
	biomes = list("temperate", "semiarid", "taiga", "sea")
	seasons = list( "SUMMER", "SPRING", "FALL", "Wet Season")

/obj/item/stack/farming/seeds/oat
	name = "oat seeds"
	plant = "oat"
	color = "#b1c11b"
	biomes = list("temperate", "tundra", "taiga", "sea")
	seasons = list( "SUMMER", "SPRING", "FALL", "Wet Season")

/obj/item/stack/farming/seeds/rice
	name = "rice seeds"
	desc = "rice seeds selected for their characteristics."
	plant = "rice"
	icon_state = "riceseeds"
	biomes = list("jungle", "savanna", "sea")

//////////////////////////////////////////////////////////
/* Fruit seeds *//////////////////////////////////////////
//////////////////////////////////////////////////////////
/obj/item/stack/farming/seeds/apple
	name = "apple seeds"
	plant = "apple"
	color = "#adff2f" //green yellow
	biomes = list("temperate", "tundra", "taiga", "sea", "semiarid")

/obj/item/stack/farming/seeds/orange
	name = "orange seeds"
	plant = "orange"
	color = "#ff8c00" //dark orange
	biomes = list("temperate", "desert", "sea", "semiarid", "jungle")

/obj/item/stack/farming/seeds/lime
	name = "lime seeds"
	plant = "lime"
	color = "#00ff00" //lime(color)
	biomes = list("temperate", "desert", "sea", "semiarid", "jungle")

/obj/item/stack/farming/seeds/lemon
	name = "lemon seeds"
	plant = "lemon"
	color = "#ffff00" //yellow
	biomes = list("temperate", "desert", "sea", "semiarid", "jungle")

/obj/item/stack/farming/seeds/watermelon
	name = "watermelon seeds"
	plant = "watermelon"
	icon_state = "seeds_dark"
	biomes = list("desert", "semiarid", "jungle")

/obj/item/stack/farming/seeds/pumpkin
	name = "pumpkin seeds"
	plant = "pumpkin"
	color = "#fbe151" //cinnamon
	biomes = list("temperate", "taiga", "tundra")

/obj/item/stack/farming/seeds/agave
	name = "agave seeds"
	plant = "agave"
	icon_state = "seeds_dark"
	color = "#4fda94" //green blue
	biomes = list("desert", "semiarid")

/obj/item/stack/farming/seeds/banana
	name = "banana seeds"
	plant = "banana"
	color = "#ffe135" //banana yellow
	biomes = list("jungle", "savanna")

/obj/item/stack/farming/seeds/cherry
	name = "cherry seeds"
	plant = "cherry"
	icon_state = "seeds_dark"
	color = "#9191b6" //black
	biomes = list("jungle", "temperate", "desert", "savanna")

/obj/item/stack/farming/seeds/apricot
	name = "apricot seeds"
	plant = "apricot"
	color = "#b59a00" //murky yellow
	biomes = list("jungle", "temperate", "desert", "savanna")

/obj/item/stack/farming/seeds/grapes
	name = "grape seeds"
	plant = "grapes"
	color = "#9370db" //medium purple
	biomes = list("temperate", "desert", "sea", "semiarid")
	seasons = list( "SUMMER", "SPRING", "FALL", "Wet Season", "Dry Season")

/obj/item/stack/farming/seeds/olives
	name = "olive seeds"
	plant = "olives"
	color = "#6b8e23" //olive drab
	biomes = list("temperate", "desert", "sea", "semiarid")

/obj/item/stack/farming/seeds/coconut
	name = "coconut seeds"
	plant = "coconut"
	icon_state = "coconut"
	biomes = list("sea", "jungle")

/obj/item/stack/farming/seeds/cocoa
	name = "cocoa seeds"
	plant = "cocoa"
	color = "#4a2601" //chocolate brown
	biomes = list("temperate", "jungle")

/obj/item/stack/farming/seeds/sapodilla
	name = "sapodilla seeds"
	plant = "sapodilla"
	color = "#f3bc5f" //paletan
	biomes = list("jungle", "sea")

/obj/item/stack/farming/seeds/sapote
	name = "sapote seeds"
	plant = "sapote"
	color = "#8f5101" //orange brown
	biomes = list("jungle", "temperate")

//////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////
/* Plants *///////////////////////////////////////////////
//////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////
/obj/structure/farming/plant
	name = "plant"
	desc = "a generic plant."
	icon = 'icons/farming/plants.dmi'
	icon_state = "tomato-grow1"
	anchored = TRUE
	opacity = FALSE
	density = FALSE
	var/stage = 1
	var/counter = 0
	var/harvest_verb = "harvest"
	var/readyStageMin = 7
	var/readyStageMax = 10
	var/plant = "name" // icon and name control, also harvested product type: /obj/item/weapon/reagent_containers/food/snacks/grown/plant
	var/condiment = "product_name" // change it if product is condiment type: /obj/item/weapon/reagent_containers/food/condiment/product_name
	var/stack = "product_name" // change it if product is stack type: /obj/item/stack/product_name
	var/stack_amount = 1 // if product is stack type, then this is amount of harvested material, change it if it not 1
	flammable = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE
	var/list/biomes = list("tundra", "taiga", "temperate", "sea", "semiarid", "desert", "jungle", "savanna")
	var/list/seasons = list("WINTER", "SUMMER", "SPRING", "FALL", "Wet Season", "Dry Season")
	var/vstatic = FALSE // to "freeze" the image, so it can be used as a prop
	var/fertilized = FALSE
	var/water = 60
	var/max_water = 60
	var/plant_nutrition = 100
	var/max_plant_nutrition = 150

/obj/structure/farming/plant/New()
	..()
	water = max_water

//////////////////////////////////////////////////////////
/* Cash crop & misc plants *//////////////////////////////
//////////////////////////////////////////////////////////
/obj/structure/farming/plant/poppy
	name = "poppy plant"
	desc = "A opium poppy plant."
	icon_state = "poppy-grow1"
	plant = "poppy"
	stack = "material/poppy"
	biomes = list("jungle", "savanna", "desert")
	max_water = 75

/obj/structure/farming/plant/tobacco
	name = "tobacco plant"
	desc = "A tobacco plant."
	icon_state = "tobacco-grow1"
	plant = "tobacco"
	stack = "material/tobacco_green"
	biomes = list("desert", "jungle", "savanna", "semiarid")
	max_water = 55

/obj/structure/farming/plant/hemp
	name = "hemp plant"
	desc = "A hemp plant. Good to make ropes and uh, other things."
	icon_state = "hemp-grow1"
	plant = "hemp"
	stack = "material/hemp"
	biomes = list("jungle", "savanna", "sea", "semiarid", "desert")
	seasons = list("SUMMER", "SPRING", "FALL", "Wet Season", "Dry Season")
	max_water = 60

/obj/structure/farming/plant/flax
	name = "flax plant"
	desc = "A flax plant. Closely related to hemp in fiberous rope-making but has none of the uh, other stuff."
	icon_state = "flax-grow1"
	plant = "flax"
	stack ="material/flax"
	biomes = list("temperate", "taiga", "tundra")
	max_water = 60

/obj/structure/farming/plant/sugarcane
	name = "sugarcane"
	desc = "A sugar cane. You can extract sugar from it."
	icon_state = "sugarcane-grow1"
	plant = "sugarcane"
	condiment = "bsugar"
	biomes = list("jungle", "savanna", "sea")
	max_water = 60

/obj/structure/farming/plant/tea
	name = "tea"
	desc = "A tea plant."
	icon_state = "tea-grow1"
	plant = "tea"
	condiment = "tealeaves"
	biomes = list("jungle", "savanna", "sea", "semiarid")
	max_water = 50

/obj/structure/farming/plant/peyote
	name = "peyote"
	desc = "A peyote cactus plant."
	icon_state = "peyote-grow1"
	plant = "peyote"
	biomes = list("desert")
	max_water = 100

/obj/structure/farming/plant/coffee
	name = "coffee"
	desc = "A coffee plant."
	icon_state = "coffee-grow1"
	plant = "coffee"
	biomes = list("jungle", "savanna", "desert", "semiarid")
	max_water = 80

/obj/structure/farming/plant/juniper
	name = "juniper"
	desc = "A juniper bush."
	icon_state = "juniper-grow1"
	plant = "juniper"
	biomes = list("tundra", "taiga", "temperate")
	max_water = 85

/obj/structure/farming/plant/cotton
	name = "cotton"
	desc = "A cotton plant."
	icon_state = "cotton-grow1"
	plant = "cotton"
	stack = "material/cotton"
	harvest_verb = "pick"
	biomes = list("temperate", "desert", "sea", "semiarid")
	seasons = list( "SUMMER", "SPRING", "Wet Season", "Dry Season")
	max_water = 50

/obj/structure/farming/plant/tree
	name = "tree"
	desc = "A tree, grown for wood."
	icon_state = "tree-grow1"
	plant = "tree"
	stack = "material/wood"
	stack_amount = 3
	harvest_verb = "cut some logs from"
	seasons = list( "SUMMER", "SPRING", "FALL", "Wet Season", "Dry Season")
	max_water = 80

/obj/structure/farming/plant/bamboo
	name = "bamboo"
	desc = "A bamboo tree, grown for its shoots."
	icon_state = "bambooo-grow1"
	plant = "bamboo"
	stack = "material/bamboo"
	stack_amount = 3
	harvest_verb = "cut some shoots from"
	biomes = list("jungle", "sea")
	seasons = list("WINTER", "SUMMER", "SPRING", "FALL", "Wet Season")
	max_water = 80

/obj/structure/farming/plant/coca
	name = "coca"
	desc = "A coca plant. Produces coca leaves that can be refined to cocaine."
	icon_state = "coca-grow1"
	plant = "coca"
	stack = "material/coca"
	biomes = list("jungle", "savanna")
	max_water = 75

/obj/structure/farming/plant/mushroom
	name = "mushroom"
	desc = "A bunch of mushrooms. Can be grown inside and underground."
	icon_state = "mushroom-grow1"
	plant = "mushroom"
	harvest_verb = "harvest"
	seasons = list("WINTER", "SUMMER", "SPRING", "FALL", "Wet Season")
	biomes = list("temperate", "sea", "tundra", "taiga", "jungle", "savanna")
	max_water = 0

/obj/structure/farming/plant/mushroompsy
	//yes it have equal icon... for fun and roleplay, enjoy
	name = "Psilocybin mushrooms"
	desc = "A bunch of mushrooms. Can be grown inside and underground."
	icon_state = "mushroompsy-grow1"
	plant = "mushroompsy"
	harvest_verb = "harvest"
	seasons = list("WINTER", "SUMMER", "SPRING", "FALL", "Wet Season")
	biomes = list("temperate", "sea", "tundra", "taiga", "jungle", "savanna")
	max_water = 0

/obj/structure/farming/plant/herbs
	//technically not have a seeds, for planting used /obj/item/stack/medical/advanced/herbs
	name = "herbs"
	desc = "A herb plant."
	icon = 'icons/farming/plants.dmi'
	icon_state = "herbs_grow1"
	plant = "herbs"
	stack = "medical/advanced/herbs"
	stack_amount = 3
	biomes = list("temperate", "semiarid", "sea", "jungle")
	max_water = 38

//////////////////////////////////////////////////////////
/* Grains plants *////////////////////////////////////////
//////////////////////////////////////////////////////////
/obj/structure/farming/plant/wheat
	name = "wheat plant"
	desc = "A wheat plant."
	icon_state = "wheat-grow1"
	plant = "wheat"
	seasons = list( "SUMMER", "SPRING", "FALL", "Wet Season")
	biomes = list("temperate", "tundra", "taiga", "sea", "desert", "semiarid")
	max_water = 50

/obj/structure/farming/plant/oat
	name = "oat plant"
	desc = "a oat plant."
	icon_state = "oat-grow1"
	plant = "oat"
	seasons = list( "SUMMER", "SPRING", "FALL", "Wet Season")
	biomes = list("temperate", "tundra", "taiga", "sea")
	max_water = 50

/obj/structure/farming/plant/barley
	name = "barley plant"
	desc = "a barley plant."
	icon_state = "barley-grow1"
	plant = "barley"
	seasons = list( "SUMMER", "SPRING", "FALL", "Wet Season")
	biomes = list("semiarid", "temperate", "taiga", "sea")
	max_water = 50

/obj/structure/farming/plant/rice
	name = "rice"
	desc = "a rice plant."
	icon_state = "rice-grow1"
	plant = "rice"
	harvest_verb = "harvest"
	biomes = list("jungle", "savanna", "sea")
	max_water = 30

//////////////////////////////////////////////////////////
/* Vegtables plants */////////////////////////////////////
//////////////////////////////////////////////////////////
/obj/structure/farming/plant/potato
	name = "potato plant"
	desc = "a potato plant."
	icon = 'icons/farming/vegetables.dmi'
	icon_state = "potato-grow1"
	plant = "potato"
	biomes = list("temperate", "taiga", "semiarid")
	max_water = 75

/*/obj/structure/farming/plant/sweetpotato
	name = "sweet-potato plant"
	desc = "a sweet-potato plant."
	icon = 'icons/farming/vegetables.dmi'
	icon_state = "sweetpotato-grow1"
	plant = "sweetpotato"
	biomes = list("jungle", "savanna", "sea")
	seasons = list("SUMMER", "SPRING", "Wet Season", "Dry Season")
	max_water = 75*/

/obj/structure/farming/plant/carrot
	name = "carrot plant"
	desc = "a carrot plant."
	icon = 'icons/farming/vegetables.dmi'
	icon_state = "carrot-grow1"
	plant = "carrot"
	max_water = 75

/obj/structure/farming/plant/cabbage
	name = "cabbage plant"
	desc = "a cabbage plant."
	icon = 'icons/farming/vegetables.dmi'
	icon_state = "cabbage-grow1"
	plant = "cabbage"
	biomes = list("temperate", "tundra", "taiga", "sea", "semiarid")
	max_water = 70

/obj/structure/farming/plant/tomato
	name = "tomato plant"
	desc = "a tomato plant."
	icon = 'icons/farming/vegetables.dmi'
	icon_state = "tomato-grow1"
	plant = "tomato"
	biomes = list("temperate", "sea", "semiarid", "desert", "jungle", "savanna")
	seasons = list("SUMMER", "SPRING", "Wet Season", "Dry Season")
	max_water = 55

/obj/structure/farming/plant/corn
	name = "corn plant"
	desc = "a corn plant."
	icon = 'icons/farming/vegetables.dmi'
	icon_state = "corn-grow1"
	plant = "corn"
	biomes = list("temperate", "jungle", "savanna", "desert", "sea", "semiarid", "taiga")
	seasons = list( "SUMMER", "SPRING", "Wet Season", "Dry Season")
	max_water = 70

/obj/structure/farming/plant/beans
	name = "bean plant"
	desc = "a bean plant."
	icon = 'icons/farming/vegetables.dmi'
	icon_state = "beans-grow1"
	plant = "beans"
	biomes = list("temperate", "savanna", "desert", "sea", "semiarid", "taiga")
	max_water = 50

/obj/structure/farming/plant/parsnip
	name = "parsnip plant"
	desc = "a parsnip plant."
	icon = 'icons/farming/vegetables.dmi'
	icon_state = "parsnip-grow1"
	plant = "parsnip"
	biomes = list("temperate", "semiarid")
	max_water = 60

//////////////////////////////////////////////////////////
/* Fruit plants */////////////////////////////////////////
//////////////////////////////////////////////////////////
/obj/structure/farming/plant/apple
	name = "apple tree"
	desc = "An apple tree."
	icon = 'icons/farming/fruits.dmi'
	icon_state = "orange-grow1"
	plant = "apple"
	biomes = list("temperate", "tundra", "taiga", "sea", "semiarid")
	max_water = 75

/obj/structure/farming/plant/orange
	name = "orange tree"
	desc = "An orange tree."
	icon = 'icons/farming/fruits.dmi'
	icon_state = "orange-grow1"
	plant = "orange"
	biomes = list("temperate", "desert", "sea", "semiarid", "jungle")
	max_water = 75

/obj/structure/farming/plant/lime
	name = "lime tree"
	desc = "An lime tree."
	icon = 'icons/farming/fruits.dmi'
	icon_state = "lime-grow1"
	plant = "lime"
	biomes = list("temperate", "desert", "sea", "semiarid", "jungle")
	max_water = 75

/obj/structure/farming/plant/lemon
	name = "lemon tree"
	desc = "An lemon tree."
	icon = 'icons/farming/fruits.dmi'
	icon_state = "lemon-grow1"
	plant = "lemon"
	biomes = list("temperate", "desert", "sea", "semiarid", "jungle")
	max_water = 75

/obj/structure/farming/plant/watermelon
	name = "watermelon vine"
	desc = "A watermelon vine."
	icon = 'icons/farming/fruits.dmi'
	icon_state = "watermelon-grow1"
	plant = "watermelon"
	biomes = list("desert", "semiarid", "jungle")
	seasons = list( "SUMMER", "SPRING", "Wet Season")
	max_water = 90

/obj/structure/farming/plant/pumpkin
	name = "pumpkin vine"
	desc = "A pumpkin vine."
	icon = 'icons/farming/fruits.dmi'
	icon_state = "pumpkin-grow1"
	plant = "pumpkin"
	biomes = list("temperate", "taiga", "tundra")
	max_water = 90

/obj/structure/farming/plant/grapes
	name = "grapes"
	desc = "A grape vine plant."
	icon = 'icons/farming/fruits.dmi'
	icon_state = "grapes-grow1"
	plant = "grapes"
	biomes = list("temperate", "desert", "sea", "semiarid")
	seasons = list("SUMMER", "SPRING", "FALL", "Wet Season", "Dry Season")
	max_water = 65

/obj/structure/farming/plant/banana
	name = "banana"
	desc = "A banana plant."
	icon = 'icons/farming/fruits.dmi'
	icon_state = "banana-grow1"
	plant = "banana"
	biomes = list("jungle", "savanna")
	max_water = 45

/obj/structure/farming/plant/olives
	name = "olive"
	desc = "An olive tree."
	icon = 'icons/farming/fruits.dmi'
	icon_state = "olives-grow1"
	plant = "olives"
	biomes = list("temperate", "desert", "sea", "semiarid")
	max_water = 70

/obj/structure/farming/plant/zucchini
	name = "zucchini"
	desc = "An zucchini vine."
	icon = 'icons/farming/fruits.dmi'
	icon_state = "zucchini-grow1"
	plant = "zucchini"
	biomes = list("temperate", "sea", "jungle")
	max_water = 70

/obj/structure/farming/plant/cherry
	name = "cherry"
	desc = "An cherry tree."
	icon = 'icons/farming/fruits.dmi'
	icon_state = "cherry-grow1"
	plant = "cherry"
	biomes = list("jungle", "temperate", "desert", "savanna")
	max_water = 40

/obj/structure/farming/plant/redpepper
	name = "red pepper"
	desc = "A red pepper bush."
	icon = 'icons/farming/fruits.dmi'
	icon_state = "redpepper-grow1"
	plant = "redpepper"
	biomes = list("desert", "temperate", "semiarid", "sea")
	max_water = 30

/obj/structure/farming/plant/sapodilla
	name = "sapodilla"
	desc = "A sapodilla tree."
	icon = 'icons/farming/fruits.dmi'
	icon_state = "sapodilla-grow1"
	plant = "sapodilla"
	biomes = list("jungle", "sea")
	max_water = 75

/obj/structure/farming/plant/agave
	name = "agave"
	desc = "An agave bush."
	icon = 'icons/farming/plants.dmi'
	icon_state = "agave-grow1"
	plant = "agave"
	biomes = list("desert", "semiarid")
	max_water = 45

/obj/structure/farming/plant/parsley
	name = "parsley"
	desc = "A parsley plant."
	icon = 'icons/farming/plants.dmi'
	icon_state = "parsley-grow1"
	plant = "parsley"
	biomes = list("temperate", "semiarid", "sea")
	max_water = 80

/obj/structure/farming/plant/celery
	name = "celery"
	desc = "A celery plant."
	icon = 'icons/farming/vegetables.dmi'
	icon_state = "celery_grow1"
	plant = "celery"
	biomes = list("temperate", "semiarid", "sea", "jungle")
	max_water = 45

/obj/structure/farming/plant/liquorice
	name = "liquorice"
	desc = "A liquorice plant."
	icon = 'icons/farming/plants.dmi'
	icon_state = "liquorice_grow1"
	plant = "liquorice"
	biomes = list("temperate", "semiarid", "sea", "desert")
	max_water = 38

/obj/structure/farming/plant/apricot
	name = "apricot"
	desc = "An apricot tree."
	icon = 'icons/farming/fruits.dmi'
	icon_state = "apricot-grow1"
	plant = "apricot"
	biomes = list("jungle", "temperate", "desert", "savanna")
	max_water = 40

/obj/structure/farming/plant/coconut
	name = "coconut"
	desc = "An coconut tree."
	icon = 'icons/farming/fruits.dmi'
	icon_state = "coconut-grow1"
	plant = "coconut"
	biomes = list("sea", "jungle")
	max_water = 100

/obj/structure/farming/plant/cocoa
	name = "cocoa"
	desc = "A cocoa tree."
	icon = 'icons/farming/fruits.dmi'
	icon_state = "coco-grow1"
	plant = "cocoa"
	biomes = list("temperate", "jungle")
	max_water = 100

/obj/structure/farming/plant/sapote
	name = "sapote plant"
	desc = "A sapote plant."
	icon = 'icons/farming/fruits.dmi'
	icon_state = "sapote-grow1"
	plant = "sapote"
	biomes = list("jungle", "temperate",)
	max_water = 65

//////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////
/* Plants spawns *////////////////////////////////////////
//////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////
/obj/item/stack/farming/seeds/proc/spawn_plant(turf/loc_to_plant)
	var/plantpath = "/obj/structure/farming/plant/[plant]"
	if (isturf(loc_to_plant))
		new plantpath(loc_to_plant)
	else
		new plantpath(loc)

/obj/structure/farming/plant/proc/spawn_seeds()
	if (istype(src, /obj/structure/farming/plant/herbs))
		return
	var/seedpath = "/obj/item/stack/farming/seeds/[plant]"
	new seedpath(loc, 2)

/obj/structure/farming/plant/proc/spawn_produce()
	var/fruitpath
	var/obj/item/I
	if (stack <> "product_name") // Routine to spawn produces when in stack
		fruitpath = "/obj/item/stack/[stack]"
		I = new fruitpath(loc, stack_amount)
		I.radiation = radiation/2
		if (plant_nutrition >= 80)
			I.amount *= rand(1, 3) // If the soil is fed, randomly increase production from 1 to 3
	else
		if (condiment <> "product_name") // Routine to spawn produces when condiment
			fruitpath = "/obj/item/weapon/reagent_containers/food/condiment/[condiment]"
		else // Routine to spawn produces when fruit itself
			fruitpath = "/obj/item/weapon/reagent_containers/food/snacks/grown/[plant]"
		I = new fruitpath(loc)
		I.radiation = radiation/2
		if (plant_nutrition >= 80) // If the soil is fed, randomly increase production from 1 to 3
			for(var/l = 1, l <= rand(0, 2) && l > 0, l++) // If 0, no extra crops. Up to 2 extras, 3 counting with the main produce
				I = new fruitpath(loc)
				I.radiation = radiation/2

//////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////
/* Plants life *//////////////////////////////////////////
//////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////
//stages: 1-6 growth, 7 harvest, 8 dead
/obj/structure/farming/plant/New()
	..()
	growth()
	var/turf/T = get_turf(src)
	if (T.radiation >= 5)
		radiation = 5

/obj/structure/farming/plant/proc/readyHarvest()
	if (stage >= readyStageMin && stage <= readyStageMax)
		return TRUE

/obj/structure/farming/plant/proc/growth()
	var/turf/floor/dirt/D = get_turf(loc)
	if(!istype(D, /turf/floor/dirt/ploughed))
		water_proc() // Plant will still consume resources and respond to the climate, but will not be able to develop
		return // Stops plant growth if the soil is no longer ploughed
	else if (!vstatic && stage < 12)
		soil_nutrition_proc()
		water_proc()
		if (stage < readyStageMin)
			icon_state = "[plant]-grow[stage]"
			desc = "A young [plant] plant."
			name = "young [plant] plant"
		else if (readyHarvest())
			icon_state = "[plant]-harvest"
			desc = "A ready to harvest [plant] plant."
			name = "ready [plant] plant"
		else
			icon_state = "[plant]-dead"
			desc = "A dead [plant] plant."
			name = "dead [plant] plant"
		spawn(600)
			var/turf/t = null
			var/area/a = null
			if (src)
				t = get_turf(src)
			if (t)
				a = get_area(t)
			
			if (a && a.location == 0 && (istype(src, /obj/structure/farming/plant/mushroom) || istype(src, /obj/structure/farming/plant/mushroompsy)))
				stageGrowth()
			else if (a)
				var/currcl = a.climate
				var/count = 0
				for (var/i in biomes)
					if (i == currcl)
						if (list("jungle", "desert", "savanna").Find(currcl))
							count++
						for (var/k in seasons)
							if (season == k)
								count++
				if (count > 0 || ! list(MAP_NOMADS_CONTINENTAL, MAP_NOMADS_PANGEA, MAP_NOMADS_NEW_WORLD, MAP_NOMADS_MEDITERRANEAN, MAP_NOMADS_EUROPE).Find(map.ID))
					stageGrowth()
			growth()

/obj/structure/farming/plant/proc/stageGrowth()  // Uses plant_nutrition as Use the plant's nutrition as a chance to grow
	if(plant_nutrition > 80) // Good soil, keep growing
		stage += 1
	else if (plant_nutrition >= 40 && prob(plant_nutrition))
		stage += 1
	else if (plant_nutrition > 0 && plant_nutrition < 40 && prob(40))
		stage += 1
	else if(prob(20))
		stage += 1

/obj/structure/farming/plant/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/material/hatchet) || istype(W, /obj/item/weapon/attachment/bayonet) || istype(W, /obj/item/weapon/material/kitchen/utensil/knife) || istype(W, /obj/item/weapon/material/scythe))
		if (stage < readyStageMin) // destroy
			user << "<span class = 'warning'>You uproot the [name].</span>"
			qdel(src)
		else if (readyHarvest()) // harvest
			spawn_seeds()
			spawn_produce()
			user << "<span class = 'notice'>You [harvest_verb] the [name].</span>"
			qdel(src)
		else // destroy
			user << "<span class = 'bad'>You uproot the dead [name].</span>"
			qdel(src)

/obj/structure/farming/plant/proc/soil_nutrition_proc()
	var/turf/floor/dirt/D = get_turf(loc)
	var/nutrition_consumed = 3
	D.soil_nutrition -= nutrition_consumed // Plant eats nutrition from the soil
	if(D.soil_nutrition < D.min_soil_nutrition)
		D.soil_nutrition = D.min_soil_nutrition // Cap soil nutrition at mininum possible
	src.plant_nutrition = D.soil_nutrition

// Helper function to set plant to dead
/obj/structure/farming/plant/proc/set_dead(type = "dead")
    stage = 11
    icon_state = "[plant]-dead"
    desc = "A " + type + " [plant] plant."
    name = type + " [plant] plant"

/obj/structure/farming/plant/proc/water_proc()
	// Exit early if the plant is a mushroom
	if (istype(src, /obj/structure/farming/plant/mushroom) || istype(src, /obj/structure/farming/plant/mushroompsy))
		return

	// Check for rain or monsoon and increase water level
	var/area/A = get_area(loc)
	if (findtext(A.icon_state, "rain") || findtext(A.icon_state, "monsoon"))
		water += 15
		return

	// Check for snow storm or sandstorm and set plant to dead
	if (findtext(A.icon_state, "snow_storm"))
		set_dead("frozen")
		return
	if (findtext(A.icon_state, "sandstorm"))
		set_dead("destroyed")
		return

	// Check for nearby sources of water
	// Water within 2 tiles means no need to manually water the plants.
	for (var/turf/floor/beach/water/WT in range(2, src))
		if (!WT.salty)
			water = max_water
			return
	for (var/turf/floor/trench/flooded/TR in range(2, src))
		if (TR.flooded && !TR.salty)
			water = max_water
			return
	for (var/turf/floor/IR in range(2, src))
		if (IR.irrigation && IR.flooded && !IR.salty)
			water = max_water
			return

	// Decrease water level based on climate and heat wave
	var/climate = get_area(src).climate
	if (!(climate in list("desert", "savanna", "semiarid")))
		water -= 15
	else
		water -= 25
	if (map.heat_wave)
		water -= 10

	// Set plant to dead if water level is too low
	if (water <= 0)
		set_dead("dry")

/obj/structure/farming/plant/examine(mob/user)
	..(user)
	if (ishuman(user))
		var/mob/living/human/H = user
		if (H.getStatCoeff("farming")>= 1.6 && H.getStatCoeff("farming") < 2.2)
			var/water_desc = "healthy"
			if (water/max_water < 0.66 && water/max_water >= 0.33)
				water_desc = "dry"
			if (water/max_water < 0.33)
				water_desc = "wilted"
			user << "\The [src] seems <b>[water_desc]</b>."
		else if (H.getStatCoeff("farming") >= 2.2)
			user << "[src]'s water level is at <b>[water]/[max_water]</b>."
			user << "[src]'s nutrition level is at <b>[plant_nutrition]/[max_plant_nutrition]</b>."
		if (H.getStatCoeff("farming")>= 1.3)
			if (plant_nutrition > 80)
				user << "The plant looks good and healthy, it may give extra crops."