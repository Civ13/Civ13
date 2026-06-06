// Magic Items and Potions

/obj/item/weapon/reagent_containers/food/drinks/bottle/small/not_butter_beer
	name = "I-Can't-Believe-It's-Not-Butter-Beer"
	desc = "Wait, is it actually butter beer? No, you can't believe it's not!"
	icon_state = "oldstyle_beer"
	item_state = "beer"
	volume = 50
	New()
		..()
		reagents.add_reagent("not_butter_beer", 50)

/datum/reagent/drink/not_butter_beer
	name = "I-Can't-Believe-It's-Not-Butter-Beer"
	id = "not_butter_beer"
	description = "A buttery alcoholic beverage that feels magical."
	taste_description = "sweet buttery ale"
	color = "#c89d3c"

/datum/reagent/drink/not_butter_beer/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
	..()
	if (ishuman(M))
		var/mob/living/human/H = M
		if (H.juice < H.max_juice)
			H.juice = min(H.max_juice, H.juice + 1.0 * removed)
		H.eye_blurry = max(H.eye_blurry, 3)
		if (H.dizziness < 108)
			H.make_dizzy(108 - H.dizziness)


/obj/item/weapon/reagent_containers/food/drinks/bottle/small/green_goop
	name = "Professor Snip's Green Goop"
	desc = "A rare potion flask containing a bubbling green fluid."
	icon = 'icons/obj/magic_items.dmi'
	icon_state = "potion_green"
	item_state = "beer"
	volume = 5
	slot_flags = SLOT_BELT | SLOT_POCKET
	New()
		..()
		reagents.add_reagent("green_goop", 5)

/datum/reagent/drink/green_goop
	name = "Professor Snip's Green Goop"
	id = "green_goop"
	description = "A rare, swirling green goop. Smells like trouble, but tastes like pure energy."
	taste_description = "sour chemicals and raw power"
	color = "#00FF00"

/datum/reagent/drink/green_goop/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
	..()
	if (ishuman(M))
		var/mob/living/human/H = M
		if (H.juice < H.max_juice)
			H.juice = min(H.max_juice, H.juice + 20.0 * removed)
		H.stats["stamina"][1] = H.stats["stamina"][2]
	M.adjustToxLoss(1.0 * removed)

/obj/item/weapon/reagent_containers/food/snacks/chocotoad
	name = "Choco-Toad"
	desc = "A chocolate toad. Eating one instantly restores 50 Juice."
	icon = 'icons/obj/magic_items.dmi'
	icon_state = "chocotoad"
	volume = 10
	bitesize = 10
	biteamount = 1
	nutriment_amt = 2
	nutriment_desc = list("chocolate" = 2)

/obj/item/weapon/reagent_containers/food/snacks/chocotoad/On_Consume(var/mob/M)
	..()
	if (ishuman(M))
		var/mob/living/human/H = M
		if (H.juice < H.max_juice)
			H.juice = min(H.max_juice, H.juice + 50)


/obj/item/wand_part
	icon = 'icons/obj/magic_items.dmi'
	slot_flags = SLOT_BELT | SLOT_POCKET

/obj/item/wand_part/badger_hair
	name = "Badger hair"
	desc = "A tuft of badger fur infused with martial instinct. It forms a combat-savvy wand core."
	icon_state = "badger_hair"

/obj/item/wand_part/pigeon_feather
	name = "Pigeon feather"
	desc = "A sleek feather that flutters with movement magic. It helps a wand cast and blink quickly."
	icon_state = "pigeon_feather"

/obj/item/wand_part/copper_wire
	name = "Copper wire"
	desc = "A copper filament that conducts arcane power while inviting volatile overcasts. It reduces juice cost at a risk."
	icon_state = "copper_wire"

/obj/item/wand_part/pocket_lint
	name = "Pocket lint"
	desc = "A handful of soft lint scavenged from pockets. Its unpredictable energy makes a wand wildly unstable."
	icon_state = "pocket_lint"

/obj/item/wand_part/asbestos
	name = "Asbestos fibre"
	desc = "Fibrous asbestos wadding that resists flame. It keeps a wand fireproof at a poisonous cost."
	icon_state = "asbestos"

/obj/item/wand_part/fox_fur
	name = "Fox fur"
	desc = "A strip of fox fur with a cunning sheen. It silences a wand's magic while slowing its spellcasting."
	icon_state = "fox_fur"

