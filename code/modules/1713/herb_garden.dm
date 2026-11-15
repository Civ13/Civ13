// Herb garden crops: chamomile, dandelion, mint, sunflower and rose.
//
// Each is an ordinary crop (seeds, ploughed soil, water) that also grows wild.
// - Chamomile and mint: steep fresh (5 tea) or dried on a dehydrator (10 tea).
//   Chamomile tea calms and cheers; mint tea settles an upset stomach.
// - Dandelion: the leaves are edible greens and every harvest also gives a
//   root. Roast the root on a dehydrator and steep it for a coffee substitute.
// - Sunflower: shell the head in hand for edible seeds.
// - Rose: gives rose hips (eaten, or steeped into a tea that helps healing)
//   and petals, which dry into a fragrant tea.

#define HERB_FRESH_STEEP 5
#define HERB_DRIED_STEEP 10

/////////////////////////////// Steeping grown herbs ///////////////////////////////

/obj/item/weapon/reagent_containers/food/snacks/grown
	var/steep_reagent = null
	var/steep_amount = 0
	var/steep_message = ""

// Hold a steepable herb and click an open container with enough water.
/obj/item/weapon/reagent_containers/food/snacks/grown/resolve_attackby(atom/A, mob/user, icon_x, icon_y)
	if (!steep_reagent || !isobj(A) || !A.reagents || istype(A, /obj/item/weapon/reagent_containers/food/snacks))
		return ..()
	var/obj/vessel = A
	if (!vessel.is_open_container() || !vessel.reagents.has_reagent("water"))
		return ..()
	steep_herb(vessel, user)
	return TRUE

/obj/item/weapon/reagent_containers/food/snacks/grown/proc/steep_herb(obj/vessel, mob/user)
	if (!steep_reagent || QDELETED(src))
		return FALSE
	if (!herb_steep_into(name, vessel, user, steep_reagent, steep_amount, steep_message))
		return FALSE
	qdel(src)
	return TRUE

/////////////////////////////// Seeds ///////////////////////////////

/obj/item/stack/farming/seeds/chamomile
	name = "chamomile seeds"
	plant = "chamomile"
	icon_state = "chamomileseeds"
	biomes = list("temperate", "semiarid", "sea", "taiga")

/obj/item/stack/farming/seeds/dandelion
	name = "dandelion seeds"
	plant = "dandelion"
	icon_state = "dandelionseeds"
	biomes = list("temperate", "taiga", "tundra", "sea", "semiarid")

/obj/item/stack/farming/seeds/mint
	name = "mint seeds"
	plant = "mint"
	icon_state = "mintseeds"
	biomes = list("temperate", "sea", "semiarid", "jungle")

/obj/item/stack/farming/seeds/sunflower
	name = "sunflower seeds"
	plant = "sunflower"
	icon_state = "sunflowerseeds"
	biomes = list("temperate", "semiarid", "savanna", "desert")

/obj/item/stack/farming/seeds/rose
	name = "rose seeds"
	plant = "rose"
	icon_state = "roseseeds"
	biomes = list("temperate", "semiarid", "sea")

/////////////////////////////// Plants ///////////////////////////////

/obj/structure/farming/plant/chamomile
	name = "chamomile"
	desc = "A chamomile plant."
	icon = 'icons/farming/plants.dmi'
	icon_state = "chamomile-grow1"
	plant = "chamomile"
	biomes = list("temperate", "semiarid", "sea", "taiga")
	max_water = 50

/obj/structure/farming/plant/dandelion
	name = "dandelion"
	desc = "A dandelion plant."
	icon = 'icons/farming/plants.dmi'
	icon_state = "dandelion-grow1"
	plant = "dandelion"
	biomes = list("temperate", "taiga", "tundra", "sea", "semiarid")
	max_water = 50

// Every harvest also lifts one root.
/obj/structure/farming/plant/dandelion/spawn_produce(bonus = 0)
	..()
	new /obj/item/weapon/reagent_containers/food/snacks/grown/dandelion_root(loc)

/obj/structure/farming/plant/mint
	name = "mint"
	desc = "A mint plant."
	icon = 'icons/farming/plants.dmi'
	icon_state = "mint-grow1"
	plant = "mint"
	biomes = list("temperate", "sea", "semiarid", "jungle")
	max_water = 70

/obj/structure/farming/plant/sunflower
	name = "sunflower"
	desc = "A sunflower plant."
	icon = 'icons/farming/plants.dmi'
	icon_state = "sunflower-grow1"
	plant = "sunflower"
	biomes = list("temperate", "semiarid", "savanna", "desert")
	max_water = 40

/obj/structure/farming/plant/rose
	name = "rose"
	desc = "A rose bush."
	icon = 'icons/farming/plants.dmi'
	icon_state = "rose-grow1"
	plant = "rose"
	biomes = list("temperate", "semiarid", "sea")
	max_water = 50

