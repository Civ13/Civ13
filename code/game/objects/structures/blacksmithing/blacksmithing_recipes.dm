/* category list
guns

swords
machetes

other weapons
shield
helmets
sallet helmets
other helmets
armor
japanese armor
other armor

japanese helmets
mk1 brodie
m15 adrian
ussr heavy visored helmets
pasgt helmets
us lwt helmets
pasgt armor

orkish weapons
orkish shields
orkish headwear
orkish helmets
orkish armor

ABOUT DUPLICATE RECIPES: There is a number of duplicate recipes with the same name that weren't working properly
(they weren't appearing on the in-game crafting menu). These recipes have been disabled for now, but something still needs
to be done about them, either removing or renaming them, or incorporating duplicates into a single recipe entry.

@Fantastic Fwoosh - Recipies mentioned above by @Masqhir AKA:BlackTea have been fixed but ill leave the note up as a helpful pointer.
- Its worth mentioning that single recipies with multiple field entries of material are fine, but time jumps or seperate ones need
(Material) or (Timeperiod) in the recipie name; by recommendation like i've applied if no more appropriate title can be orchestrated.

*/
var/global/list/anvil_recipes = list(
	//name = list(name, category, first age, last age, steel cost, iron cost, bronze cost, kevlar cost, result)

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//|| Weapons ||///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///*Guns and stuff*///
		/*Muskets*/
	"Crude Musket" = list("Crude Musket","guns",3,4,0,15,0,0,/obj/item/weapon/gun/projectile/flintlock/crude),
	"Flintlock Musket" = list("Flintlock Musket","guns",3,4,0,30,0,0,/obj/item/weapon/gun/projectile/flintlock/musket),
	"Flintlock Musketoon" = list("Flintlock Musketoon","guns",3,4,0,25,0,0,/obj/item/weapon/gun/projectile/flintlock/musketoon),
	"Flintlock Blunderbuss" = list("Flintlock Blunderbuss","guns",3,4,0,25,0,0,/obj/item/weapon/gun/projectile/flintlock/blunderbuss),
	"Flintlock Pistol" = list("Flintlock Pistol","guns",3,4,0,20,0,0,/obj/item/weapon/gun/projectile/flintlock/pistol),

		/*Industrial*/
	"Derringer M95 Pistol" = list("Derringer M95 Pistol","guns",4,5,15,0,0,0,/obj/item/weapon/gun/projectile/revolver/derringer),
	"Colt Peacemaker Revolver" = list("Colt Peacemaker Revolver","guns",4,5,25,0,0,0,/obj/item/weapon/gun/projectile/revolver/peacemaker),
	"Martini-Henry Rifle" = list("Martini-Henry Rifle","guns",4,5,35,0,0,0,/obj/item/weapon/gun/projectile/boltaction/singleshot/martini_henry),
	"Winchester Repeater" = list("Winchester Repeater","guns",4,5,50,0,0,0,/obj/item/weapon/gun/projectile/leveraction/winchester),
	"Evans Repeater" = list("Evans Repeater","guns",4,5,60,0,0,0,/obj/item/weapon/gun/projectile/leveraction/evansrepeater),
	"Henry Repeater" = list("Henry Repeater","guns",4,5,55,0,0,0,/obj/item/weapon/gun/projectile/leveraction/henryrepeater),
	"Sharps Rifle" = list("Sharps Rifle","guns",4,5,30,0,0,0,/obj/item/weapon/gun/projectile/boltaction/singleshot),
	"Coach Gun" = list("Coach Gun","guns",4,6,22,0,0,0,/obj/item/weapon/gun/projectile/shotgun/coachgun),
	"Gewehr 71" = list("Gewehr 71","guns",4,6,30,0,0,0,/obj/item/weapon/gun/projectile/boltaction/gewehr71),

		/*Modern*/
	"RPG-7" = list("RPG-7","guns",7,8,40,0,0,0,/obj/item/weapon/gun/launcher/rocket/rpg7/makeshift),
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///*Melee*///
		/*Swords*/
	"Gaelic Shortsword" = list("Gaelic Shortsword","swords",1,1,0,10,10,0,/obj/item/weapon/material/sword/gaelic),
	"Gladius" = list("Gladius","swords",1,1,0,10,10,0,/obj/item/weapon/material/sword/gladius),
	"Khopesh" = list("Khopesh","swords",1,1,0,14,14,0,/obj/item/weapon/material/sword/khopesh),
	"Xiphos" = list("Xiphos","swords",1,1,0,14,14,0,/obj/item/weapon/material/sword/xiphos),
	"Wakazashi" = list("Wakazashi","swords",2,5,10,0,0,0,/obj/item/weapon/material/sword/wakazashi),
	"Small Sword" = list("Small Sword","swords",2,3,10,10,0,0,/obj/item/weapon/material/sword/smallsword),
	"Longquan" = list("Longquan","swords",2,3,12,12,0,0,/obj/item/weapon/material/sword/longquan),
	"(Steel) Scimitar" = list("(Steel) Scimitar","swords",2,4,12,0,0,0,/obj/item/weapon/material/sword/scimitar), //steel
	"(Iron) Scimitar" = list("(Iron) Scimitar","swords",2,3,0,12,0,0,/obj/item/weapon/material/sword/scimitar), //iron, aged seperately
	"Arming Sword " = list("Arming Sword ","swords",2,2,15,15,0,0,/obj/item/weapon/material/sword/armingsword),
	"Saif" = list("Saif","swords",2,3,15,15,0,0,/obj/item/weapon/material/sword/saif),
	"Katana" = list("Katana","swords",2,5,15,15,0,0,/obj/item/weapon/material/sword/katana),
	"Longsword" = list("Longsword","swords",2,2,18,18,0,0,/obj/item/weapon/material/sword/longsword),
	"Cutlass" = list("Cutlass","swords",3,3,12,12,0,0,/obj/item/weapon/material/sword/cutlass),
	"Spadroon" = list("Spadroon","swords",3,3,15,15,0,0,/obj/item/weapon/material/sword/spadroon),
	"Sabre" = list("Sabre","swords",3,4,15,15,0,0,/obj/item/weapon/material/sword/sabre),
	"Rapier" = list("Rapier","swords",3,5,18,18,0,0,/obj/item/weapon/material/sword/rapier),
	"Ceremonial Saif" = list("Ceremonial Saif","swords",4,8,20,20,0,0,/obj/item/weapon/material/sword/arabsword), //if it was a real reproduction it would be least x2 cost but +8
	"Ceremonial Scimitar" = list("Ceremonial Scimitar","swords",4,8,23,23,0,0,/obj/item/weapon/material/sword/arabsword2), //if it was a real reproduction it would be least x2 cost but +8
	"Ceremonial Wakazashi" = list("Ceremonial Wakazashi","swords",6,8,10,0,0,0,/obj/item/weapon/material/sword/wakazashi),
	"Ceremonial Katana" = list("Ceremonial Katana","swords",6,8,30,30,0,0,/obj/item/weapon/material/sword/katana), //applied double cost or required 'ceremonial' subtype.

		/*Other Weapons*/
	"Knife" = list("Knife","knives",0,8,1,1,1,0,/obj/item/weapon/material/kitchen/utensil/knife),
	"Throwing Knife" = list("Throwing Knife","knives",2,8,1.5,1.5,1.5,0,/obj/item/weapon/material/thrown/throwing_knife),
	"Tanto" = list("Tanto","knives",2,5,5,5,0,0,/obj/item/weapon/material/kitchen/utensil/knife/tanto),
	"Bowie Knife" = list("Bowie Knife","knives",4,6,8,8,0,0,/obj/item/weapon/material/kitchen/utensil/knife/bowie),
	"Reproduction Bowie Knife" = list("Reproduction Bowie Knife","knives",7,8,12,12,0,0,/obj/item/weapon/material/kitchen/utensil/knife/bowie), //price inflated +4 out of era
	"Trench Knife" = list("Trench Knife","knives",5,6,10,10,0,0,/obj/item/weapon/material/kitchen/utensil/knife/trench),
	"Reproduction Trench Knife" = list("Reproduction Trench Knife","knives",7,8,14,14,0,0,/obj/item/weapon/material/kitchen/utensil/knife/trench), //price inflated +4 out of era
	"Military Knife" = list("Military Knife","knives",5,7,14,14,0,0,/obj/item/weapon/material/kitchen/utensil/knife/military),
	"Reproduction Military Knife" = list("Reproduction Military Knife","knives",8,8,18,14,0,0,/obj/item/weapon/material/kitchen/utensil/knife/military), //price inflated +4 out of era
	"Ceremonial Tanto" = list("Ceremonial Tanto","knives",6,8,10,10,0,0,/obj/item/weapon/material/kitchen/utensil/knife/tanto), //applied double cost or required 'ceremonial' subtype.
	"Razor Blade" = list("Razor Blade","knives",0,8,2,2,2,0,/obj/item/weapon/material/kitchen/utensil/knife/razorblade),
	"Circumcision Knife" = list("Circumcision Knife","knives",0,8,2,2,0,0,/obj/item/weapon/material/kitchen/utensil/knife/circumcision),
	"Butcher's Cleaver" = list("Butcher's Cleaver","knives",0,8,3,3,0,0,/obj/item/weapon/material/kitchen/utensil/knife/butcher),

	"Hatchet Head" = list("Hatchet Head","axes",0,8,3,3,3,0,/obj/item/weapon/material/part/axehead/hatchet),
	"Throwing Axe Head" = list("Throwing Axe Head","axes",0,8,3,3,3,0,/obj/item/weapon/material/part/axehead/throwing),
	"Battle Axe Head" = list("Battle Axe Head","axes",0,3,8,8,8,0,/obj/item/weapon/material/part/axehead/battleaxe),

	"Bolo Machete" = list("Bolo Machete","machetes",4,5,12,12,0,0,/obj/item/weapon/material/sword/bolo),
	"Reproduction Bolo Machete" = list("Reproduction Bolo Machete","machetes",6,8,16,16,0,0,/obj/item/weapon/material/sword/bolo), //price inflated +4 out of era
	"Kukri Machete" = list("Kukri Machete","machetes",4,5,12,12,0,0,/obj/item/weapon/material/sword/kukri),
	"Reproduction Kukri Machete" = list("Reproduction Kukri Machete","machetes",6,8,16,16,0,0,/obj/item/weapon/material/sword/kukri), //price inflated +4 out of era

	"Halberd" = list("Halberd","other weapons",2,3,14,10,0,0,/obj/item/weapon/material/spear/halberd),
	"Pike" = list("Pike","other weapons",2,2,14,12,0,0,/obj/item/weapon/material/spear/sarissa/pike),
	"Boarding Axe" = list("Boarding Axe","other weapons",3,3,8,0,0,0,/obj/item/weapon/material/boarding_axe),
	"Naginata" = list("Naginata","other weapons",2,3,16,14,0,0,/obj/item/weapon/material/naginata),

		/*Orc Weapons*/
	"Uruk-Hai Scimitar" = list("Uruk-Hai Scimitar","orkish weapons",2,2,0,16,0,0,/obj/item/weapon/material/sword/urukhaiscimitar), // needs orc code.

	///*Shields & Tools*///
	"Athenian Aspis Shield" = list("Athenian Aspis Shield","shields",1,1,0,0,13,0,/obj/item/weapon/shield/nomads/aspis), //this paragraph changed from iron to bronze
	"Spartan Aspis Shield" = list("Spartan Aspis Shield","shields",1,1,0,0,13,0,/obj/item/weapon/shield/nomads/spartan),
	"Pegasus Aspis Shield" = list("Pegasus Aspis Shield","shields",1,1,0,0,13,0,/obj/item/weapon/shield/nomads/aspis/pegasus),
	"Owl Aspis Shield" = list("Owl Aspis Shield","shields",1,1,0,0,13,0,/obj/item/weapon/shield/nomads/aspis/owl),
	"Egyptian Shield" = list("Egyptian Shield","shields",1,1,0,0,13,0,/obj/item/weapon/shield/egyptian), //

	"Scutum Shield" = list("Scutum Shield","shields",1,1,0,14,0,0,/obj/item/weapon/shield/scutum),
	"Roman Shield" = list("Roman Shield","shields",1,1,0,14,0,0,/obj/item/weapon/shield/roman),
	"Blue Roman Shield" = list("Blue Roman Shield","shields",1,1,0,14,0,0,/obj/item/weapon/shield/roman/blue),
	"Praetorian Roman Shield" = list("Praetorian Roman Shield","shields",1,2,0,16,0,0,/obj/item/weapon/shield/roman/praetorian),
	"Semi Oval Shield" = list("Semi Oval Shield","shields",2,2,0,16,0,0,/obj/item/weapon/shield/iron/nomads/semioval),
	"Semi Oval Templar Shield" = list("Semi Oval Templar Shield","shields",2,2,0,16,0,0,/obj/item/weapon/shield/iron/nomads/semioval/templar),

	"Bronze Shield" = list("Bronze Shield","shields",1,2,0,0,8,0,/obj/item/weapon/shield/bronze),
	"Iron Shield" = list("Iron Shield","shields",1,2,0,10,0,0,/obj/item/weapon/shield/iron),
	"Steel Shield" = list("Steel Shield","shields",2,2,10,0,0,0,/obj/item/weapon/shield/steel),
		/*Orc Shields*/
	"Orkish Shield" = list("Orkish Shield","orkish shields",1,2,0,16,0,0,/obj/item/weapon/shield/iron/orc),
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//|| Helmets ||///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///*Iron Helmets*///
			/*Classical*/
	"Roman Helmet" = list("Roman Helmet","helmets",1,1,0,10,0,0,/obj/item/clothing/head/helmet/roman/nomads),
	"Centurion Helmet" = list("Centurion Helmet","helmets",1,1,0,14,0,0,/obj/item/clothing/head/helmet/roman_centurion/nomads),
	"Decurion Helmet" = list("Decurion Helmet","helmets",1,1,0,14,0,0,/obj/item/clothing/head/helmet/roman_decurion/nomads),
	"Sol Invictus Helmet" = list("Sol Invictus Helmet","helmets",1,1,0,18,0,0,/obj/item/clothing/head/helmet/solinvictus),

	"Horned Helmet" = list("Horned Helmet","helmets",1,1,0,10,0,0,/obj/item/clothing/head/helmet/horned),
	"Winged Helmet" = list("Winged Helmet","helmets",1,1,0,10,0,0,/obj/item/clothing/head/helmet/asterix),
	"Conspicious Gaelic Helmet " = list("Conspicious Gaelic Helmet ","helmets",1,1,0,14,0,0,/obj/item/clothing/head/helmet/asterix/conspicious),

			/*Medieval to Imperial*/
				/*Standard (/) European Helmets*/
	"Kettle Helmet" = list("Kettle Helmet","helmets",2,2,0,8,0,0,/obj/item/clothing/head/helmet/medieval/helmet2),
	"Coif" = list("Coif","helmets",2,2,0,10,0,0,/obj/item/clothing/head/helmet/medieval/coif),
	"Coif & Helmet" = list("Coif & Helmet","helmets",2,2,0,15,0,0,/obj/item/clothing/head/helmet/medieval/coif_helmet),
	"Crusader Helmet" = list("Crusader Helmet","helmets",2,2,0,15,0,0,/obj/item/clothing/head/helmet/medieval/crusader),
	"Knight Helmet" = list("Knight Helmet","helmets",2,2,0,15,0,0,/obj/item/clothing/head/helmet/medieval),
	"Hounskull Bascinet" = list("Hounskull Bascinet","helmets",2,2,0,15,0,0,/obj/item/clothing/head/helmet/bascinet),

	"Conical Helmet" = list("Conical Helmet","helmets",2,3,0,6,0,0,/obj/item/clothing/head/helmet/medieval/helmet3),
	"Protective Conical Helmet" = list("Protective Conical Helmet","helmets",2,3,0,10,0,0,/obj/item/clothing/head/helmet/medieval/helmet1),

                 /*Imperial Helmets*/
	"Morion Helmet" = list("Morion Helmet","helmets",3,3,0,10,0,0,/obj/item/clothing/head/helmet/imperial/morion),
	"Cabasset Helmet" = list("Cabasset Helmet","helmets",3,3,0,8,0,0,/obj/item/clothing/head/helmet/imperial/cabasset),

				/*Sallet Helmets*/
	"Italian Sallet Helmet" = list("Italian Sallet Helmet","sallet helmets",2,2,0,12,0,0,/obj/item/clothing/head/helmet/sallet/italian),
	"German Sallet Helmet" = list("German Sallet Helmet","sallet helmets",2,2,0,12,0,0,/obj/item/clothing/head/helmet/sallet/german),
	"Burgundian Sallet Helmet" = list("Burgundian Sallet Helmet","sallet helmets",2,2,0,12,0,0,/obj/item/clothing/head/helmet/sallet/burg),

				/*Other Cultural Helmets*/
	"Viking Helmet" = list("Viking Helmet","other helmets",2,2,0,10,0,0,/obj/item/clothing/head/helmet/medieval/viking),
	"Valkyrie Helmet" = list("Valkyrie Helmet","other helmets",2,2,0,10,0,0,/obj/item/clothing/head/helmet/medieval/viking/valkyrie),
	"Varangian Helmet" = list("Varangian Helmet","other helmets",2,2,0,15,0,0,/obj/item/clothing/head/helmet/medieval/viking/varangian),

	"Mamluk Conical Helmet" = list("Mamluk Conical Helmet","other helmets",2,2,0,8,0,0,/obj/item/clothing/head/helmet/medieval/mamluk/helmet),
	"Mamluk Coif Helmet" = list("Mamluk Coif Helmet","other helmets",2,2,0,12,0,0,/obj/item/clothing/head/helmet/medieval/mamluk/coif),
	"Arabic Long Helmet" = list("Arabic Long Helmet","other helmets",2,2,0,15,0,0,/obj/item/clothing/head/helmet/medieval/nomads/longarab),

	"Imperial Chinese Helmet" = list("Imperial Chinese Helmet","other helmets",2,3,0,10,0,0,/obj/item/clothing/head/helmet/medieval/imperial_chinese),

				/*Japanese Helmets & Headwear*/
	"Samurai Helmet" = list("Samurai Helmet","japanese helmets",2,3,10,13,0,0,/obj/item/clothing/head/helmet/samurai),
	"Red Samurai Helmet" = list("Red Samurai Helmet","japanese helmets",2,3,10,13,0,0,/obj/item/clothing/head/helmet/samurai/red),
	"Blue Samurai Helmet" = list("Blue Samurai Helmet","japanese helmets",2,3,10,13,0,0,/obj/item/clothing/head/helmet/samurai/blue),
	"Black Samurai Helmet" = list("Black Samurai Helmet","japanese helmets",2,3,10,13,0,0,/obj/item/clothing/head/helmet/samurai/black),

	"(Iron) Samurai Lord Helmet" = list("(Iron) Samurai Lord Helmet","japanese helmets",2,2,0,15,0,0,/obj/item/clothing/head/helmet/samurai/lord/brown),                //* Iron Medieval Samurai Lord helms
	"(Iron) Red Samurai Lord Helmet" = list("(Iron) Red Samurai Lord Helmet","japanese helmets",2,2,0,15,0,0,/obj/item/clothing/head/helmet/samurai/lord/red),
	"(Iron) Blue Samurai Lord Helmet" = list("(Iron) Blue Samurai Lord Helmet","japanese helmets",2,2,0,15,0,0,/obj/item/clothing/head/helmet/samurai/lord/blue),
	"(Iron) Black Samurai Lord Helmet" = list("(Iron) Black Samurai Lord Helmet","japanese helmets",2,2,0,15,0,0,/obj/item/clothing/head/helmet/samurai/lord/black),

	"(Steel) Samurai Lord Helmet" = list("(Steel) Samurai Lord Helmet","japanese helmets",3,3,25,0,0,0,/obj/item/clothing/head/helmet/samurai/lord/brown),                //* Steel Imperial Samurai Lord Warrior helms
	"(Steel) Red Samurai Lord Helmet" = list("(Steel) Red Samurai Lord Helmet","japanese helmets",3,3,25,0,0,0,/obj/item/clothing/head/helmet/samurai/lord/red),
	"(Steel) Blue Samurai Lord Helmet" = list("(Steel) Blue Samurai Lord Helmet","japanese helmets",3,3,25,0,0,0,/obj/item/clothing/head/helmet/samurai/lord/blue),
	"(Steel) Black Samurai Lord Helmet" = list("(Steel) Black Samurai Lord Helmet","japanese helmets",3,3,25,0,0,0,/obj/item/clothing/head/helmet/samurai/lord/black),

	"Samurai Mask" = list("Samurai Mask","japanese headwear",2,3,4,8,0,0,/obj/item/clothing/mask/samurai),
	"Red Samurai Mask" = list("Red Samurai Mask","japanese headwear",2,3,4,8,0,0,/obj/item/clothing/mask/samurai/red),
	"Blue Samurai Mask" = list("Blue Samurai Mask","japanese headwear",2,3,4,8,0,0,/obj/item/clothing/mask/samurai/blue),

				/*Orkish Helmets & Headwear*/
	"Horned Helmet" = list("Horned Helmet","orkish headwear",2,2,0,10,0,0,/obj/item/clothing/head/helmet/horned),
	"Boss Jaw" = list("Boss Jaw","orkish headwear",2,2,0,7,0,0,/obj/item/clothing/mask/bossjaw),

	"Grunt Helmet" = list("Grunt Helmet","orkish helmets",2,2,0,10,0,0,/obj/item/clothing/head/helmet/orc_grunt),
	"Spearman Helmet" = list("Spearman Helmet","orkish helmets",2,2,0,12,0,0,/obj/item/clothing/head/helmet/orc_spearman),
	"Beserker Helmet" = list("Beserker Helmet","orkish helmets",2,2,0,15,0,0,/obj/item/clothing/head/helmet/orc_beserker),

				/*Early Modern Helmets*/
	"Pickelhaube" = list("Pickelhaube","helmets",4,5,6,7,0,0,/obj/item/clothing/head/helmet/modern/pickelhaube),
	"Pith Helmet" = list("Pith Helmet","helmets",4,5,0,7,0,0,/obj/item/clothing/head/helmet/modern/pith),

				/*Modern Iron Helmets*/
	"Scrap Helmet" = list("Scrap Helmet","helmets",4,5,0,15,0,0,/obj/item/clothing/head/helmet/scrap),

	///*Bronze Helmets*///
			/*Classical*/

	"Phrigian Helmet" = list("Phrigian Helmet","helmets",1,1,0,0,6,0,/obj/item/clothing/head/helmet/phrigian),

	"Gladiator Helmet" = list("Gladiator Helmet","helmets",1,1,0,0,10,0,/obj/item/clothing/head/helmet/gladiator/nomads),
	"Chinese Warrior Helmet" = list("Chinese Warrior Helmet","helmets",1,1,0,0,10,0,/obj/item/clothing/head/helmet/chinese_warrior),
	"Egyptian War Headdress" = list("Egyptian War Headdress","helmets",1,1,0,0,11,0,/obj/item/clothing/head/helmet/egyptian/nomads),

	"Greek Helmet" = list("Greek Helmet","helmets",1,1,0,0,10,0,/obj/item/clothing/head/helmet/greek/nomads),
	"Dimoerites Helmet" = list("Dimoerites Helmet","helmets",1,1,0,0,14,0,/obj/item/clothing/head/helmet/greek_sl/nomads),
	"Lochagos Helmet" = list("Lochagos Helmet","helmets",1,1,0,0,14,0,/obj/item/clothing/head/helmet/greek_commander/nomads),
	"Anax Helmet" = list("Anax Helmet","helmets",1,1,0,0,18,0,/obj/item/clothing/head/helmet/anax),

			/*Napoleonic*/
	"Dragoon Helmet" = list("Dragoon Helmet","helmets",3,3,0,0,10,0,/obj/item/clothing/head/helmet/napoleonic/dragoon),

	///*Steel Helmets*///
			/*World Wars*/
	"Mesh Pickelhaube Helmet" = list("Mesh Picklehaube Helmet","helmets",5,5,6,0,0,0,/obj/item/clothing/head/helmet/ww/pickelhaube2),

	"Stahlhelm Helmet" = list("Stahlhelm Helmet","helmets",5,6,9,0,0,0,/obj/item/clothing/head/helmet/modern/stahlhelm),

	"Soviet Helmet" = list("Soviet Helmet","helmets",6,6,9,0,0,0,/obj/item/clothing/head/helmet/ww2/soviet),
	"M1 Helmet" = list("M1 Helmet","helmets",6,6,9,0,0,0,/obj/item/clothing/head/helmet/ww2/usm1),
	"Type 92 Helmet" = list("Type 92 Helmet","helmets",6,6,9,0,0,0,/obj/item/clothing/head/helmet/ww2/japhelm),
	"Mk2 Brodie Helmet" = list("Mk2 Brodie Helmet","helmets",6,6,9,0,0,0,/obj/item/clothing/head/helmet/ww/mk2brodieog),
	"M26 Adrian Helmet" = list("M26 Adrian Helmet","helmets",6,6,9,0,0,0,/obj/item/clothing/head/helmet/ww2/adrianm26),

				/*Brodie Helmets*/
	"Mk1 Brodie (Apple Green)" = list("Mk1 Brodie (Apple Green)","mk1 brodie",5,5,9,0,0,0,/obj/item/clothing/head/helmet/ww/mk1brodieag),
	"Mk1 Brodie (Duck Egg Blue)" = list("Mk1 Brodie (Duck Egg Blue)","mk1 brodie",5,5,9,0,0,0,/obj/item/clothing/head/helmet/ww/mk1brodiedeb),

				/*Adrian Helmets*/
	"Standard M15 Adrian" = list("Standard M15 Adrian","m15 adrian",5,5,9,0,0,0,/obj/item/clothing/head/helmet/ww/adrian),
	"Russian M15 Adrian" = list("Russian M15 Adrian","m15 adrian",5,5,9,0,0,0,/obj/item/clothing/head/helmet/ww/adriansoviet),
	"Greek M15 Adrian" = list("Greek M15 Adrian","m15 adrian",5,5,9,0,0,0,/obj/item/clothing/head/helmet/ww/adriangreek),

		/*Cold War to Modern Helmets*/
	"USSR SSh-68 Helmet" = list("USSR SSh-68 Helmet","helmets",7,7,10,0,0,0,/obj/item/clothing/head/helmet/modern/ssh_68),
	"Korean War US M1 Helmet" = list("Korean War US M1 Helmet","helmets",7,7,12,0,0,0,/obj/item/clothing/head/helmet/korean/usm1),
	"Russian ZSh-1 Helmet" = list("Russian ZSh-1 Helmet","helmets",7,7,12,0,0,0,/obj/item/clothing/head/helmet/modern/zsh1),

	"Modern US M1 Helmet" = list("Modern US M1 Helmet","helmets",8,8,12,0,0,0,/obj/item/clothing/head/helmet/modern/ushelmet),
	"Russian ZSh-2 helmet" = list("Russian ZSh-2 helmet","helmets",8,8,14,0,0,0,/obj/item/clothing/head/helmet/modern/a6b47),

				/*USSR Heavy Helmets*/
	"USSR MASKA1 Helmet" = list("USSR MASKA1 Helmet","ussr heavy visored helmets",7,7,15,0,0,0,/obj/item/clothing/head/helmet/modern/sovietfacehelmet/nomads),
	"USSR K6-3 Helmet" = list("USSR K6-3 Helmet","ussr heavy visored helmets",7,7,16,0,0,0,/obj/item/clothing/head/helmet/modern/sovietfacehelmet/welding/nomads),

	///*Kevlar Helmets*///
			/*Cold War*/
	"Kevlar Helmet" = list("Kevlar Helmet","helmets",7,8,0,0,0,10,/obj/item/clothing/head/helmet/kevlarhelmet),
	"SWAT Helmet" = list("SWAT Helmet","helmets",7,8,0,0,0,12,/obj/item/clothing/head/helmet/swat),

				/*PASGT Helmets*/
	"Standard PASGT Helmet" = list("Standard PASGT Helmet","pasgt helmets",7,8,0,0,0,10,/obj/item/clothing/head/helmet/modern/pasgt),
	"Desert PASGT Helmet" = list("Desert PASGT Helmet","pasgt helmets",7,8,0,0,0,10,/obj/item/clothing/head/helmet/modern/pasgt/desert),

			/*Modern*/
	"Tactical Helmet" = list("Tactical Helmet","helmets",7,8,0,0,0,14,/obj/item/clothing/head/helmet/tactical),

				/*US LWT Helmets*/
	"Standard US LWT Helmet" = list("Standard US LWT Helmet","us lwt helmets",8,8,0,0,0,12,/obj/item/clothing/head/helmet/modern/lwh),
	"Black US LWT Helmet" = list("Black US LWT Helmet","us lwt helmets",8,8,0,0,0,12,/obj/item/clothing/head/helmet/modern/lwh/black),
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//|| Armor ||///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///*Bronze Armor*///
			/*Classical*/
	"Egyptian Lamellar Armor" = list("Egyptian Lamellar Armor","armor",1,1,0,0,8,0,/obj/item/clothing/suit/armor/ancient/bronze_lamellar),
	"Chinese Lamellar Armor" = list("Chinese Lamellar Armor","armor",1,1,0,0,8,0,/obj/item/clothing/suit/armor/ancient/bronze_lamellar/chinese),
	"Scaled Armor" = list("Scaled Armor","armor",1,1,0,0,8,0,/obj/item/clothing/suit/armor/ancient/scaled),

	///*Iron Armor*///
			/*Classical*/
	"Early Chainmail" = list("Early Chainmail","armor",1,1,0,10,0,0,/obj/item/clothing/suit/armor/ancient/chainmail),
	"Segmented Armor" = list("Segmented Armor","armor",1,1,0,14,0,0,/obj/item/clothing/suit/armor/ancient/scale),

			/*Medieval*/
	"Chainmail" = list("Chainmail","armor",2,2,0,10,0,0,/obj/item/clothing/suit/armor/medieval/chainmail),
	"Iron Chestplate" = list("Iron Chestplate","armor",2,2,0,12,0,0,/obj/item/clothing/suit/armor/medieval/iron_chestplate),
	"Hauberk" = list("Hauberk","armor",2,2,0,12,0,0,/obj/item/clothing/suit/armor/medieval/hauberk),
	"Emirate Armor" = list("Emirate Armor","armor",2,2,0,14,0,0,/obj/item/clothing/suit/armor/medieval/emirate),
	"Plated Armor" = list("Plated Armor","armor",2,2,0,16,0,0,/obj/item/clothing/suit/armor/medieval),

				/*Armor Accessories*/
	"Gauntlets" = list("Gauntlets","armor",2,2,0,10,0,0,/obj/item/clothing/gloves/gauntlets),
	"Plated Boots" = list("Plated Boots","armor",2,2,0,10,0,0,/obj/item/clothing/shoes/medieval/knight),

				/*Orkish Armor*/
	"Grunt Armor" = list("Grunt Armor","orkish armor",2,2,0,10,0,0,/obj/item/clothing/suit/armor/ork_grunt),
	"Urukhai Armor" = list("Urukhai Armor","orkish armor",2,2,0,12,0,0,/obj/item/clothing/suit/armor/ork_urukhai),

	"Orkish Gauntlets" = list("Orkish Gauntlets","orkish armor",2,2,0,10,0,0,/obj/item/clothing/gloves/gauntlets/orc),
	"Orkish Sabatons" = list("Orkish Sabatons","orkish armor",2,2,0,10,0,0,/obj/item/clothing/shoes/orc),

				/*Other Cultural Armor*/
	"Varangian Lamellar Armor" = list("Varangian Lamellar Armor","other armor",2,2,0,12,0,0,/obj/item/clothing/suit/armor/medieval/varangian),
	"Imperial Chinese Armor" = list("Imperial Chinese Armor","other armor",2,3,0,13,0,0,/obj/item/clothing/suit/armor/medieval/imperial_chinese),

				/*Japanese Armor & Accessories*/

	"Metal Samurai Armor" = list("Metal Samurai Armor","japanese armor",2,3,11,14,0,0,/obj/item/clothing/suit/armor/samurai/warrior),
	"Red Metal Samurai Armor" = list("Red Metal Samurai Armor","japanese armor",2,3,11,14,0,0,/obj/item/clothing/suit/armor/samurai/warrior/red),
	"Blue Metal Samurai Armor" = list("Blue Metal Samurai Armor","japanese armor",2,3,11,14,0,0,/obj/item/clothing/suit/armor/samurai/warrior/blue),
	"Black Metal Samurai Armor" = list("Black Metal Samurai Armor","japanese armor",2,3,11,14,0,0,/obj/item/clothing/suit/armor/samurai/warrior/black),

	"(Iron) Metal Samurai Lord Armor" = list("(Iron) Metal Samurai Lord Armor","japanese armor",2,2,0,17,0,0,/obj/item/clothing/suit/armor/samurai/lord),                    //* Iron Medieval Samurai Lord armor
	"(Iron) Red Metal Samurai Lord Armor" = list("(Iron) Red Metal Samurai Lord Armor","japanese armor",2,2,0,17,0,0,/obj/item/clothing/suit/armor/samurai/lord/red),
	"(Iron) Blue Metal Samurai Lord Armor" = list("(Iron) Blue Metal Samurai Lord Armor","japanese armor",2,2,0,17,0,0,/obj/item/clothing/suit/armor/samurai/lord/blue),
	"(Iron) Black Metal Samurai Lord Armor" = list("(Iron) Black Metal Samurai Lord Armor","japanese armor",2,2,0,17,0,0,/obj/item/clothing/suit/armor/samurai/lord/black),

	"(Steel) Metal Samurai Lord Armor" = list("(Steel) Metal Samurai Lord Armor","japanese armor",3,3,23,0,0,0,/obj/item/clothing/suit/armor/samurai/lord),                         //* Steel Imperial Samurai Lord armor
	"(Steel) Red Metal Samurai Lord Armor" = list("(Steel) Red Metal Samurai Lord Armor","japanese armor",3,3,23,0,0,0,/obj/item/clothing/suit/armor/samurai/lord/red),
	"(Steel) Blue Metal Samurai Lord Armor" = list("(Steel) Blue Metal Samurai Lord Armor","japanese armor",3,3,23,0,0,0,/obj/item/clothing/suit/armor/samurai/lord/blue),
	"(Steel) Black Metal Samurai Lord Armor" = list("(Steel) Black Metal Samurai Lord Armor","japanese armor",3,3,23,0,0,0,/obj/item/clothing/suit/armor/samurai/lord/black),

	"Kote Bracer Gauntlets" = list("Kote Bracer Gauntlets","japanese armor",2,3,0,10,0,0,/obj/item/clothing/gloves/gauntlets/kote),
	"Tsuranuki Shinguard Boots" = list("Tsuranuki Shinguard Boots","japanese armor",2,3,0,10,0,0,/obj/item/clothing/shoes/tsuranuki),

			/*Imperial*/
	"Imperial Chestplate" = list("Imperial Chestplate","armor",3,3,0,14,0,0,/obj/item/clothing/suit/armor/imperial/imperial_chestplate),

			/*Modern Iron Armor*/
	"Scrap Armor" = list("Scrap Armor","armor",8,8,13,16,0,0,/obj/item/clothing/suit/armor/scrap),

	///*Steel Armor*///
			/*World Wars*/
	"Dayfield Body Armor" = list("Dayfield Body Armor","armor",5,5,10,0,0,0,/obj/item/clothing/accessory/armor/modern/british),
	"Breastplate Body Armor" = list("Breastplate Body Armor","armor",5,5,12,0,0,0,/obj/item/clothing/accessory/armor/modern/plate),

	///*Kevlar Armor*///
			/*Cold War*/
	"Police Bullet-Proof Vest" = list("Police Bullet-Proof Vest","armor",7,8,0,0,0,10,/obj/item/clothing/suit/police),
	"Standard Kevlar Vest" = list("Standard Kevlar Vest","armor",7,8,0,0,0,14,/obj/item/clothing/accessory/armor/nomads/kevlarblack),

				/*PASGT Armor*/
	"Standard PASGT Armor" = list("Standard PASGT Armor","pasgt armor",7,7,0,0,0,12,/obj/item/clothing/accessory/armor/coldwar/pasgt),
	"Khaki PASGT Armor" = list("Khaki PASGT Armor","pasgt armor",7,7,0,0,0,12,/obj/item/clothing/accessory/armor/coldwar/pasgt/khaki),

			/*Modern*/
	"SWAT Heavy Vest" = list("SWAT Heavy Vest","helmets",8,8,0,0,0,16,/obj/item/clothing/suit/swat),
	/*gulag*/
	"Guard Key" = list("Guard Key","keys",6,6,3,3,3,0,/obj/item/weapon/key/soviet/guard),
)
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
