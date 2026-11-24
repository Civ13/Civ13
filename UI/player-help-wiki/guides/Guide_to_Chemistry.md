# Guide to Chemistry

Use a laboratory reaction bench when several recipes share feedstocks: it lets you choose the intended reaction instead of relying on automatic mixing. These are simplified game conversions, not real laboratory instructions.

## Equipment and feedstocks

| Equipment | Materials | Tech-tree gate | Use |
| --- | --- | --- | --- |
| Laboratory reaction bench | 10 glass | Apothecary | Holds an installed glass container inert while you select a recipe. |
| Laboratory feedstock dispenser | 20 glass | Pharmacology | Starts with finite 100-unit feedstocks; fill beakers with its UI and refill depleted stocks from reagent containers. |
| Extraction kit | 14 iron | Apothecary | Collects biological feedstocks into an empty kit. |
| Laboratory burner | 4 iron | Apothecary | Consumes purified ethanol to heat the installed bench beaker. |
| Laboratory centrifuge | 24 electronics | Pharmacology | Separates supported mixtures; needs anchoring, cable power, medical skill and an empty collector vial. |

The bench, dispenser and burner are offered in global and Carib catalogs through the Modern Age; the centrifuge is also available in both. Map catalogs, era, skills and the active research mode still determine what you can craft. The laboratory dispenser includes elemental feedstocks plus water and purified ethanol; it is finite, and the ordinary empty chemical dispenser does not become stocked automatically.

## Run a selected reaction

1. Use a glass container on the bench to install it. Keep it installed while preparing the mixture.
2. Set transfer amounts on your other glass containers and use them on the bench to add the feedstocks. The installed mixture stays inert, avoiding competing automatic reactions.
3. Click the bench and choose the named recipe. Include any catalysts and leave room for the output; the bench scales to the available inputs. Missing inputs, catalysts or output space reject the operation without consuming ingredients.
4. Use **Remove reaction beaker** when finished. Ejection restores its previous mixing behavior, so remaining reagents can react again. It also clears heat.

## Elements from ore

An empty extraction kit also purifies ore into its element. Use the kit on a stack of iron ore (or sponge or pig iron), silver, gold, copper, tin, calamine, lead, uranium, coal, charcoal, sulphur, saltpeter or bauxite. Each use takes **one** ore from the stack and fills the kit with **5 units**. Saltpeter gives 2.5 potassium and 2.5 nitrogen. The rest of the stack stays, so empty the kit and use it again for more.

## Gelatin from meat or papaya

An empty extraction kit collects **4 units** from one supported source: collagen from an unspoiled raw meat slab or a cleaned bone (clean a bone with a knife first), Digestive Protease from a vomit decal, or Fruit Protease from an unspoiled papaya. A successful extraction consumes the source. Empty the kit into the bench before reusing it; spoiled or unsupported sources and nonempty kits consume nothing.

Gather wild papaya seeds in jungle or savanna, plant and tend them using [farming](Guide_to_Farming.md), then harvest with a knife, hatchet, bayonet or scythe. Papaya currently shares orange fruit/tree sprites; read the item's name. Other fruit does not supply Fruit Protease through this route.

| Step | Inputs | Output |
| --- | --- | --- |
| Acid precursor, if using acid treatment | 2 hydrogen + 2 chlorine; then 1 hydrogen chloride + 5 water | 1 hydrogen chloride; then 5 hydrochloric acid |
| Choose one treatment at the bench | 4 collagen + 1 hydrochloric acid, Digestive Protease **or** Fruit Protease | 5 unpurified gelatin |
| Separate in centrifuge | 5 unpurified gelatin | 4 purified gelatin |
| Finish at the bench | 4 purified gelatin + 1 water **or purified ethanol** | 5 solid gelatin |

Ordinary ethanol and blood plasma will not do. A third finishing route uses purified gelatin with both water and purified ethanol.

### Gelatin bandages