/obj/item/wand_part/chewing_gum
	name = "Used chewing gum"
	desc = "Scraped from the underside of Professor Snip's desk. Highly unhygienic and incredibly sticky."
	icon_state = "chewing_gum"

/obj/item/wand_part/cassette_tape
	name = "Tangled cassette tape"
	desc = "Magnetic tape ripped from a confiscated 1980s synth-pop mixtape. It crackles with unstable, looping energy."
	icon_state = "cassette_tape"

/obj/item/wand_part/sheep_wool
	name = "Damp sheep wool"
	desc = "Snagged on a barbed-wire fence near the Mop Ball pitch. Smells strongly of rain and lanolin."
	icon_state = "sheep_wool"

/obj/item/wand_part/rat_tail
	name = "Feral rat tail"
	desc = "Found in the dark corners of the Slatepie common room. The essence of a true survivor, but ultimately a coward."
	icon_state = "rat_tail"

/obj/item/wand_part/spark_plug
	name = "Rusted spark plug"
	desc = "Plucked from a broken-down tractor in Farmer Evans' field. Heavy, metallic, and surges with raw kinetic energy."
	icon_state = "spark_plug"

/obj/item/wand_part/gnat_wing
	name = "Golden gnat wing"
	desc = "So fast it hums. It wants to fly away, even when stuffed inside a piece of wood."
	icon_state = "gnat_wing"

/obj/item/wand_part/gloom_thread
	name = "Gloom-weave thread"
	desc = "Freezing cold to the touch. It feels like holding pure depression."
	icon_state = "gloom_thread"

/obj/item/wand_part/pine_wood
	name = "Pine wood"
	desc = "A splinter-prone pine branch. It is a common wand chassis with balanced magic traits."
	icon_state = "pine_wood"

/obj/item/wand_part/mdf_board
	name = "MDF board"
	desc = "A dense MDF segment that absorbs juice and swells when wet. It makes a wand cheap but fragile."
	icon_state = "mdf_board"

/obj/item/wand_part/balsa_wood
	name = "Balsa wood"
	desc = "A featherlight balsa slat. It is fast and fragile, and a wand built from it snaps easily in melee."
	icon_state = "balsa_wood"

/obj/item/wand_part/snooker_cue
	name = "Snooker cue"
	desc = "A polished snooker cue shaft. It gives a wand strong melee power at the expense of cast speed."
	icon_state = "snooker_cue"

/obj/item/wand_part/fibreglass
	name = "Fibreglass"
	desc = "A whippy strip of fibreglass. It makes a wand lash out on overcasts and cast very quickly."
	icon_state = "fibreglass"

/obj/item/wand_part/driftwood
	name = "Driftwood"
	desc = "A piece of bleached driftwood with elemental resonance. It smells faintly of the sea and enhances spell efficiency."
	icon_state = "driftwood"

/obj/item/wand_part/stale_chip
	name = "Stale chip (French fry)"
	desc = "Dropped during Tuesday's lunch service by Lunch Lady Doris and hardened over months into an indestructible, rock-like substance."
	icon_state = "stale_chip"

/obj/item/wand_part/shrub_root
	name = "Shrieking shrub root"
	desc = "A thick, vibrating root that constantly emits a faint, high-pitched whimper. It is incredibly magically volatile."
	icon_state = "shrub_root"

/obj/item/wand_part/cap_truncheon
	name = "C.A.P. truncheon"
	desc = "Standard-issue Ministry police baton. Carved from dense, magic-resistant mahogany and weighted with lead."
	icon_state = "cap_truncheon"

/obj/effect/spawner/objspawner/wandpart/pine_wood
	name = "wand part spawner"
	icon_state = "f2"
	max_number = 5
	max_range = 7
	create_path = /obj/item/wand_part/pine_wood
	timer = 1800

/obj/effect/spawner/objspawner/wandpart/mdf_board
	name = "wand part spawner"
	icon_state = "f2"
	max_number = 5
	max_range = 7
	create_path = /obj/item/wand_part/mdf_board
	timer = 1800

/obj/effect/spawner/objspawner/wandpart/balsa_wood
	name = "wand part spawner"
	icon_state = "f2"
	max_number = 5
	max_range = 7
	create_path = /obj/item/wand_part/balsa_wood
	timer = 1800

/obj/effect/spawner/objspawner/wandpart/fibreglass
	name = "wand part spawner"
	icon_state = "f2"
	max_number = 5
	max_range = 7
	create_path = /obj/item/wand_part/fibreglass
	timer = 1800

