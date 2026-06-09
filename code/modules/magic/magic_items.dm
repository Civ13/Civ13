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

// ============================================================
// BRENDA'S "SPECIAL RESERVE" WELSH RUM
// ============================================================

/obj/item/weapon/reagent_containers/food/drinks/bottle/welsh_rum
	name = "Brenda's \"Special Reserve\" Welsh Rum"
	desc = "A grimy bottle with a handwritten label that reads 'Property of B. Brenda — Touch this and I'll break your wand arm.'"
	icon = 'icons/obj/magic_items.dmi'
	icon_state = "rumbottle"
	item_state = "beer"
	volume = 60
	value = 50
	New()
		..()
		reagents.add_reagent("welsh_rum", 60)

/obj/item/weapon/reagent_containers/food/drinks/bottle/welsh_rum/empty
	name = "empty bottle of Brenda's rum"
	desc = "An empty bottle. The smell of cheap rum and despair still lingers."
	icon_state = "rumbottle"
	value = 1
	New()
		..()
		reagents.del_reagents()

/datum/reagent/drink/welsh_rum
	name = "Brenda's \"Special Reserve\" Welsh Rum"
	id = "welsh_rum"
	description = "Bathtub-brewed since 1982. Strips paint, but gets you through an exam."
	taste_description = "burning rubber and defiance"
	color = "#8B4513"
	metabolism = REM * 6

/datum/reagent/drink/welsh_rum/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
	..()
	if (ishuman(M))
		var/mob/living/human/H = M
		if (H.juice < H.max_juice)
			H.juice = min(H.max_juice, H.juice + 1.0 * removed)
		H.add_chemical_effect(CE_PAINKILLER, 250)
		H.slurring = max(H.slurring, 45)

// ============================================================
// THE "CHAMELEON" MAC (Bootleg Invisibility Cloak)
// ============================================================

/obj/item/clothing/suit/chameleon_mac
	name = "\"Chameleon\" Mac"
	desc = "A smelly, translucent 1980s plastic raincoat. Brenda swears it's woven from invisible beasts; it's actually highly reflective Ministry-grade plastic. Stand still and you'll vanish."
	icon = 'icons/obj/magic_items.dmi'
	icon_state = "mac_jacket"
	item_state = "mac_jacket"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|ARMS
	armor = list(melee = 5, arrow = 0, gun = FALSE, energy = 0, bomb = 0, bio = 0, rad = 0)
	slot_flags = SLOT_OCLOTHING
	value = 200
	var/mob/living/human/wearer = null
	var/last_x = 0
	var/last_y = 0
	var/last_z = 0
	var/stand_still_time = 0
	var/hidden = FALSE
	var/normal_alpha = 101

/obj/item/clothing/suit/chameleon_mac/equipped(var/mob/user, var/slot)
	..()
	if (slot == slot_wear_suit && ishuman(user))
		wearer = user
		normal_alpha = wearer.alpha
		processing_objects |= src

/obj/item/clothing/suit/chameleon_mac/dropped(var/mob/user)
	if (wearer)
		wearer.alpha = normal_alpha
		wearer = null
	processing_objects -= src
	..()

/obj/item/clothing/suit/chameleon_mac/Destroy()
	if (wearer)
		wearer.alpha = normal_alpha
		wearer = null
	processing_objects -= src
	return ..()

/obj/item/clothing/suit/chameleon_mac/process()
	if (!wearer || wearer.stat || !isturf(wearer.loc))
		return
	if (loc != wearer)
		return

	if (wearer.x != last_x || wearer.y != last_y || wearer.z != last_z)
		last_x = wearer.x
		last_y = wearer.y
		last_z = wearer.z
		stand_still_time = world.time
		if (hidden)
			hidden = FALSE
			wearer.alpha = normal_alpha
		return

	if (world.time - stand_still_time >= 50 && !hidden)
		hidden = TRUE
		wearer.alpha = 0

// ============================================================
// CWM-PLWD DITCH-WEED (Bootleg Night-Vision)
// ============================================================

/obj/item/weapon/reagent_containers/food/snacks/ditch_weed
	name = "Cwm-Plwd Ditch-Weed"
	desc = "A glowing, radioactive-looking weed harvested from the toxic runoff pipe behind the potion dungeons. Eating it will violently mutate your eyes."
	icon = 'icons/obj/magic_items.dmi'
	icon_state = "ditch_weed"
	volume = 5
	bitesize = 5
	biteamount = 1
	nutriment_amt = 0
	value = 40

/obj/item/weapon/reagent_containers/food/snacks/ditch_weed/On_Consume(var/mob/M)
	..()
	if (ishuman(M))
		var/mob/living/human/H = M
		H.thermal = TRUE
		H.handle_vision()
		to_chat(H, SPAN_NOTICE("Your eyes burn and warp — the world shimmers in green and heat!"))
		spawn(2400)
			if (H && ishuman(H))
				H.thermal = FALSE
				H.handle_vision()
				to_chat(H, SPAN_NOTICE("The thermal shimmer fades from your vision."))