1. Optionally whip 5 gelatin into gelatin foam at the bench.
2. Use a container holding 5 units of gelatin or gelatin foam on an empty **drying rack** to spread it out to dry into **dry gelatin**.
3. Cut dry gelatin with a knife into a **gelatin sheet**.
4. Use a gelatin sheet in hand to fold it into a **gelatin bandage**, which works like any other bandage roll, including as a [tourniquet](Guide_to_Medical.md#severed-arteries-and-tourniquets).

## Wood pulp and fibres

Wood chips can be pulped at the bench, and the pulp centrifuged into cellulose. Cellulose spins into **rayon** (from 1890) or **lyocell** (from 1980) fibre, which makes ordinary cloth.

## Polymer products

Polymers from the bench can be made into useful items:

- **Polyethylene and butyl rubber:** a closed plastic bottle. **Polypropylene:** a reusable storage bag. Either polymer makes a plastic sheet.
- **Polypropylene** also makes cloth or a plastic comb; **polyethylene** makes a throwable play ball.
- With **Industrial Plastics** (World War II), 4 units of either polymer granulate into a measure of thermoplastic pellets for the [plastics molding machine](Guide_to_Factory_Automation.md#plastics-molding-machine).
- **Butyl** makes adhesive tape, stoppers and gaskets. Tape repairs drones and wraps a copper ingot into an insulated power cable; stoppers and gaskets seal small vials and drink bottles.
- Using a copper ingot on a plastic sheet makes one piece of insulated power cable.
- Plastic sheets also craft decorative plastic pipes, elbows and junctions. These are decoration only and do not carry liquids.

## Automated chemistry

Pipe networks, pumps, holding tanks, reaction vessels, bottlers and the automatic tablet press can run chemistry without anyone at the bench. See [Factory Automation](Guide_to_Factory_Automation.md#pipe-networks).

## Centrifuge setup

Secure it with a wrench and [connect cable power](Guide_to_Crafting.md#wiring). It needs **30 kW**, so a single [battery](Guide_to_Power.md) is insufficient. Your character must meet its medical skill requirement to load and operate it.

Take the lid off before pouring: a lidded beaker or vial cannot pour in or collect. Pour the input into the centrifuge; each container interaction transfers up to 10 units. Install an open, **empty vial** as collector, then click the machine to begin its **15-second** cycle. Power is checked at start and completion, and the centrifuge only holds its 30 kW on the grid while a cycle is running. Use **Remove Vial** after it stops.

The largest reagent in the mixture determines the separation: unpurified gelatin yields 80% purified gelatin; 10 blood yields 6 plasma, 3 red-cell reagent and 1 white-cell reagent; salt yields equal sodium/chlorine fractions. Capacity limits the processed amount, leaving excess input for later. Unsupported input, unavailable collector space or lost power preserves the input. Salt fractions can react again in ordinary containers; use an inert bench for elemental feedstocks.

## Heat and polypropylene

Fill the burner with **purified ethanol** from a glass container, then use it on the bench while adjacent on the same level. One unit heats the secured beaker for **one game minute**. Choose polypropylene before heat expires: 2 propylene produces 25 solid units and requires catalysts of 10 titanium tetrachloride (`titaniumchloride`), 5 boron trifluoride and 5 aluminum chloride, which are retained. Use a container large enough for the expanded output plus catalysts. Ejecting or replacing the beaker clears its heat.

The bench also selects calcium, wood-processing, polymer precursor and gasoline-chain recipes. Liquid titanium tetrachloride and solid titanium trichloride are separate reagents; the latter does not replace the catalyst.

## Engine fuel

Select **Engine fuel - 9:1 blend** with 9 gasoline and 1 purified ethanol to produce 10 units of Blended Engine Fuel. Internal engines that already accept gasoline accept this blend with the same consumption and power behavior. Diesel-only engines do not gain it, and it retains gasoline's toxicity and fire-contact behavior. See [engines and vehicles](Guide_to_Crafting.md#engines) for tank attachment and installation.

## Aspirin from willow bark

Strip bark from a willow tree with a knife and steep one strip in an open container holding at least 10 units of water; the strip adds 10 units of salicin. Mix 2 salicin with 1 sulphuric acid to get 2 salicylic acid, then mix 2 salicylic acid with 1 ethanol to get 2 aspirin. Both steps happen on their own in any beaker. See the [Guide to Medical](Guide_to_Medical.md) for finding willows and chewing the bark.

## Additional chemical reactions

This table does not list every bench recipe. Use the workflows above and the recipe menu for selected reactions. **Ctrl-F** searches this page.

## Chemical Reactions List

| Result                  | Ingredients                                             | Catalysts    | Inhibitors    | Produced Amount | ID                       |
| ----------------------- | ------------------------------------------------------- | ------------ | ------------- | --------------- | ------------------------ |
| Penicillin |  10u. enzyme 1u. acetone | none | none | 5 | penicillin |
| Tramadol |  1u. opium 1u. ethanol 1u. acetone | none | none | 3 | tramadol |
| Paracetamol |  1u. tramadol 1u. sugar 1u. water | none | none | 3 | paracetamol |
| Oxycodone |  1u. ethanol 1u. tramadol |  5u. tungsten | none | 1 | oxycodone |
| Adrenaline |  1u. acetone 1u. sugar 1u. diethylamine 1u. potassium_chloride | none | none | 5 | adrenaline |
| Soporific |  1u. chloralhydrate 4u. sugar | none |  u. phosphorus | 5 | stoxin |
| Chloral Hydrate |  1u. ethanol 3u. hclacid 1u. water | none | none | 1 | chloralhydrate |
| Potassium Chloride |  1u. sodiumchloride 1u. potassium | none | none | 2 | potassium_chloride |
| Potassium Chlorophoride |  1u. potassium_chloride 1u. tungsten 1u. chloralhydrate | none | none | 4 | potassium_chlorophoride |
| Diethylamine |  1u. ammonia 1u. ethanol | none | none | 2 | diethylamine |
| Foaming Agent |  1u. lithium 1u. hydrazine | none | none | 1 | foaming_agent |
| Hydrochloric Acid |  1u. hydrogen_chloride 5u. water | none | none | 5 | hclacid |
| Potassium Iodide |  1u. potassium 1u. iodine | none | none | 1 | potassium_iodide |
| Ammonia |  1u. nitrogen 3u. hydrogen | none | none | 1 | ammonia |
| Acetone |  1u. carbon 2u. ethanol | none | none | 1 | acetone |
| Table Salt |  1u. sodium 1u. chlorine | none | none | 1 | sodiumchloride |
| Hydrogen Chloride |  2u. hydrogen 2u. chlorine | none | none | 1 | hydrogen_chloride |
| Hydrogen Peroxide |  1u. chlorine 1u. water 1u. oxygen | none | none | 3 | hydrogen_peroxide |
| Water |  1u. oxygen 1u. hydrogen | none | none | 1 | water |
| Cider |  10u. applejuice |  5u. enzyme | none | 10 | cider |
| Glycerol |  3u. cornoil 1u. sacid | none | none | 3 | glycerol |
| Glycerol |  3u. cornoil 1u. hclacid | none | none | 3 | glycerol |
| Sodium Chloride |  1u. sodium 1u. hclacid | none | none | 2 | sodiumchloride |
| Aspirin |  5u. carbon 4u. water 2u. oxygen | none | none | 5 | aspirin |
| Salicylic Acid |  2u. salicin 1u. sacid | none | none | 2 | salicylic_acid_from_salicin |
| Aspirin |  2u. sal_acid 1u. ethanol | none | none | 2 | aspirin_from_salicylic_acid |
| Calcium carbonate |  1u. carbon 1u. calcium 3u. oxygen | none | none | 5 | calcium_carbonate |
| Carbon dioxide |  1u. carbon 2u. oxygen | none | none | 2 | carbon_dioxide |
| Sulphuric acid |  1u. sulfur 1u. oxygen 1u. hydrogen | none | none | 2 | sacid |
| Saline Glucose solution |  1u. sodiumchloride 1u. water 1u. sugar | none | none | 2 | saline_glucose |
| Aqua regia |  1u. nitric_acid 3u. clorhydric_acid | none | none | 2 | aqua_regia |
| Nitric acid |  2u. nitrogen 5u. oxygen 3u. water | none | none | 4 | nitric_acid |
| Clorhydric acid |  1u. hydrogen 1u. chlorine | none | none | 1 | clorhydric_acid |
| Baking soda |  1u. carbon_dioxide 1u. ammonia 2u. sodium_chloride | none | none | 2 | baking_soda |
| Bleach |  1u. sodium_hypochlorite 9u. water | none | none | 10 | bleach |
| Sodium hypochlorite |  1u. potassium 1u. oxygen 1u. chlorine | none | none | 2 | sodium_hypochlorite |
| Hydrazine |  1u. ammonia 1u. hydrogen 1u. nitrogen | none | none | 1 | hydrazine |
| Condensed Capsaicin |  2u. capsaicin |  5u. tungsten | none | 1 | condensedcapsaicin |
| Methylphenidate |  1u. mindbreaker 1u. hydrazine | none | none | 3 | methylphenidate |
| Citalopram |  1u. mindbreaker 1u. carbon | none | none | 3 | citalopram |
| Paroxetine |  1u. mindbreaker 1u. acetone | none | none | 3 | paroxetine |
| Lysergic acid diethylamide |  1u. enzyme 1u. diethylamine | none | none | 2 | mindbreaker |
| Explosion |  1u. water 1u. potassium | none | none | 2 | explosion_potassium |
| Nitroglycerin |  1u. glycerol 1u. potassium | none | none | 2 | nitroglycerin |
| Nitrocellulose (explodes) |  1u. cotton 1u. potassium | none |  1u. sacid | 2 | nitrocellulose |
| Guncotton |  2u. cotton 1u. potassium |  5u. sacid | none | 2 | guncotton |
| Guncotton |  2u. cotton 1u. nitric_acid | none | none | 2 | guncotton |
| Smokeless powder |  2u. guncotton 1u. ethanol | none | none | 3 | smokeless_powder |
| Gunpowder |  1u. sulfur 1u. carbon 1u. potassium | none | none | 3 | gunpowder |
| Gunpowder |  1u. sulfur 1u. charcoal 1u. potassium | none | none | 3 | gunpowder |
| Saltpeter |  2u. poo 1u. urine | none | none | 1 | potassium |
| Saltpeter |  2u. fertilizer 1u. urine | none | none | 1 | potassium |
| Napalm |  1u. gasoline 1u. cotton | none | none | 1 | napalm |
| Chemsmoke |  1u. potassium 1u. sugar 1u. phosphorus | none | none | 0.4 | chemsmoke |
| Hexachloroetane |  6u. chlorine 2u. carbon | none | none | 10 | hexachloroetane |
| Chlorine Gas |  5u. chlorine 5u. hydrogen | none | none | 5 | chlorine_gas |
| Mustard Gas |  4u. carbon 8u. hydrogen 2u. chlorine 1u. sulfur | none | none | 10 | mustard_gas |
| White Phosphorus Gas |  5u. phosphorus 5u. hydrogen | none | none | 5 | white_phosphorus_gas |
| Phosgene Gas |  5u. chlorine 2.5u. carbon 2.5u. oxygen |  5u. carbon | none | 5 | phosgene_gas |
| Xylyl Bromide |  6u. carbon 4u. hydrogen 1u. bromine | none | none | 5 | xylyl_bromide |
| Zyklon B |  10u. cyanide 5u. hydrogen | none | none | 5 | zyklon_b |
| Cyanide |  1u. carbon 1u. nitrogen | none | none | 1 | cyanide |
| Gasoline Kevlar |  5u. sacid 5u. gasoline | none | none | 1 | gas_kevlar |
| Diesel Kevlar |  5u. sacid 5u. diesel | none | none | 1 | diesel_kevlar |
| Biodiesel Kevlar |  5u. sacid 5u. biodiesel | none | none | 1 | biodiesel_kevlar |
|  |  1u. acetone 1u. carbon 1u. sugar | none | none | 3 |  |
| Hot Coco |  5u. water 1u. coco | none | none | 5 | hot_coco |
| Cheesewheel |  40u. milk |  5u. enzyme | none | 1 | cheesewheel |
| Meatball |  5u. protein 5u. flour | none | none | 3 | meatball |
| Dough |  5u. water 10u. flour | none | none | 1 | dough |
| Sweet Dough |  3u. egg 10u. flour 2u. sugar | none | none | 1 | sweet_dough |
| Goldschlager |  10u. vodka 1u. gold | none | none | 10 | goldschlager |
| Patron |  10u. tequilla 1u. silver | none | none | 10 | patron |
| Bilk |  1u. milk 1u. beer | none | none | 2 | bilk |
| Iced Tea |  1u. ice 2u. tea | none | none | 3 | icetea |
| Iced Coffee |  1u. ice 2u. coffee | none | none | 3 | icecoffee |
| Moonshine |  10u. nutriment |  5u. enzyme | none | 5 | moonshine |
| Grenadine Syrup |  10u. berryjuice |  5u. enzyme | none | 10 | grenadine |
| Wine |  10u. grapejuice |  5u. enzyme | none | 10 | wine |
| Melon Liquor |  10u. watermelonjuice |  5u. enzyme | none | 5 | melonliquor |
| Vodka |  10u. potato |  5u. enzyme | none | 5 | vodka |
| Coca Wine |  10u. wine 1u. cocaine |  5u. enzyme | none | 10 | cocawine |
| Sake |  10u. rice |  5u. enzyme | none | 5 | sake |
| Gin and Tonic |  2u. gin 1u. tonic | none | none | 3 | gintonic |
| Classic Martini |  2u. gin 1u. vermouth | none | none | 3 | martini |
| Vodka Martini |  2u. vodka 1u. vermouth | none | none | 3 | vodkamartini |
| White Russian |  2u. blackrussian 1u. cream | none | none | 3 | whiterussian |
| Screwdriver |  2u. vodka 1u. orangejuice | none | none | 3 | screwdrivercocktail |
| Bloody Mary |  2u. vodka 3u. tomatojuice 1u. limejuice | none | none | 6 | bloodymary |
| Tequilla Sunrise |  2u. tequilla 1u. orangejuice | none | none | 3 | tequillasunrise |
| Irish Cream |  2u. whiskey 1u. cream | none | none | 3 | irishcream |
| The Manly Dorf |  1u. beer 2u. ale | none | none | 3 | manlydorf |
| Irish Coffee |  1u. irishcream 1u. coffee | none | none | 2 | irishcoffee |
| Margarita |  2u. tequilla 1u. limejuice | none | none | 3 | margarita |
| Red Mead |  1u. blood 1u. mead | none | none | 2 | red_mead |
| Garum |  1u. sodiumchloride 2u. fish |  5u. enzyme | none | 2 | garum |
| Mead must |  1u. honey 1u. water | none | none | 2 | honey_must |
| Iced Beer |  5u. beer 1u. ice | none | none | 6 | iced_beer |
| Cafe Latte |  1u. coffee 1u. milk | none | none | 2 | cafe_latte |
| Andalusia |  1u. rum 1u. whiskey 1u. lemonjuice | none | none | 3 | andalusia |
| Snow White |  1u. beer 1u. lemon_lime | none | none | 2 | snowwhite |
| Syndicate Bomb |  1u. beer 1u. whiskeycola | none | none | 2 | syndicatebomb |
| Driest Martini |  1u. nothing 1u. gin | none | none | 2 | driestmartini |
| Lemonade |  1u. lemonjuice 1u. sugar 1u. water | none | none | 3 | lemonade |
| Kira Special |  1u. orangejuice 1u. limejuice 1u. sodawater | none | none | 3 | kiraspecial |
| Milkshake |  1u. cream 2u. ice 2u. milk | none | none | 5 | milkshake |
| Luminol |  2u. hydrogen 2u. carbon 2u. ammonia | none | none | 6 | luminol |
| rum |  3u. sugar 1u. water |  5u. enzyme | none | 1 | rum |
| gin |  3u. sugar 1u. juniper_juice |  5u. enzyme | none | 1 | gin |
| beer |  2u. barleyflour 2u. water 1u. hops |  5u. enzyme | none | 2 | beer |
| mezcal |  5u. agave 2u. water |  5u. enzyme | none | 2 | mezcal |
| wheat beer |  2u. flour 2u. water |  5u. enzyme | none | 2 | wheatbeer |
| ale |  2u. barleyflour 2u. water |  5u. enzyme | none | 2 | ale |
| Lard Soap |  20u. lard 2u. lye | none | none | 1 | lard_soap |
