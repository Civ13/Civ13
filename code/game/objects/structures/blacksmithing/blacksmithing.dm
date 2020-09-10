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
	
	///*Shields & Tools*///
	"Athenian Aspis Shield" = list("Athenian Aspis Shield","shield",1,1,0,13,0,0,/obj/item/weapon/shield/nomads/aspis),
	"Spartan Aspis Shield" = list("Spartan Aspis Shield","shield",1,1,0,13,0,0,/obj/item/weapon/shield/nomads/spartan),
	"Pegasus Aspis Shield" = list("Pegasus Aspis Shield","shield",1,1,0,13,0,0,/obj/item/weapon/shield/nomads/aspis/pegasus),
	"Owl Aspis Shield" = list("Owl Aspis Shield","shield",1,1,0,13,0,0,/obj/item/weapon/shield/nomads/aspis/owl),
	"Egyptian Shield" = list("Egyptian Shield","shield",1,1,0,13,0,0,/obj/item/weapon/shield/egyptian),
	"Scutum Shield" = list("Scutum Shield","shield",1,1,0,14,0,0,/obj/item/weapon/shield/scutum),
	"Roman Shield" = list("Roman Shield","shield",1,1,0,14,0,0,/obj/item/weapon/shield/roman),
	"Blue Roman Shield" = list("Blue Roman Shield","shield",1,1,0,14,0,0,/obj/item/weapon/shield/roman/blue),
	"Praetorian Roman Shield" = list("Praetorian Roman Shield","shield",1,2,0,16,0,0,/obj/item/weapon/shield/roman/praetorian),
	"Semi Oval Shield" = list("Semi Oval Shield","shield",2,2,0,16,0,0,/obj/item/weapon/shield/iron/nomads/semioval),
	"Semi Oval Templar Shield" = list("Semi Oval Templar Shield","shield",2,2,0,16,0,0,/obj/item/weapon/shield/iron/nomads/semioval/templar),
	"Orkish Shield" = list("Orkish Shield","shield",1,2,0,16,0,0,/obj/item/weapon/shield/iron/orc),

	///*Muskets*///
	"Crude Musket" = list("Crude Musket","guns",3,4,0,15,0,0,/obj/item/weapon/gun/projectile/flintlock/crude),
	"Flintlock Musket" = list("Flintlock Musket","guns",3,4,0,30,0,0,/obj/item/weapon/gun/projectile/flintlock/musket),
	"Flintlock Musketoon" = list("Flintlock Musketoon","guns",3,4,0,25,0,0,/obj/item/weapon/gun/projectile/flintlock/musketoon),
	"Flintlock Blunderbuss" = list("Flintlock Blunderbuss","guns",3,4,0,25,0,0,/obj/item/weapon/gun/projectile/flintlock/blunderbuss),
	"Flintlock Pistol" = list("Flintlock Pistol","guns",3,4,0,20,0,0,/obj/item/weapon/gun/projectile/flintlock/pistol),
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
