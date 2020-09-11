var/global/list/anvil_recipes = list(
	//name = list(name, category, first age, last age, steel cost, iron cost, bronze cost, kevlar cost, result)
	///*Industrial guns and stuff*///
	"Derringer M95 Pistol" = list("Derringer M95 Pistol","guns",4,5,15,0,0,0,/obj/item/weapon/gun/projectile/revolver/derringer),
	"Colt Peacemaker Revolver" = list("Colt Peacemaker Revolver","guns",4,5,25,0,0,0,/obj/item/weapon/gun/projectile/revolver/peacemaker),
	"Martini-Henry Rifle" = list("Martini-Henry Rifle","guns",4,5,35,0,0,0,/obj/item/weapon/gun/projectile/boltaction/singleshot/martini_henry),
	"Winchester Repeater" = list("Winchester Repeater","guns",4,5,50,0,0,0,/obj/item/weapon/gun/projectile/leveraction/winchester),
	"Evans Repeater" = list("Evans Repeater","guns",4,5,60,0,0,0,/obj/item/weapon/gun/projectile/leveraction/evansrepeater),
	"Henry Repeater" = list("Henry Repeater","guns",4,5,55,0,0,0,/obj/item/weapon/gun/projectile/leveraction/henryrepeater),
	"Sharps Rifle" = list("Sharps Rifle","guns",4,5,30,0,0,0,/obj/item/weapon/gun/projectile/boltaction/singleshot),
	"Coach Gun" = list("Coach Gun","guns",4,6,22,0,0,0,/obj/item/weapon/gun/projectile/shotgun/coachgun),
	"Gewehr 71" = list("Gewehr 71","guns",4,6,30,0,0,0,/obj/item/weapon/gun/projectile/boltaction/gewehr71),
	"Makeshift AK-47" = list("Makeshift AK-47","guns",7,8,32,0,0,0,new/obj/item/weapon/gun/projectile/submachinegun/makeshiftak47),

	///*Melee*///
		/*Swords*/
	"Gladius" = list("Gladius","swords",1,1,0,10,0,0,/obj/item/weapon/material/sword/gladius),
	"Xiphos" = list("Xiphos","swords",1,1,0,14,0,0,/obj/item/weapon/material/sword/xiphos),
	"Wakazashi" = list("Wakazashi","swords",2,5,10,0,0,0,/obj/item/weapon/material/sword/wakazashi),
	"Small Sword" = list("Small Sword","swords",2,3,10,10,0,0,/obj/item/weapon/material/sword/smallsword),
	"Longquan" = list("Longquan","swords",2,3,12,12,0,0,/obj/item/weapon/material/sword/longquan),
	"Scimitar" = list("Scimitar","swords",2,4,12,12,0,0,/obj/item/weapon/material/sword/scimitar), //steel
	"Scimitar" = list("Scimitar","swords",2,3,0,12,0,0,/obj/item/weapon/material/sword/scimitar), //iron, aged seperately
	"Arming Sword " = list("Arming Sword ","swords",2,2,15,15,0,0,/obj/item/weapon/material/sword/armingsword),
	"Saif" = list("Saif","swords",2,3,15,0,0,0,/obj/item/weapon/material/sword/saif), //steel
	"Saif" = list("Saif","swords",2,3,0,15,0,0,/obj/item/weapon/material/sword/saif), //iron
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
	"Tanto" = list("Tanto","knives",2,5,5,5,0,0,/obj/item/weapon/material/knife/tanto),
	"Bowie Knife" = list("Bowie Knife","knives",4,6,8,8,0,0,/obj/item/weapon/material/kitchen/utensil/knife/bowie),
	"Bowie Knife" = list("Bowie Knife","knives",7,8,12,12,0,0,/obj/item/weapon/material/kitchen/utensil/knife/bowie), //price inflated +4 out of era
	"Trench Knife" = list("Trench Knife","knives",5,6,10,10,0,0,/obj/item/weapon/material/kitchen/utensil/knife/trench),
	"Trench Knife" = list("Trench Knife","knives",7,8,14,14,0,0,/obj/item/weapon/material/kitchen/utensil/knife/trench), //price inflated +4 out of era
	"Military Knife" = list("Military Knife","knives",5,7,14,14,0,0,/obj/item/weapon/material/kitchen/utensil/knife/military),
	"Military Knife" = list("Military Knife","knives",8,8,18,14,0,0,/obj/item/weapon/material/kitchen/utensil/knife/military), //price inflated +4 out of era
	"Ceremonial Tanto" = list("Ceremonial Tanto","knives",6,8,10,10,0,0,/obj/item/weapon/material/knife/tanto), //applied double cost or required 'ceremonial' subtype.

	"Bolo Machete" = list("Bolo Machete","machetes",4,5,12,12,0,0,/obj/item/weapon/material/sword/bolo),
	"Bolo Machete" = list("Bolo Machete","machetes",6,8,16,16,0,0,/obj/item/weapon/material/sword/bolo), //price inflated +4 out of era
	"Kukri Machete" = list("Kukri Machete","machetes",4,5,12,12,0,0,/obj/item/weapon/material/sword/kukri),
	"Kukri Machete" = list("Kukri Machete","machetes",6,8,16,16,0,0,/obj/item/weapon/material/sword/kukri), //price inflated +4 out of era

	"Halberd" = list("Halberd","other weapons",2,3,14,10,0,0,/obj/item/weapon/material/halberd),
	"Pike" = list("Pike","other weapons",2,2,14,12,0,0,/obj/item/weapon/material/pike),
	"Boarding Axe" = list("Boarding Axe","other weapons",3,3,8,0,0,0,/obj/item/weapon/material/boarding_axe),
	"Naginata" = list("Naginata","other weapons",2,3,16,14,0,0,/obj/item/weapon/material/naginata),

		/*Orc Weapons*/

	"Uruk-Hai Scimitar" = list("Uruk-Hai Scimitar","orkish weapons",2,2,0,16,0,0,/obj/item/weapon/material/sword/urukhaiscimitar), // needs orc code.

	///*Shields & Tools*///
	"Athenian Aspis Shield" = list("Athenian Aspis Shield","shield",1,1,0,0,13,0,/obj/item/weapon/shield/nomads/aspis), //this paragraph changed from iron to bronze
	"Spartan Aspis Shield" = list("Spartan Aspis Shield","shield",1,1,0,0,13,0,/obj/item/weapon/shield/nomads/spartan),
	"Pegasus Aspis Shield" = list("Pegasus Aspis Shield","shield",1,1,0,0,13,0,/obj/item/weapon/shield/nomads/aspis/pegasus),
	"Owl Aspis Shield" = list("Owl Aspis Shield","shield",1,1,0,0,13,0,/obj/item/weapon/shield/nomads/aspis/owl),
	"Egyptian Shield" = list("Egyptian Shield","shield",1,1,0,0,13,0,/obj/item/weapon/shield/egyptian), //

	"Scutum Shield" = list("Scutum Shield","shield",1,1,0,14,0,0,/obj/item/weapon/shield/scutum),
	"Roman Shield" = list("Roman Shield","shield",1,1,0,14,0,0,/obj/item/weapon/shield/roman),
	"Blue Roman Shield" = list("Blue Roman Shield","shield",1,1,0,14,0,0,/obj/item/weapon/shield/roman/blue),
	"Praetorian Roman Shield" = list("Praetorian Roman Shield","shield",1,2,0,16,0,0,/obj/item/weapon/shield/roman/praetorian),
	"Semi Oval Shield" = list("Semi Oval Shield","shield",2,2,0,16,0,0,/obj/item/weapon/shield/iron/nomads/semioval),
	"Semi Oval Templar Shield" = list("Semi Oval Templar Shield","shield",2,2,0,16,0,0,/obj/item/weapon/shield/iron/nomads/semioval/templar),

		/*Orc Shields*/

	"Orkish Shield" = list("Orkish Shield","orkish shields",1,2,0,16,0,0,/obj/item/weapon/shield/iron/orc),

	///*Muskets*///
	"Crude Musket" = list("Crude Musket","guns",3,4,0,15,0,0,/obj/item/weapon/gun/projectile/flintlock/crude),
	"Flintlock Musket" = list("Flintlock Musket","guns",3,4,0,30,0,0,/obj/item/weapon/gun/projectile/flintlock/musket),
	"Flintlock Musketoon" = list("Flintlock Musketoon","guns",3,4,0,25,0,0,/obj/item/weapon/gun/projectile/flintlock/musketoon),
	"Flintlock Blunderbuss" = list("Flintlock Blunderbuss","guns",3,4,0,25,0,0,/obj/item/weapon/gun/projectile/flintlock/blunderbuss),
	"Flintlock Pistol" = list("Flintlock Pistol","guns",3,4,0,20,0,0,/obj/item/weapon/gun/projectile/flintlock/pistol),

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

	"Morion Helmet" = list("Morion Helmet","helmets",3,3,0,10,0,0,/obj/item/clothing/head/helmet/medieval/helmet1),

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

	"Samurai Helmet" = list("Samurai Helmet","japanese helmets",2,3,0,15,0,0,/obj/item/clothing/head/helmet/samurai/guard),
	"Red Samurai Helmet" = list("Red Samurai Helmet","japanese helmets",2,3,0,15,0,0,/obj/item/clothing/head/helmet/samurai/guard/red),
	"Blue Samurai Helmet" = list("Blue Samurai Helmet","japanese helmets",2,3,0,15,0,0,/obj/item/clothing/head/helmet/samurai/guard/blue),
	"Black Samurai Helmet" = list("Black Samurai Helmet","japanese helmets",2,3,0,15,0,0,/obj/item/clothing/head/helmet/samurai/guard/black),

	"Samurai Mask" = list("Samurai Mask","japanese headwear",2,3,0,8,0,0,/obj/item/clothing/head/helmet/samurai/guard),
	"Red Samurai Mask" = list("Samurai Mask","japanese headwear",2,3,0,8,0,0,/obj/item/clothing/head/helmet/samurai/guard/red),
	"Blue Samurai Mask" = list("Samurai Mask","japanese headwear",2,3,0,8,0,0,/obj/item/clothing/head/helmet/samurai/guard/blue),

				/*Orkish Helmets & Headwear*/
	"Horned Helmet" = list("Horned Helmet","orkish headwear",2,2,0,10,0,0,/obj/item/clothing/head/helmet/horned),
	"Boss Jaw" = list("Boss Jaw","orkish headwear",2,2,0,7,0,0,/obj/item/clothing/mask/bossjaw),

	"Grunt Helmet" = list("Grunt Helmet","orkish helmets",2,2,0,10,0,0,/obj/item/clothing/head/helmet/orc_grunt),
	"Spearman Helmet" = list("Spearman Helmet","orkish helmets",2,2,0,12,0,0,/obj/item/clothing/head/helmet/orc_spearman),
	"Beserker Helmet" = list("Beserker Helmet","orkish helmets",2,2,0,15,0,0,/obj/item/clothing/head/helmet/orc_beserker),

				/*Early Modern Iron Helmets*/
	"Pickelhaube" = list("Pickelhaube","helmets",4,4,0,7,0,0,/obj/item/clothing/head/helmet/modern/pickelhaube),
	"Pith Helmet" = list("Pith Helmet","helmets",4,4,0,7,0,0,/obj/item/clothing/head/helmet/modern/pith),

				/*Modern Iron Helmets*/
	"Scrap Helmet" = list("Scrap Helmet","helmets",4,4,0,15,0,0,/obj/item/clothing/head/helmet/scrap),

)
/obj/structure/anvil
	name = "iron anvil"
	desc = "A heavy iron anvil. The blacksmith's main work tool. It has 0 hot iron bars on it."
	icon = 'icons/obj/metallurgy.dmi'
	icon_state = "iron_anvil"
	density = TRUE
	anchored = TRUE
	var/base_icon = "iron"
	not_movable = FALSE
	not_disassemblable = TRUE

