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
	if (M.juice < M.max_juice)
		M.juice = min(M.max_juice, M.juice + 1.0 * removed)
	M.eye_blurry = max(M.eye_blurry, 3)
	if (M.dizziness < 108)
		M.make_dizzy(108 - M.dizziness)


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
	if (M.juice < M.max_juice)
		M.juice = min(M.max_juice, M.juice + 20.0 * removed)
	M.stats["stamina"][1] = M.stats["stamina"][2]
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