/obj/effect/spawner/objspawner/wandpart/driftwood
	name = "wand part spawner"
	icon_state = "f2"
	max_number = 5
	max_range = 7
	create_path = /obj/item/wand_part/driftwood
	timer = 1800

/obj/effect/spawner/objspawner/wandpart/snooker_cue
	name = "wand part spawner"
	icon_state = "f2"
	max_number = 5
	max_range = 7
	create_path = /obj/item/wand_part/snooker_cue
	timer = 1800

/obj/effect/spawner/objspawner/wandpart/badger_hair
	name = "wand part spawner"
	icon_state = "f3"
	max_number = 5
	max_range = 7
	create_path = /obj/item/wand_part/badger_hair
	timer = 1800

/obj/effect/spawner/objspawner/wandpart/pigeon_feather
	name = "wand part spawner"
	icon_state = "f3"
	max_number = 5
	max_range = 7
	create_path = /obj/item/wand_part/pigeon_feather
	timer = 1800

/obj/effect/spawner/objspawner/wandpart/copper_wire
	name = "wand part spawner"
	icon_state = "f3"
	max_number = 5
	max_range = 7
	create_path = /obj/item/wand_part/copper_wire
	timer = 1800

/obj/effect/spawner/objspawner/wandpart/pocket_lint
	name = "wand part spawner"
	icon_state = "f3"
	max_number = 5
	max_range = 7
	create_path = /obj/item/wand_part/pocket_lint
	timer = 1800

/obj/effect/spawner/objspawner/wandpart/asbestos
	name = "wand part spawner"
	icon_state = "f3"
	max_number = 5
	max_range = 7
	create_path = /obj/item/wand_part/asbestos
	timer = 1800

/obj/effect/spawner/objspawner/wandpart/fox_fur
	name = "wand part spawner"
	icon_state = "f3"
	max_number = 5
	max_range = 7
	create_path = /obj/item/wand_part/fox_fur
	timer = 1800


/obj/effect/spawner/objspawner/wandpart/stale_chip
	name = "wand part spawner"
	icon_state = "f3"
	max_number = 5
	max_range = 7
	create_path = /obj/item/wand_part/stale_chip
	timer = 1800

/obj/effect/spawner/objspawner/wandpart/shrub_root
	name = "wand part spawner"
	icon_state = "f2"
	max_number = 5
	max_range = 7
	create_path = /obj/item/wand_part/shrub_root
	timer = 1800

/obj/effect/spawner/objspawner/wandpart/cap_truncheon
	name = "wand part spawner"
	icon_state = "f2"
	max_number = 5
	max_range = 7
	create_path = /obj/item/wand_part/cap_truncheon
	timer = 1800

/obj/effect/spawner/objspawner/wandpart/chewing_gum
	name = "wand part spawner"
	icon_state = "f3"
	max_number = 5
	max_range = 7
	create_path = /obj/item/wand_part/chewing_gum
	timer = 1800

/obj/effect/spawner/objspawner/wandpart/cassette_tape
	name = "wand part spawner"
	icon_state = "f3"
	max_number = 5
	max_range = 7
	create_path = /obj/item/wand_part/cassette_tape
	timer = 1800

/obj/effect/spawner/objspawner/wandpart/sheep_wool
	name = "wand part spawner"
	icon_state = "f3"
	max_number = 5
	max_range = 7
	create_path = /obj/item/wand_part/sheep_wool
	timer = 1800

/obj/effect/spawner/objspawner/wandpart/rat_tail
	name = "wand part spawner"
	icon_state = "f3"
	max_number = 5
	max_range = 7
	create_path = /obj/item/wand_part/rat_tail
	timer = 1800

/obj/effect/spawner/objspawner/wandpart/spark_plug
	name = "wand part spawner"
	icon_state = "f3"
	max_number = 5
	max_range = 7
	create_path = /obj/item/wand_part/spark_plug
	timer = 1800

/obj/effect/spawner/objspawner/wandpart/gnat_wing
	name = "wand part spawner"
	icon_state = "f3"
	max_number = 5
	max_range = 7
	create_path = /obj/item/wand_part/gnat_wing
	timer = 1800

/obj/effect/spawner/objspawner/wandpart/gloom_thread
	name = "wand part spawner"
	icon_state = "f3"
	max_number = 5
	max_range = 7
	create_path = /obj/item/wand_part/gloom_thread
	timer = 1800

/obj/item/weapon/basketball/mopball
	name = "mop ball"
	desc = "A ball used for playing mop ball. It is slightly bouncy and very dirty."