// A rose gives its hips (the fed-soil bonus applies) and one handful of petals.
/obj/structure/farming/plant/rose/spawn_produce(bonus = 0)
	var/count = 1
	if (plant_nutrition >= 80)
		count += rand(0, 2)
	count = harvest_skill_amount(count, bonus)
	for (var/i = 1, i <= count, i++)
		var/obj/item/I = new /obj/item/weapon/reagent_containers/food/snacks/grown/rosehips(loc)
		I.radiation = radiation/2
	var/obj/item/petals = new /obj/item/weapon/reagent_containers/food/snacks/grown/rose_petals(loc)
	petals.radiation = radiation/2

/////////////////////////////// Produce ///////////////////////////////

/obj/item/weapon/reagent_containers/food/snacks/grown/chamomile
	name = "chamomile flowers"
	icon_state = "chamomile"
	desc = "Small white daisy-like flowers. Steep them in water for a calming tea, or dry them first for a stronger one."
	nutriment_amt = 0
	nutriment_desc = list("bitter flowers" = 1)
	decay = 30*600
	satisfaction = 1
	dry_size = 5
	dried_type = /obj/item/weapon/reagent_containers/food/snacks/grown/dried_chamomile
	steep_reagent = "chamomile_tea"
	steep_amount = HERB_FRESH_STEEP
	steep_message = "The water turns a pale gold and smells of apples."

/obj/item/weapon/reagent_containers/food/snacks/grown/dried_chamomile
	name = "dried chamomile"
	icon = 'icons/obj/food/dryed.dmi'
	icon_state = "dried_chamomile"
	desc = "Dried chamomile flowers. They keep for a long time and steep into a strong calming tea."
	nutriment_amt = 0
	nutriment_desc = list("dry flowers" = 1)
	decay = 0
	dry_size = 5
	steep_reagent = "chamomile_tea"
	steep_amount = HERB_DRIED_STEEP
	steep_message = "The water turns a deep gold and smells of apples."

/obj/item/weapon/reagent_containers/food/snacks/grown/dandelion
	name = "dandelion greens"
	icon_state = "dandelion"
	desc = "Young dandelion leaves and a yellow flower head. Bitter, but good to eat."
	nutriment_amt = 2
	nutriment_desc = list("bitter greens" = 1)
	decay = 30*600
	satisfaction = 1

/obj/item/weapon/reagent_containers/food/snacks/grown/dandelion_root
	name = "dandelion root"
	icon_state = "dandelion_root"
	desc = "A long brown taproot. Roast it on a dehydrator, then steep it for a coffee substitute."
	nutriment_amt = 1
	nutriment_desc = list("earthy root" = 1)
	decay = 60*600
	dry_size = 5
	dried_type = /obj/item/weapon/reagent_containers/food/snacks/grown/roasted_dandelion_root

/obj/item/weapon/reagent_containers/food/snacks/grown/roasted_dandelion_root
	name = "roasted dandelion root"
	icon = 'icons/obj/food/dryed.dmi'
	icon_state = "roasted_dandelion_root"
	desc = "A dark, dried dandelion root. Steep it in water for a warming coffee-like drink."
	nutriment_amt = 1
	nutriment_desc = list("roasted root" = 1)
	decay = 0
	dry_size = 5
	steep_reagent = "dandelion_coffee"
	steep_amount = HERB_DRIED_STEEP
	steep_message = "The water turns a dark, roasty brown."

/obj/item/weapon/reagent_containers/food/snacks/grown/mint
	name = "mint"
	icon_state = "mint_sprig"
	desc = "A fragrant sprig of mint. Steep it in water for a tea that settles the stomach, or dry it first for a stronger one."
	nutriment_amt = 0
	nutriment_desc = list("mint" = 1)
	decay = 30*600
	satisfaction = 1
	dry_size = 5
	dried_type = /obj/item/weapon/reagent_containers/food/snacks/grown/dried_mint
	steep_reagent = "mint_tea"
	steep_amount = HERB_FRESH_STEEP
	steep_message = "The water turns pale green and smells fresh."

/obj/item/weapon/reagent_containers/food/snacks/grown/dried_mint
	name = "dried mint"
	icon = 'icons/obj/food/dryed.dmi'
	icon_state = "dried_mint"
	desc = "Dried mint leaves. They keep for a long time and steep into a strong stomach-settling tea."
	nutriment_amt = 0
	nutriment_desc = list("dry mint" = 1)
	decay = 0
	dry_size = 5
	steep_reagent = "mint_tea"
	steep_amount = HERB_DRIED_STEEP
	steep_message = "The water turns green and smells strongly of mint."

/obj/item/weapon/reagent_containers/food/snacks/grown/sunflower
	name = "sunflower head"
	icon_state = "sunflower"
	desc = "A big sunflower head packed with seeds. Use it in hand to shell the seeds."
	nutriment_amt = 1
	nutriment_desc = list("raw seeds" = 1)
	decay = 90*600