// ============================================================
// THE "BOTTOMLESS" TESCO CARRIER BAG
// ============================================================

/obj/item/weapon/storage/tesco_bag
	name = "\"Bottomless\" Tesco Carrier Bag"
	desc = "A crinkled, slightly sticky plastic grocery bag from a non-magical supermarket. Brenda charmed it herself in the pub's cellar. It can hold a ludicrous amount of stuff — but sharp objects might tear it."
	icon = 'icons/obj/magic_items.dmi'
	icon_state = "tesco_bag"
	item_state = "plasticbag"
	w_class = ITEM_SIZE_SMALL
	max_w_class = ITEM_SIZE_HUGE
	max_storage_space = 200
	storage_slots = null
	slot_flags = SLOT_BELT | SLOT_POCKET
	value = 80

/obj/item/weapon/storage/tesco_bag/handle_item_insertion(obj/item/W, prevent_warning = FALSE)
	. = ..()
	if (. && is_sharp(W) && prob(5))
		rip_bag()

/obj/item/weapon/storage/tesco_bag/proc/rip_bag()
	var/turf/center = get_turf(src)
	playsound(center, 'sound/effects/rip_pack.ogg', 100, TRUE)
	visible_message(SPAN_DANGER("[src] tears apart violently, scattering its contents everywhere!"))
	for (var/obj/item/I in contents)
		remove_from_storage(I, center)
		var/turf/target = locate(center.x + rand(-2, 2), center.y + rand(-2, 2), center.z)
		if (target && !target.density)
			I.loc = target
		else
			I.loc = center
	qdel(src)

// ============================================================
// THE "DEAD-ZONE" CAR BATTERY
// ============================================================

/obj/item/weapon/dead_zone_battery
	name = "\"Dead-Zone\" Car Battery"
	desc = "A rusted lead-acid battery pulled from an old car. Anti-magic copper runes are crudely etched into the casing. When activated, it grounds out all arcane frequencies in a wide area."
	icon = 'icons/obj/magic_items.dmi'
	icon_state = "car_battery"
	item_state = "car_battery"
	w_class = ITEM_SIZE_LARGE
	value = 120
	var/cooldown_time = 0
	var/active = FALSE

/obj/item/weapon/dead_zone_battery/attack_self(mob/user)
	if (!ishuman(user))
		return
	var/mob/living/human/H = user
	if (active)
		to_chat(H, SPAN_WARNING("The battery is already discharging!"))
		return
	if (world.time < cooldown_time)
		var/remaining = round((cooldown_time - world.time) / 10)
		to_chat(H, SPAN_WARNING("The battery needs to recharge. Wait [remaining] seconds."))
		return

	H.visible_message(SPAN_DANGER("[H] slams \the [src] onto the ground! A pulse of invisible energy expands outward!"))
	playsound(H.loc, 'sound/effects/spells/blockum.ogg', 80, TRUE)

	H.drop_from_inventory(src)
	loc = get_turf(H)

	new /obj/effect/null_zone(loc, H)

	active = TRUE
	cooldown_time = world.time + 900
	spawn(300)
		if (src)
			active = FALSE

/obj/effect/null_zone
	name = "null zone"
	desc = "The air feels dead and heavy here."
	invisibility = 101
	anchored = TRUE
	density = FALSE
	var/created_time = 0
	var/mob/living/human/owner = null
	var/list/affected_mobs = list()

/obj/effect/null_zone/New(loc, var/mob/living/human/setter)
	..()
	created_time = world.time
	owner = setter
	processing_objects |= src

/obj/effect/null_zone/Destroy()
	for (var/mob/living/human/H in affected_mobs)
		if (H)
			H.no_magic = FALSE
			to_chat(H, SPAN_NOTICE("The null zone dissipates. You can feel magic again."))
	affected_mobs.Cut()
	processing_objects -= src
	. = ..()

/obj/effect/null_zone/process()
	if (world.time - created_time >= 300)
		qdel(src)
		return

	for (var/mob/living/human/H in range(3, src))
		if (H.stat || H == owner)
			continue
		if (H.faction == "Moldywart")
			continue
		if (!(H in affected_mobs))
			affected_mobs += H
			H.no_magic = TRUE
			to_chat(H, SPAN_DANGER("An oppressive numbness floods your body — the null zone suppresses all magic!"))

	var/i = 1
	while (i <= affected_mobs.len)
		var/mob/living/human/H = affected_mobs[i]
		if (!H)
			affected_mobs.Cut(i, i + 1)
		else if (H.stat || get_dist(H, src) > 3)
			H.no_magic = FALSE
			to_chat(H, SPAN_NOTICE("You step out of the null zone. Magic feels possible again."))
			affected_mobs.Cut(i, i + 1)
		else
			i++