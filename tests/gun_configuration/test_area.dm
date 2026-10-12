// Opt-in disposable local area. Never included by production civ13.dme.
var/global/datum/gun_test_area/gun_test_area = new
/world/OpenPort(port)
	if(!world.params["visual"] && port != "none")
		return FALSE
	return ..()
/datum/gun_test_area
	var/ready = FALSE
	var/list/equipment = list()
	var/obj/structure/repair/gun/bench
	New()
		if(!world.params["visual"])
			world.OpenPort("none")
		if(config)
			config.webhook_can_fire = FALSE
			config.ToRban = FALSE
		spawn(200)
			prepare()
	proc/prepare()
		for(var/x in 18 to 34)
			for(var/y in 18 to 28)
				var/turf/T = locate(x,y,1)
				for(var/atom/movable/A in T)
					qdel(A)
				T = T.ChangeTurf(/turf/floor/plating, FALSE, FALSE)
		bench = new(locate(23,23,1))
		bench.set_light(8, 2, "#FFFFFF")
		var/list/types = list(/obj/item/weapon/gun/projectile/semiautomatic/svd, /obj/item/weapon/gun/projectile/submachinegun/m16/commando/m4mws, /obj/item/weapon/gun_mount, /obj/item/weapon/attachment/scope/adjustable/advanced/reddot, /obj/item/weapon/attachment/scope/adjustable/sniper_scope/pso1, /obj/item/weapon/attachment/silencer/rifle, /obj/item/weapon/attachment/silencer/pistol, /obj/item/weapon/attachment/bayonet, /obj/item/weapon/attachment/under/foregrip, /obj/item/weapon/screwdriver, /obj/item/weapon/gun_cleaning_kit, /obj/item/ammo_magazine/svd, /obj/item/ammo_magazine/m16)
		var/i = 0
		for(var/path in types)
			var/obj/item/I = new path(locate(20+i%7,25+round(i/7),1))
			equipment += I
			i++
		for(var/y in 20 to 25)
			var/obj/structure/barricade/B = new(locate(32,y,1))
			B.name = "local range backstop"
		ready = TRUE
		text2file(json_encode(list("commit"=world.params["tested_commit"],"byond"="[world.byond_version].[world.byond_build]","map"=map.ID,"area"="18,18 to 34,28,1","equipment"=equipment.len,"network_port"=world.port)),"test-area-ready.json")
		if(!world.params["visual"])
			del(world)

/client/verb/enter_gun_test_area()
	set category = "Local Verification"
	set name = "Enter gun test area"
	if(!gun_test_area.ready) return
	src << browse(null,"window=playersetup")
	var/mob/living/human/H = new(locate(23,22,1))
	H.name = "Local firearm tester"
	H.real_name = H.name
	mob = H
	H.see_in_dark = 8
	to_chat(H,"LOCAL disposable gun range. Native guns, parts, tools and bench. Commit [world.params["tested_commit"]]. SVD begins with native PSO-1: Field Strip it before fitting a rail. Unload guns before maintenance. No action waits or compatibility checks are replaced.")

/client/verb/test_area_condition()
	set category = "Local Verification"
	set name = "Set held test gun condition"
	var/mob/living/human/H = mob
	if(!istype(H) || !gun_test_area.ready) return
	var/obj/item/weapon/gun/G = H.get_active_hand()
	if(!istype(G) || !(G in gun_test_area.equipment)) return
	var/value = input(H,"Test setup only: condition percentage","Local fixture",60) as num|null
	if(isnull(value)) return
	G.health = G.maxhealth * clamp(value,1,100)/100
	to_chat(H,"Test setup assigned [value]% condition; native maintenance remains unchanged.")
