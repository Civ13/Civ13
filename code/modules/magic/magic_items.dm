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
	icon_state = "frat_tail"

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



/obj/item/weapon/book/manual/barman_recipes
	name = "Barman Recipes"
	icon_state = "barbook"
	author = "Sir John Rose"
	title = "Barman Recipes"

	dat = {"<html>
				<head>
				<style>
				h1 {font-size: 18px; margin: 15px 0px 5px;}
				h2 {font-size: 15px; margin: 15px 0px 5px;}
				h3 {font-size: 13px; margin: 15px 0px 5px;}
				li {margin: 2px 0px 2px 15px;}
				ul {margin: 5px; padding: 0px;}
				ol {margin: 5px; padding: 0px 15px;}
				body {font-size: 13px; font-family: Verdana;}
				</style>
				</head>
				<body>

				<h1>Drinks for Dummies</h1>
				Here's a guide for some basic drinks.

				<h3>Black Russian:</h3>
				Mix vodka and Kahlua into a glass.

				<h3>Cafe Latte:</h3>
				Mix milk and coffee into a glass.

				<h3>Classic Martini:</h3>
				Mix vermouth and gin into a glass.

				<h3>Gin Tonic:</h3>
				Mix gin and tonic into a glass.

				<h3>Grog:</h3>
				Mix rum and water into a glass.

				<h3>Irish Cream:</h3>
				Mix cream and whiskey into a glass.

				<h3>The Manly Dorf:</h3>
				Mix ale and beer into a glass.

				<h3>Mead:</h3>
				Mix enzyme, water, and sugar into a glass.

				<h3>Screwdriver:</h3>
				Mix vodka and orange juice into a glass.

				</body>
			</html>
			"}

/obj/item/weapon/book/manual/potions
	name = "Professor Snip's Cauldron-Stirring Syllabus"
	icon_state = "grimoire0"
	author = "Professor Snip"
	title = "Professor Snip's Cauldron-Stirring Syllabus"

	dat = {"<html>
				<head>
				<style>
				h1 {font-size: 18px; margin: 15px 0px 5px; color: #800000;}
				h2 {font-size: 15px; margin: 15px 0px 5px; color: #4b0082;}
				h3 {font-size: 13px; margin: 10px 0px 3px; color: #006400;}
				li {margin: 2px 0px 2px 15px;}
				ul {margin: 5px; padding: 0px;}
				ol {margin: 5px; padding: 0px 15px;}
				body {font-size: 13px; font-family: Verdana; background-color: #fadb6f;}
				</style>
				</head>
				<body>

				<h1>Cauldron-Stirring Syllabus</h1>
				<p><i>Compiled by Professor Snip, Department of Potions and Disappointment.</i></p>
				<p>Pay close attention. I will not repeat these instructions. If you manage to blow up the laboratory or poison yourself, you will receive a grade of Zero and serve detention until the end of the semester. Stir counter-clockwise unless you desire a sudden trip to the hospital wing.</p>

				<h2>Standard Curricular Potions</h2>

				<h3>1. Skele-Bones Broth</h3>
				<ul>
					<li><b>Ingredients:</b> 2 units Milk, 2 units Paracetamol, 1 unit Sugar.</li>
					<li><b>Properties:</b> Knits broken bones back together and acts as a powerful painkiller.</li>
					<li><b>Notes:</b> Tastes like chalk and despair. Do not complain to me about the flavor.</li>
				</ul>

				<h3>2. Welsh Instant Darkness Powder</h3>
				<ul>
					<li><b>Ingredients:</b> 1 unit Potassium, 1 unit Phosphorus, 1 unit Sugar.</li>
					<li><b>Properties:</b> Fizzes into a dense, throwable powder. When thrown and shattered, it releases a massive, billowing cloud of absolute darkness.</li>
					<li><b>Notes:</b> Completely inert if ingested, though it tastes like Swansea coal dust.</li>
				</ul>

				<h3>3. Liquid Gamble</h3>
				<ul>
					<li><b>Ingredients:</b> 2 units Adrenaline, 1 unit Mindbreaker, 2 units Goldschlager.</li>
					<li><b>Properties:</b> Induces terrifying speed, total pain relief, and overrides paralysis or stunning.</li>
					<li><b>Notes:</b> Banned before exams. Side effects include severe jitters, dizziness, and intense hallucinations (primarily of non-existent spiders).</li>
				</ul>

				<h3>4. Heart-Throb Syrup</h3>
				<ul>
					<li><b>Ingredients:</b> 1 unit Chloral Hydrate, 1 unit Sugar, 1 unit Wine.</li>
					<li><b>Properties:</b> Induces severe drowsiness, rapidly followed by deep unconsciousness.</li>
					<li><b>Notes:</b> Rumoured by idiots to induce romance. In reality, it only induces sleep. Excellent for keeping rowdy students quiet.</li>
				</ul>

				<h3>5. Polysoup Paste</h3>
				<ul>
					<li><b>Ingredients:</b> 1 unit Blood, 1 unit Ammonia, 1 unit Protein.</li>
					<li><b>Properties:</b> A vile grey-green sludge. Does NOT change your appearance, despite what schoolyard rumours claim.</li>
					<li><b>Notes:</b> Causes immediate toxin poisoning, vomiting, and a highly hazardous slippery mess on the floor. Grade: Automatic F.</li>
				</ul>

				<h3>6. Pep-Up Juice</h3>
				<ul>
					<li><b>Ingredients:</b> 3 units Coffee, 1 unit Condensed Capsaicin, 1 unit Ethanol.</li>
					<li><b>Properties:</b> Warms the consumer instantly and heals internal organ damage.</li>
					<li><b>Notes:</b> Over-consumption will lead to excessive body heat, resulting in severe internal throat burns. Sip, do not chug.</li>
				</ul>

				<h3>7. Toad Mixture (The Exploding Toad)</h3>
				<ul>
					<li><b>Ingredients:</b> 2 units Water, 2 units Potassium.</li>
					<li><b>Properties:</b> A metallic silver, highly unstable liquid. Explosive on impact when thrown and shattered.</li>
					<li><b>Notes:</b> Under NO circumstances are you to drink this, unless you wish to disintegrate your digestive tract. Do NOT place this container on my desk.</li>
				</ul>

				</body>
			</html>
			"}

/obj/item/weapon/book/manual/wand_crafting
	name = "Splinters' Guide to Bootleg Wands"
	icon_state = "book18"
	author = "Seamus 'Splinters' O'Shaughnessy"
	title = "Splinters' Guide to Bootleg Wands"

	dat = {"<html>
				<head>
				<style>
				h1 {font-size: 18px; margin: 15px 0px 5px; color: #800000;}
				h2 {font-size: 15px; margin: 15px 0px 5px; color: #4b0082;}
				h3 {font-size: 13px; margin: 10px 0px 3px; color: #006400;}
				li {margin: 2px 0px 2px 15px;}
				ul {margin: 5px; padding: 0px;}
				ol {margin: 5px; padding: 0px 15px;}
				body {font-size: 13px; font-family: Verdana; background-color: #fadb6f;}
				</style>
				</head>
				<body>

				<h1>Splinters' Guide to Bootleg Wands</h1>
				<p><i>Written by Seamus 'Splinters' O'Shaughnessy, 7th Year Mintysnek.</i></p>
				<p>Listen up, first-years. The wands the school issues are made of cheap pine and cotton thread. They snap if you look at them funny. If you want a wand that actually does damage, or one that fits in your boot, you have to build it yourself. Bring me the parts behind the greenhouse, and I'll assemble it for ten Francs. Here's what you need to know.</p>

				<h2>The Three Components</h2>
				<ul>
					<li><b>The Wood (The Body):</b> Determines how fast you can wave the thing, and how hard it hits if you just smack someone with it. (e.g., Balsa, Fibreglass, Driftwood, Snooker Cue).</li>
					<li><b>The Core (The Engine):</b> Determines Juice efficiency, misfire chance, and special quirks. (e.g., Badger Hair, Pigeon Feather, Copper Wire, Fox Fur, Asbestos).</li>
					<li><b>The Length (The Chassis):</b> Determines your spell range and whether the P.L.O.D. can see it in your pocket. (Stubby, Standard, Overcompensator, Telescopic).</li>
				</ul>

				<h2>Advanced Materials</h2>
				<ul>
					<li><b>Driftwood:</b> Picked up from the shores of Cwm-Tlawd. It's soggy and smells of salt, but it has a natural resonance with the elements. Very efficient, though it lacks the 'snap' of drier woods.</li>
					<li><b>Asbestos Fibre:</b> A core for the truly reckless. It makes the wand almost entirely immune to catching fire during a botched <i>Burnus!</i> cast, but the dust will slowly rot your lungs. A fair trade.</li>
				</ul>

				<h2>Splinters' Recommended Builds</h2>

				<h3>1. The Sea-Shanty</h3>
				<ul>
					<li><b>Parts:</b> Driftwood + Pigeon Feather + Standard Length.</li>
					<li><b>The Vibe:</b> Reliable, rhythmic, and smells like a wet dog. Great for students who want to keep moving without running out of Juice.</li>
				</ul>

				<h3>2. The Hallway Ghost</h3>
				<ul>
					<li><b>Parts:</b> Balsa Wood + Fox Fur Core + Stubby Length.</li>
					<li><b>The Vibe:</b> The ultimate smuggler's wand. Fits perfectly in a sock.</li>
					<li><b>Performance:</b> The Balsa makes it cast incredibly fast, while the Fox Fur makes your spells completely invisible and silent. Perfect for casting <i>Dropus!</i> on a prefect and walking away. Just don't hit anyone with it—it will snap in half instantly.</li>
				</ul>

				<h3>3. The Pub Brawler</h3>
				<ul>
					<li><b>Parts:</b> Broken Snooker Cue + Badger Hair + Standard Length.</li>
					<li><b>The Vibe:</b> A heavy, brutal piece of work. For the Rubywyrm who prefers violence over magic.</li>
					<li><b>Performance:</b> Takes forever to cast a spell because it's so heavy, but the Badger Hair makes your offensive curses hit harder. If you run out of Juice, it functions as a highly lethal bludgeoning weapon.</li>
				</ul>

				<h3>4. The Copper Sniper</h3>
				<ul>
					<li><b>Parts:</b> Fibreglass Tent Pole + Copper Wire + Overcompensator Length.</li>
					<li><b>The Vibe:</b> Looks like a radioactive fishing rod. Shoots like a cannon.</li>
					<li><b>Performance:</b> The Fibreglass and Copper combo makes casting lightning-fast and highly Juice-efficient, while the massive length increases your maximum spell range. <b>WARNING:</b> If you overcast with copper wire, the wand will violently electrocute you.</li>
				</ul>

				<h3>5. The Fire-Breather</h3>
				<ul>
					<li><b>Parts:</b> Pine Wood + Asbestos Core + Overcompensator.</li>
					<li><b>The Vibe:</b> For the pyromaniac who wants to cast <i>Burnus!</i> all day without their wand melting. Try not to breathe in while casting.</li>
				</ul>

				<h3>6. The Puddle-Jumper (The Desperation Build)</h3>
				<ul>
					<li><b>Parts:</b> MDF Board + Pocket Lint + Telescopic Length.</li>
					<li><b>The Vibe:</b> Made of literal garbage. Cost you zero Francs to build.</li>
					<li><b>Performance:</b> The pocket lint means every cast is a gamble—it might cost double Juice, it might cost zero. Because it's made of cheap MDF, if you use it in the rain, it will swell up like a sponge, double your cast time, and likely blow your eyebrows off. You have been warned.</li>
				</ul>

				</body>
			</html>
			"}

/obj/item/weapon/book/manual/student_handbook
	name = "The L.A.M.E. Student Handbook"
	icon_state = "book_lame"
	author = "Ministry of Arcane Standards & Practices"
	title = "L.A.M.E. Student Handbook: A Guide to Academic Progression"

	dat = {"<html>
				<head>
				<style>
				h1 {font-size: 18px; margin: 15px 0px 5px; color: #000080;}
				h2 {font-size: 15px; margin: 15px 0px 5px; color: #8b0000;}
				h3 {font-size: 13px; margin: 10px 0px 3px; color: #2f4f4f;}
				li {margin: 2px 0px 2px 15px;}
				ul {margin: 5px; padding: 0px;}
				ol {margin: 5px; padding: 0px 15px;}
				body {font-size: 13px; font-family: Verdana; background-color: #f0f8ff;}
				</style>
				</head>
				<body>

				<h1>The L.A.M.E. Student Handbook</h1>
				<p><i>Published by the Ministry of Arcane Standards & Practices.</i></p>
				<p>Welcome to the Llanboarwart Academy of Magical Education. Statistically speaking, you are currently a hazard to yourself and everyone around you. To ensure the school continues to receive its government funding, you must progress through the standardized academic tiers. Failure to do so will result in a life of sweeping floors.</p>
				
				<p>Below are the official examinations required to upgrade your magical license.</p>

				<h2>1. The I.D.I.O.T. Phase</h2>
				<p>If you have recently arrived, you are classified as an <b>I.D.I.O.T.</b> (Incompetent Dunderhead In Official Training). You cannot cast proper spells, but you can swing a cricket bat quite hard.</p>
				<ul>
					<li><b>The Exam: Wand Assembly.</b></li>
					<li><b>The Task:</b> We do not hand out free wands. You must scavenge the grounds to find a piece of Wood (e.g., Pine, MDF) and a Core (e.g., Pigeon Feather, Badger Hair). Combine them at a crafting workbench to create your first functional wand.</li>
					<li><b>The Reward:</b> Upgrades you to the <b>U.N.G.A.</b> (Underperforming Numpty General Assessment) tier, granting you the right to carry a wand and cast Level 1 charms.</li>
				</ul>

				<h2>2. The Cauldron Practical</h2>
				<p>To advance from <b>U.N.G.A.</b> to <b>C.O.A.L.</b>, you must prove you can handle volatile reagents without erasing the dungeon from the map.</p>
				<ul>
					<li><b>The Exam: Professor Snip's Potion Assessment.</b></li>
					<li><b>The Task:</b> Brew at least 10 units of <i>Welsh Instant Darkness Powder</i> (Potassium, Phosphorus, Sugar). Hand the container directly to Professor Snip in the Potions Dungeon.</li>
					<li><b>The Reward:</b> Upgrades you to the <b>C.O.A.L.</b> (Cwm-Tlawd Ordinary Amateur License) tier. You are now authorized to cast Level 2 spells and use the vending machines.</li>
				</ul>

				<h2>3. The Dueling Trial</h2>
				<p>To achieve <b>G.E.M.</b> status, you must prove you have the reflexes to survive a real magical duel.</p>
				<ul>
					<li><b>The Exam: The Defense Trial.</b></li>
					<li><b>The Task:</b> Enter the training ring and pull the G.E.M. Lever. You must successfully cast <i>Blockum!</i> to deflect three incoming spells, and then cast <i>Dropus!</i> to disarm the dummy.</li>
					<li><b>The Reward:</b> Upgrades you to the <b>G.E.M.</b> (Gravity & Elemental Manipulation) tier. You may now cast <i>Pushum!</i>, <i>Floatus!</i>, and <i>Blinkae!</i>.</li>
				</ul>

				<h2>4. Reaching the Apex</h2>
				<p>The final tiers, <b>B.A.S.E.D.</b> and <b>C.H.A.D.</b>, are reserved for those who have mastered both the wilderness and the arena.</p>
				<ul>
					<li><b>The Task:</b> Slay Lord Moldywart or his lieutenants to achieve <b>B.A.S.E.D.</b> status. Those who demonstrate absolute dominance in the Great Hall duels may eventually be recognized as a <b>C.H.A.D.</b> (Classified High-level Arcane Destruction).</li>
				</ul>

				<hr>

				<h2>WARNING: Disciplinary Action</h2>
				<p>Any student caught casting Forbidden Spells (<i>Painum!</i> or <i>Deadum!</i>), attacking a Professor, or bringing the school into disrepute will be immediately stripped of their rank. You will be permanently downgraded to <b>L.O.S.E.R.</b> (Llanboarwart Outcast & Sub-standard Educational Reject) status. You will wear a grey sack, and your wand privileges will be severely restricted.</p>
				<p><i>Ignorance of the rules is not an excuse. Neither is being turned into a wooden barrel.</i></p>

				</body>
			</html>
			"}

/obj/item/weapon/basketball/mopball
	name = "mop ball"
	desc = "A ball used for playing mop ball. It is slightly bouncy and very dirty."