/obj/item/weapon/reagent_containers/food/snacks/grown/sunflower/attack_self(mob/user)
	if (!user || QDELETED(src))
		return
	var/turf/T = get_turf(user)
	if (!T)
		return
	for (var/i = 1, i <= 3, i++)
		new /obj/item/weapon/reagent_containers/food/snacks/grown/sunflower_seeds(T)
	to_chat(user, SPAN_NOTICE("You shell \the [src] into three handfuls of sunflower seeds."))
	qdel(src)

/obj/item/weapon/reagent_containers/food/snacks/grown/sunflower_seeds
	name = "shelled sunflower seeds"
	icon_state = "sunflower_seeds"
	desc = "A handful of shelled sunflower seeds. A filling snack that keeps well."
	nutriment_amt = 3
	nutriment_desc = list("nutty seeds" = 1)
	decay = 240*600
	satisfaction = 3

/obj/item/weapon/reagent_containers/food/snacks/grown/rosehips
	name = "rose hips"
	icon_state = "rosehips"
	desc = "Bright red rose hips. Tart to eat, or steep them in water for a tea that helps wounds heal."
	nutriment_amt = 1
	nutriment_desc = list("tart fruit" = 1)
	decay = 60*600
	satisfaction = 2
	steep_reagent = "rosehip_tea"
	steep_amount = HERB_DRIED_STEEP
	steep_message = "The water turns a deep rosy red."

/obj/item/weapon/reagent_containers/food/snacks/grown/rose_petals
	name = "rose petals"
	icon_state = "rose_petals"
	desc = "A handful of soft rose petals. Dry them on a dehydrator for a fragrant tea."
	nutriment_amt = 0
	nutriment_desc = list("petals" = 1)
	decay = 20*600
	dry_size = 2
	dried_type = /obj/item/weapon/reagent_containers/food/snacks/grown/dried_rose_petals

/obj/item/weapon/reagent_containers/food/snacks/grown/dried_rose_petals
	name = "dried rose petals"
	icon = 'icons/obj/food/dryed.dmi'
	icon_state = "dried_rose_petals"
	desc = "Dried rose petals. They steep into a fragrant, cheering tea."
	nutriment_amt = 0
	nutriment_desc = list("dry petals" = 1)
	decay = 0
	dry_size = 2
	steep_reagent = "rose_tea"
	steep_amount = HERB_DRIED_STEEP
	steep_message = "The water turns pink and smells of roses."

/////////////////////////////// Teas ///////////////////////////////

/datum/reagent/drink/chamomile_tea
	name = "Chamomile Tea"
	id = "chamomile_tea"
	description = "A gentle tea of chamomile flowers. It calms the nerves and lifts the mood."
	taste_description = "honeyed apples"
	color = "#E3C25A"
	adj_dizzy = -3
	adj_temp = 15

/datum/reagent/drink/chamomile_tea/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
	..()
	M.jitteriness = max(0, M.jitteriness - 5 * removed)
	if (istype(M))
		M.adjust_mood(removed * 4, "chamomile tea")

/datum/reagent/drink/mint_tea
	name = "Mint Tea"
	id = "mint_tea"
	description = "A fresh mint tea. It settles an upset stomach."
	taste_description = "cool mint"
	color = "#8FC58A"
	adj_temp = 10

/datum/reagent/drink/mint_tea/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
	..()
	if (holder)
		holder.remove_reagent("food_poisoning", 2 * removed)

/datum/reagent/drink/dandelion_coffee
	name = "Dandelion Coffee"
	id = "dandelion_coffee"
	description = "A roasted dandelion root drink. It tastes like coffee and warms you up, without coffee's kick."
	taste_description = "roasted roots"
	color = "#3B2414"
	adj_drowsy = -1
	adj_sleepy = -1
	adj_temp = 25

/datum/reagent/drink/rosehip_tea
	name = "Rosehip Tea"
	id = "rosehip_tea"
	description = "A tart red tea of rose hips. It helps the body mend small wounds."
	taste_description = "tart berries"
	color = "#B83A2E"
	nutrition = 1
	adj_temp = 10
	metabolism = 0.1

/datum/reagent/drink/rosehip_tea/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
	..()
	M.heal_organ_damage(2 * removed, 0)

/datum/reagent/drink/rose_tea
	name = "Rose Tea"
	id = "rose_tea"
	description = "A fragrant tea of dried rose petals."
	taste_description = "roses"
	color = "#E79AB0"
	adj_temp = 10

/datum/reagent/drink/rose_tea/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
	..()
	if (istype(M))
		M.adjust_mood(removed * 3, "rose tea")

#undef HERB_FRESH_STEEP
#undef HERB_DRIED_STEEP