obj/structure/anvil/New()
	..()
	desc = "A heavy iron anvil. The blacksmith's main work tool."

/obj/structure/anvil/attackby(obj/item/P as obj, mob/user as mob)
	var/mob/living/human/H = user
	if (istype(P,/obj/item/weapon/wrench))
		playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
		user << (anchored ? "<span class='notice'r>You unfasten \the [src] from the floor.</span>" : "<span class='notice'>You secure \the [src] to the floor.</span>")
		anchored = !anchored
	if (H.getStatCoeff("crafting") < 1.7)
		user << "You don't have the skills to use this."
		return
	if (!map.civilizations && map.ID != MAP_TRIBES && (user.original_job_title != "Blacksmith" && user.original_job_title != "Pioneer Blacksmith" && user.original_job_title != "Town Blacksmith" && user.original_job_title != "Ferreiro" && user.original_job_title != "Ferrero" && user.original_job_title != "Grofsmid" && user.original_job_title != "Forgeron" && user.original_job_title != "British Blacksmith" && user.original_job_title != "Marooned Pirate Crew" && user.original_job_title != "Schmied"))
		user << "You don't have the skills to use this. Ask a blacksmith."
		return
	if (map.ID == MAP_TRIBES && (H.gorillaman || H.ant || H.wolfman || H.lizard || H.crab))
		user << "You don't know how to use this."
		return
	else
		if (istype(P, /obj/item/stack/ore/iron_pig))
			user << "You begin smithing the pig iron..."
			icon_state = "[base_icon]_anvil_use"
			playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
			if (do_after(user,15*P.amount,src))
				user << "<span class='notice'>You smite the pig into steel.</span>"
				if (P && P.amount)
					var/amt = P.amount
					qdel(P)
					var/obj/item/stack/material/steel/I = new/obj/item/stack/material/steel(loc)
					I.amount = amt*0.8
		else if (istype(P, /obj/item/stack/ore/iron_sponge))
			user << "You begin smithing the sponge iron..."
			icon_state = "[base_icon]_anvil_use"
			playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
			if (do_after(user,15*P.amount,src))
				user << "<span class='notice'>You smite the sponge iron into wrought iron.</span>"
				if (P && P.amount)
					var/amt = P.amount
					qdel(P)
					var/obj/item/stack/material/iron/I = new/obj/item/stack/material/iron(loc)
					I.amount = amt

/obj/structure/anvil/steel
	name = "stone anvil"
	desc = "An advanced steel anvil. The blacksmith's main work tool."
	icon_state = "steel_anvil"
	base_icon = "steel"

/obj/structure/anvil/stone
	name = "stone anvil"
	desc = "A crude stone anvil. The blacksmith's main work tool."
	icon_state = "stone_anvil"
	base_icon = "stone"
