//////////////////////////////////////////////////////////////////////////////////////////
//Yamasaki Industries > Japanese manufacturer of sports cars and motorcycles

//Yamasaki M125 - A 125cc motorcycle
//Yamasaki Shinobu 5000 - A fast sports car
//Yamasaki Kazoku - A mid-size family car

//////////////////////////////////////////////////////////////////////////////////////////
//Stallion Motors Company > American manufacturer of Trucks and full-size cars

//SMC Wyoming - A medium-sized jeep
//SMC HP800 - A pickup truck
//SMC Falcon - A full-size sedan
//SMC Falcon Interceptor - The police version of the SMC Falcon

//////////////////////////////////////////////////////////////////////////////////////////
//Ubermacht Motorwerke > German manufacturer of luxury cars and vans

//UM Erstenklasse - Large luxury sedan
//UM Volle - A transport van
//UM Volle KW - A large ambulance version of the Volle

//////////////////////////////////////////////////////////////////////////////////////////
//ASINO > Cheap, small italian cars

//ASINO Piccolino - Small 2 seat italian car
//ASINO Quattroporte - Simple 4 seater

//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
/obj/effects/premadevehicles
	name = "premade vehicle"
	icon = 'icons/obj/vehicles/vehicleeffects.dmi'
	icon_state = "3x3"
	var/custom_color = ""
	var/axis = /obj/structure/vehicleparts/axis/car
	var/doorcode = 0
	var/reg_number = "000"
	var/list/tocreate = list(

	"1,1" = list(),
	"1,2" = list(),
	"1,3" = list(),
	"1,4" = list(),
	"1,5" = list(),

	"2,1" = list(),
	"2,2" = list(),
	"2,3" = list(),
	"2,4" = list(),
	"2,5" = list(),

	"3,1" = list(),
	"3,2" = list(),
	"3,3" = list(),
	"3,4" = list(),
	"3,5" = list(),

	"4,1" = list(),
	"4,2" = list(),
	"4,3" = list(),
	"4,4" = list(),
	"4,5" = list(),

	"5,1" = list(),
	"5,2" = list(),
	"5,3" = list(),
	"5,4" = list(),
	"5,5" = list(),
	)

/obj/effects/premadevehicles/New()
	invisibility = 101
	..()
	var/vmaxx = 1
	var/vmaxy = 1
	spawn(10)
		for (var/ix=1,ix<=5,ix++)
			for(var/iy=1, iy<=5, iy++)
				if (tocreate["[ix],[iy]"] && islist(tocreate["[ix],[iy]"]) && tocreate["[ix],[iy]"].len)
					var/turf/T = get_turf(locate(src.x+ix,src.y+iy,src.z))
					if (T)
						for(var/pt in tocreate["[ix],[iy]"])
							new pt(T)
							if (iy > vmaxy)
								vmaxy = iy
							if (ix > vmaxx)
								vmaxx = ix
		var/obj/structure/vehicleparts/axis/tpt = new axis(get_turf(locate(x+vmaxx,y+1,z)))
		if (custom_color != "")
			tpt.color = custom_color
		if (doorcode != 0)
			tpt.doorcode = doorcode
		tpt.reg_number = reg_number
		tpt.dir = 2
		var/turf/autoassembler_loc = get_turf(locate(tpt.x-2,tpt.y+2,tpt.z))
		new/obj/effect/autoassembler(autoassembler_loc)
		spawn(5)
			if (map.ID == MAP_THE_ART_OF_THE_DEAL && istype(src, /obj/effects/premadevehicles/yamasaki/shinobu/police))
				var/rangeto = range(2,autoassembler_loc)
				for (var/obj/structure/vehicleparts/frame/car/shinobu/rcf/A in rangeto)
					A.override_color = "#FFFFFF"
				for (var/obj/structure/vehicleparts/frame/car/shinobu/lcf/B in rangeto)
					B.override_color = "#FFFFFF"
				for (var/obj/structure/vehicleparts/frame/car/shinobu/rbc/C in rangeto)
					C.override_color = "#FFFFFF"
				for (var/obj/structure/vehicleparts/frame/car/shinobu/lbc/D in rangeto)
					D.override_color = "#FFFFFF"
	spawn(100)
		if(src)
			qdel(src)
/obj/effects/premadevehicles/proc/new_number()
	var/tempnum = 0
	tempnum = "[pick(alphabet_uppercase)][pick(alphabet_uppercase)][pick(alphabet_uppercase)] [rand(0,9)][rand(0,9)][rand(0,9)]"
	if (tempnum in license_plate_numbers)
		new_number()
		return
	else
		reg_number = tempnum
		license_plate_numbers += tempnum
		return tempnum

//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//ASNO
/obj/effects/premadevehicles/asno/piccolino
	name = "ASNO Piccolino"
	icon_state = "3x3"
	custom_color = "#494949"
	axis = /obj/structure/vehicleparts/axis/car/piccolino
	tocreate = list(
	"1,1" = list(/obj/item/weapon/reagent_containers/glass/barrel/fueltank/smalltank/fueledgasoline, /obj/structure/vehicleparts/movement, /obj/structure/vehicleparts/frame/car/piccolino/rf),
	"2,1" = list(/obj/structure/vehicleparts/frame/car/piccolino/lf, /obj/structure/engine/internal/gasoline/ethanol/premade/piccolino, /obj/structure/vehicleparts/movement, /obj/structure/vehicleparts/license_plate/eu/centered/front),

	"1,2" = list(/obj/structure/bed/chair/carseat/right, /obj/structure/vehicleparts/frame/car/piccolino/rc),
	"2,2" = list(/obj/structure/bed/chair/drivers/car, /obj/structure/vehicleparts/frame/car/piccolino/lc),

	"1,3" = list(/obj/structure/table/carboot, /obj/structure/vehicleparts/frame/car/piccolino/rb, /obj/structure/vehicleparts/movement/reversed),
	"2,3" = list(/obj/structure/table/carboot, /obj/structure/vehicleparts/frame/car/piccolino/lb, /obj/structure/vehicleparts/movement/reversed, /obj/structure/vehicleparts/license_plate/eu/centered),
	)

/obj/effects/premadevehicles/asno/quattroporte
	name = "ASNO Quattroporte"
	icon_state = "3x3"
	custom_color = "#076007"
	axis = /obj/structure/vehicleparts/axis/car/quattroporte
	tocreate = list(
	"1,1" = list(/obj/item/weapon/reagent_containers/glass/barrel/fueltank/smalltank/fueledgasoline, /obj/structure/vehicleparts/movement, /obj/structure/vehicleparts/frame/car/quattroporte/rf),
	"2,1" = list(/obj/structure/vehicleparts/frame/car/quattroporte/lf, /obj/structure/engine/internal/gasoline/premade/quattroporte, /obj/structure/vehicleparts/movement, /obj/structure/vehicleparts/license_plate/eu/centered/front),

	"1,2" = list(/obj/structure/bed/chair/carseat/right, /obj/structure/vehicleparts/frame/car/quattroporte/rc),
	"2,2" = list(/obj/structure/bed/chair/drivers/car, /obj/structure/vehicleparts/frame/car/quattroporte/lc),

	"1,3" = list(/obj/structure/bed/chair/carseat/right, /obj/structure/vehicleparts/frame/car/quattroporte/rb, /obj/structure/vehicleparts/movement/reversed),
	"2,3" = list(/obj/structure/bed/chair/carseat/left, /obj/structure/vehicleparts/frame/car/quattroporte/lb, /obj/structure/vehicleparts/license_plate/eu/centered, /obj/structure/vehicleparts/movement/reversed),
	)
//Ubermacht
/obj/effects/premadevehicles/ubermacht/erstenklasse
	name = "Ubermacht Erstenklasse"
	icon_state = "4x4"
	custom_color = "#1b1f1b"
	axis = /obj/structure/vehicleparts/axis/car/erstenklasse
	tocreate = list(
	"1,1" = list(/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel, /obj/structure/vehicleparts/movement, /obj/structure/vehicleparts/frame/car/umek/rf),
	"2,1" = list(/obj/structure/vehicleparts/frame/car/umek/lf, /obj/structure/engine/internal/diesel/premade/erstenklasse, /obj/structure/vehicleparts/movement, /obj/structure/vehicleparts/license_plate/eu/centered/front),

	"1,2" = list(/obj/structure/vehicleparts/frame/car/umek/rfc, /obj/structure/bed/chair/carseat/right/lion),
	"2,2" = list(/obj/structure/vehicleparts/frame/car/umek/lfc, /obj/structure/bed/chair/drivers/car/lion),

	"1,3" = list(/obj/structure/vehicleparts/frame/car/umek/rbc, /obj/structure/bed/chair/carseat/right/lion),
	"2,3" = list(/obj/structure/vehicleparts/frame/car/umek/lbc, /obj/structure/bed/chair/carseat/left/lion),

	"1,4" = list(/obj/structure/vehicleparts/frame/car/umek/rb, /obj/structure/table/carboot, /obj/structure/vehicleparts/movement/reversed),
	"2,4" = list(/obj/structure/vehicleparts/frame/car/umek/lb, /obj/structure/table/carboot, /obj/structure/vehicleparts/movement/reversed),
	)

//SMC
//falcon
/obj/effects/premadevehicles/smc/falcon
	name = "SMC Falcon"
	icon_state = "4x4"
	custom_color = "#1b1f1b"
	axis = /obj/structure/vehicleparts/axis/car/falcon
	tocreate = list(
	"1,1" = list(/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueledgasoline, /obj/structure/vehicleparts/movement, /obj/structure/vehicleparts/frame/car/falcon/rf),
	"2,1" = list(/obj/structure/vehicleparts/frame/car/falcon/lf, /obj/structure/engine/internal/gasoline/premade/falcon, /obj/structure/vehicleparts/movement, /obj/structure/vehicleparts/license_plate/us/centered/front),

	"1,2" = list(/obj/structure/vehicleparts/frame/car/falcon/rfc, /obj/structure/bed/chair/carseat/right),
	"2,2" = list(/obj/structure/vehicleparts/frame/car/falcon/lfc, /obj/structure/bed/chair/drivers/car,),

	"1,3" = list(/obj/structure/vehicleparts/frame/car/falcon/rbc, /obj/structure/bed/chair/carseat/right),
	"2,3" = list(/obj/structure/vehicleparts/frame/car/falcon/lbc, /obj/structure/bed/chair/carseat/left),

	"1,4" = list(/obj/structure/vehicleparts/frame/car/falcon/rb, /obj/structure/table/carboot, /obj/structure/vehicleparts/movement/reversed),
	"2,4" = list(/obj/structure/vehicleparts/frame/car/falcon/lb, /obj/structure/table/carboot, /obj/structure/vehicleparts/movement/reversed, /obj/structure/vehicleparts/license_plate/us/centered),
	)

/obj/effects/premadevehicles/smc/falcon/unmarked
	name = "SMC Falcon"
	icon_state = "4x4"
	custom_color = "#13161c"
	axis = /obj/structure/vehicleparts/axis/car/falcon/police
	tocreate = list(
	"1,1" = list(/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueledgasoline, /obj/structure/vehicleparts/movement, /obj/structure/vehicleparts/frame/car/falcon/rf),
	"2,1" = list(/obj/structure/vehicleparts/frame/car/falcon/lf, /obj/structure/engine/internal/gasoline/premade/falcon, /obj/structure/vehicleparts/movement, /obj/structure/vehicleparts/license_plate/us/centered/front),

	"1,2" = list(/obj/structure/vehicleparts/frame/car/falcon/rfc, /obj/structure/bed/chair/carseat/right),
	"2,2" = list(/obj/structure/vehicleparts/frame/car/falcon/lfc, /obj/structure/bed/chair/drivers/car, /obj/structure/emergency_lights/police2),

	"1,3" = list(/obj/structure/vehicleparts/frame/car/falcon/rbc, /obj/structure/bed/chair/carseat/right),
	"2,3" = list(/obj/structure/vehicleparts/frame/car/falcon/lbc, /obj/structure/bed/chair/carseat/left),

	"1,4" = list(/obj/structure/vehicleparts/frame/car/falcon/rb, /obj/structure/table/carboot, /obj/structure/vehicleparts/movement/reversed),
	"2,4" = list(/obj/structure/vehicleparts/frame/car/falcon/lb, /obj/structure/table/carboot, /obj/structure/vehicleparts/movement/reversed, /obj/structure/vehicleparts/license_plate/us/centered),
	)

/obj/effects/premadevehicles/smc/wyoming
	name = "SMC Wyoming"
	icon_state = "4x4"
	custom_color = "#392f92"
	axis = /obj/structure/vehicleparts/axis/car/wyoming
	tocreate = list(
	"1,1" = list(/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel, /obj/structure/vehicleparts/movement, /obj/structure/vehicleparts/frame/car/wyoming/rf),
	"2,1" = list(/obj/structure/vehicleparts/frame/car/wyoming/lf, /obj/structure/engine/internal/diesel/premade/wyoming, /obj/structure/vehicleparts/movement, /obj/structure/vehicleparts/license_plate/us/centered/front),

	"1,2" = list(/obj/structure/vehicleparts/frame/car/wyoming/rfc, /obj/structure/bed/chair/carseat/right),
	"2,2" = list(/obj/structure/vehicleparts/frame/car/wyoming/lfc, /obj/structure/bed/chair/drivers/car),

	"1,3" = list(/obj/structure/vehicleparts/frame/car/wyoming/rbc),
	"2,3" = list(/obj/structure/vehicleparts/frame/car/wyoming/lbc),

	"1,4" = list(/obj/structure/vehicleparts/frame/car/wyoming/rb, /obj/structure/vehicleparts/movement/reversed),
	"2,4" = list(/obj/structure/vehicleparts/frame/car/wyoming/lb, /obj/structure/vehicleparts/movement/reversed, /obj/structure/vehicleparts/license_plate/us/centered),
	)
//Yamasaki
//Shinobu
/obj/effects/premadevehicles/yamasaki/shinobu
	name = "Yamasaki Shinobu 5000"
	icon_state = "4x4"
	custom_color = "#7F0000"
	axis = /obj/structure/vehicleparts/axis/car/shinobu
	tocreate = list(
	"1,1" = list(/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueledgasoline, /obj/structure/vehicleparts/movement, /obj/structure/vehicleparts/frame/car/shinobu/rf),
	"2,1" = list(/obj/structure/vehicleparts/frame/car/shinobu/lf, /obj/structure/engine/internal/gasoline/wankel/premade/shinobu, /obj/structure/vehicleparts/movement, /obj/structure/vehicleparts/license_plate/eu/centered/front),

	"1,2" = list(/obj/structure/vehicleparts/frame/car/shinobu/rcf, /obj/structure/bed/chair/carseat/right),
	"2,2" = list(/obj/structure/vehicleparts/frame/car/shinobu/lcf, /obj/structure/bed/chair/drivers/car,),

	"1,3" = list(/obj/structure/vehicleparts/frame/car/shinobu/rbc, /obj/structure/bed/chair/carseat/right),
	"2,3" = list(/obj/structure/vehicleparts/frame/car/shinobu/lbc, /obj/structure/bed/chair/carseat/left),

	"1,4" = list(/obj/structure/vehicleparts/frame/car/shinobu/rb, /obj/structure/table/carboot, /obj/structure/vehicleparts/movement/reversed),
	"2,4" = list(/obj/structure/vehicleparts/frame/car/shinobu/lb, /obj/structure/table/carboot, /obj/structure/vehicleparts/movement/reversed, /obj/structure/vehicleparts/license_plate/eu/centered),
	)
//Shinobu interceptor

/obj/effects/premadevehicles/yamasaki/shinobu/police
	name = "Yamasaki Police Interceptor Shinobu"
	icon_state = "4x4"
	custom_color = "#383838"
	axis = /obj/structure/vehicleparts/axis/car/shinobu/police
	tocreate = list(
	"1,1" = list(/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueledgasoline, /obj/structure/vehicleparts/movement, /obj/structure/vehicleparts/frame/car/shinobu/rf),
	"2,1" = list(/obj/structure/vehicleparts/frame/car/shinobu/lf, /obj/structure/engine/internal/gasoline/wankel/premade/shinobu, /obj/structure/vehicleparts/movement, /obj/structure/vehicleparts/license_plate/us/centered/front),

	"1,2" = list(/obj/structure/vehicleparts/frame/car/shinobu/rcf, /obj/structure/bed/chair/carseat/right/dark),
	"2,2" = list(/obj/structure/vehicleparts/frame/car/shinobu/lcf, /obj/structure/bed/chair/drivers/car/dark, /obj/structure/emergency_lights),

	"1,3" = list(/obj/structure/vehicleparts/frame/car/shinobu/rbc, /obj/structure/bed/chair/carseat/right/dark),
	"2,3" = list(/obj/structure/vehicleparts/frame/car/shinobu/lbc, /obj/structure/bed/chair/carseat/left/dark),

	"1,4" = list(/obj/structure/vehicleparts/frame/car/shinobu/rb, /obj/structure/table/carboot, /obj/structure/vehicleparts/movement/reversed, /obj/item/weapon/storage/toolbox/emergency),
	"2,4" = list(/obj/structure/vehicleparts/frame/car/shinobu/lb, /obj/structure/table/carboot, /obj/structure/vehicleparts/movement/reversed, /obj/structure/vehicleparts/license_plate/us/centered, /obj/item/weapon/trafficcone, /obj/item/weapon/trafficcone, /obj/item/weapon/trafficcone, /obj/item/weapon/reagent_containers/glass/barrel/jerrycan/gasoline),
	)
//Kazoku
/obj/effects/premadevehicles/yamasaki/kazoku
	name = "Yamasaki Kazoku"
	icon_state = "3x3"
	custom_color = "#3b3a3a"
	axis = /obj/structure/vehicleparts/axis/car/kazoku
	tocreate = list(
	"1,1" = list(/obj/item/weapon/reagent_containers/glass/barrel/fueltank/smalltank/fueledgasoline, /obj/structure/vehicleparts/movement, /obj/structure/vehicleparts/frame/car/kazoku/rf),
	"2,1" = list(/obj/structure/vehicleparts/frame/car/kazoku/lf, /obj/structure/engine/internal/gasoline/premade/kazoku, /obj/structure/vehicleparts/movement, /obj/structure/vehicleparts/license_plate/eu/centered/front),

	"1,2" = list(/obj/structure/bed/chair/carseat/right, /obj/structure/vehicleparts/frame/car/kazoku/rc),
	"2,2" = list(/obj/structure/bed/chair/drivers/car, /obj/structure/vehicleparts/frame/car/kazoku/lc),


	"1,3" = list(/obj/structure/bed/chair/carseat/right, /obj/structure/vehicleparts/frame/car/kazoku/rb, /obj/structure/vehicleparts/movement/reversed),
	"2,3" = list(/obj/structure/bed/chair/carseat/left, /obj/structure/vehicleparts/frame/car/kazoku/lb, /obj/structure/vehicleparts/license_plate/eu/centered, /obj/structure/vehicleparts/movement/reversed),
	)
//Kurogane Type 95
/obj/effects/premadevehicles/kurogane/type95
	name = "Kurogane type 95"
	icon_state = "3x3"
	custom_color = "#736953"
	axis = /obj/structure/vehicleparts/axis/car/type95
	tocreate = list(
	"1,1" = list(/obj/item/weapon/reagent_containers/glass/barrel/fueltank/smalltank/fueledgasoline, /obj/structure/vehicleparts/movement, /obj/structure/vehicleparts/frame/car/type95/rf),
	"2,1" = list(/obj/structure/vehicleparts/frame/car/type95/lf, /obj/structure/engine/internal/gasoline/premade/type95, /obj/structure/vehicleparts/movement),

	"1,2" = list(/obj/structure/bed/chair/drivers/car/type95, /obj/structure/vehicleparts/frame/car/type95/rc),
	"2,2" = list(/obj/structure/bed/chair/carseat/left/type95, /obj/structure/vehicleparts/frame/car/type95/lc),

	"1,3" = list(/obj/structure/bed/chair/carseat/right/type95, /obj/structure/vehicleparts/frame/car/type95/rb, /obj/structure/vehicleparts/movement/reversed),
	"2,3" = list(/obj/structure/bed/chair/carseat/left/type95, /obj/structure/vehicleparts/frame/car/type95/lb, /obj/structure/vehicleparts/movement/reversed),
	)
//Isuzu Type 94
//Kurogane Type 95
/obj/effects/premadevehicles/isuzu/type94
	name = "Isuzu Type 94"
	icon_state = "4x4"
	custom_color = "#736953"
	axis = /obj/structure/vehicleparts/axis/car/type94
	tocreate = list(
	"1,1" = list(/obj/item/weapon/reagent_containers/glass/barrel/fueltank/smalltank/fueledgasoline, /obj/structure/vehicleparts/movement, /obj/structure/vehicleparts/frame/car/type94/rf),
	"2,1" = list(/obj/structure/vehicleparts/frame/car/type94/lf, /obj/structure/engine/internal/gasoline/premade/type94, /obj/structure/vehicleparts/movement),

	"1,2" = list(/obj/structure/bed/chair/drivers/car/type94, /obj/structure/vehicleparts/frame/car/type94/rc),
	"2,2" = list(/obj/structure/bed/chair/carseat/left/type94, /obj/structure/vehicleparts/frame/car/type94/lc),

	"1,3" = list(/obj/structure/vehicleparts/frame/car/right),
	"2,3" = list(/obj/structure/vehicleparts/frame/car/left),

	"1,4" = list(/obj/structure/vehicleparts/frame/car/right),
	"2,4" = list(/obj/structure/vehicleparts/frame/car/left),

	"1,5" = list(/obj/structure/vehicleparts/frame/car/right, /obj/structure/vehicleparts/movement/reversed),
	"2,5" = list(/obj/structure/vehicleparts/frame/car/left, /obj/structure/vehicleparts/movement/reversed, /obj/structure/vehicleparts/license_plate/eu),
	)
///////////////////////////////////////////////CARS///////////////////////////////////////////////////////
/obj/effects/premadevehicles/car

//Dutch Jeep
/obj/effects/premadevehicles/car/mercedes
	name = "Mercedes-Benz G280"
	icon_state = "3x3"
	custom_color = "#45453b"
	axis = /obj/structure/vehicleparts/axis/car/mercedes
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/frame/car/rf/armored, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel, /obj/structure/vehicleparts/movement/armored),
	"2,1" = list(/obj/structure/vehicleparts/frame/car/lf/armored, /obj/structure/engine/internal/diesel/premade/v6, /obj/structure/vehicleparts/movement/armored/reversed, /obj/structure/vehicleparts/license_plate/nl/centered/front),

	"1,2" = list(/obj/structure/vehicleparts/frame/car/mercedes/rf, /obj/structure/bed/chair/office/dark),
	"2,2" = list(/obj/structure/vehicleparts/frame/car/mercedes/lf, /obj/structure/bed/chair/drivers),

	"1,3" = list(/obj/structure/vehicleparts/frame/car/rb/armored, /obj/structure/bed/chair/office/dark, /obj/structure/vehicleparts/movement/armored/reversed),
	"2,3" = list(/obj/structure/vehicleparts/frame/car/lb/armored, /obj/structure/bed/chair/office/dark, /obj/structure/vehicleparts/movement/armored/reversed, /obj/structure/vehicleparts/license_plate/nl/centered),
	)
/obj/effects/premadevehicles/car/mercedes/mg
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/frame/car/rf/armored, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel, /obj/structure/vehicleparts/movement/armored),
	"2,1" = list(/obj/structure/vehicleparts/frame/car/lf/armored, /obj/structure/engine/internal/diesel/premade/v6, /obj/structure/vehicleparts/movement/armored/reversed, /obj/structure/vehicleparts/license_plate/nl/centered/front),

	"1,2" = list(/obj/structure/vehicleparts/frame/car/mercedes/rf, /obj/structure/bed/chair/office/dark, /obj/item/weapon/gun/projectile/automatic/stationary/m2browning),
	"2,2" = list(/obj/structure/vehicleparts/frame/car/mercedes/lf, /obj/structure/bed/chair/drivers),

	"1,3" = list(/obj/structure/vehicleparts/frame/car/rb/armored, /obj/structure/bed/chair/office/dark, /obj/structure/vehicleparts/movement/armored/reversed, /obj/item/ammo_magazine/a50cal_can, /obj/item/ammo_magazine/a50cal_can, /obj/item/ammo_magazine/a50cal_can),
	"2,3" = list(/obj/structure/vehicleparts/frame/car/lb/armored, /obj/structure/bed/chair/office/dark, /obj/structure/vehicleparts/movement/armored/reversed, /obj/structure/vehicleparts/license_plate/nl/centered),
	)

//Russian Jeep
/obj/effects/premadevehicles/car/tigr
	name = "AMN-233114 Tigr-M"
	icon_state = "3x3"
	custom_color = "#45453b"
	axis = /obj/structure/vehicleparts/axis/car/tigr
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/frame/car/rf/armored, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel, /obj/structure/vehicleparts/movement/armored),
	"2,1" = list(/obj/structure/vehicleparts/frame/car/lf/armored, /obj/structure/engine/internal/diesel/premade/v6, /obj/structure/vehicleparts/movement/armored/reversed, /obj/structure/vehicleparts/license_plate/ru_mil/centered/front),

	"1,2" = list(/obj/structure/vehicleparts/frame/car/tigr/rf, /obj/structure/bed/chair/office/dark),
	"2,2" = list(/obj/structure/vehicleparts/frame/car/tigr/lf, /obj/structure/bed/chair/drivers),

	"1,3" = list(/obj/structure/vehicleparts/frame/car/tigr/rb, /obj/structure/bed/chair/office/dark, /obj/structure/vehicleparts/movement/armored/reversed),
	"2,3" = list(/obj/structure/vehicleparts/frame/car/tigr/lb, /obj/structure/bed/chair/office/dark, /obj/structure/vehicleparts/movement/armored/reversed, /obj/structure/vehicleparts/license_plate/ru_mil/centered),
	)
/obj/effects/premadevehicles/car/tigr/mg
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/frame/car/rf/armored, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel, /obj/structure/vehicleparts/movement/armored),
	"2,1" = list(/obj/structure/vehicleparts/frame/car/lf/armored, /obj/structure/engine/internal/diesel/premade/v6, /obj/structure/vehicleparts/movement/armored/reversed, /obj/structure/vehicleparts/license_plate/ru_mil/centered/front),

	"1,2" = list(/obj/structure/vehicleparts/frame/car/tigr/rf, /obj/structure/bed/chair/office/dark, /obj/item/weapon/gun/projectile/automatic/stationary/pkm),
	"2,2" = list(/obj/structure/vehicleparts/frame/car/tigr/lf, /obj/structure/bed/chair/drivers),

	"1,3" = list(/obj/structure/vehicleparts/frame/car/tigr/rb, /obj/structure/bed/chair/office/dark, /obj/structure/vehicleparts/movement/armored/reversed, /obj/item/ammo_magazine/pkm/c100, /obj/item/ammo_magazine/pkm/c100, /obj/item/ammo_magazine/pkm/c100),
	"2,3" = list(/obj/structure/vehicleparts/frame/car/tigr/lb, /obj/structure/bed/chair/office/dark, /obj/structure/vehicleparts/movement/armored/reversed, /obj/structure/vehicleparts/license_plate/ru_mil/centered),
	)

//Toyota
/obj/effects/premadevehicles/car/toyota
	name = "Toyota Hilux"
	icon_state = "5x5"
	custom_color = "#BDB76B"
	axis = /obj/structure/vehicleparts/axis/car/toyota
	tocreate = list(
		"1,1" = list(/obj/structure/vehicleparts/frame/car/toyota/rf, /obj/structure/vehicleparts/movement, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/smalltank/fueleddiesel),
		"2,1" = list(/obj/structure/vehicleparts/frame/car/toyota/lf, /obj/structure/vehicleparts/movement/reversed, /obj/structure/engine/internal/diesel/premade/v12),

		"1,2" = list(/obj/structure/vehicleparts/frame/car/toyota/rfc, /obj/structure/bed/chair/office/dark),
		"2,2" = list(/obj/structure/vehicleparts/frame/car/toyota/lfc, /obj/structure/bed/chair/drivers),

		"1,3" = list(/obj/structure/vehicleparts/frame/car/toyota/rfcc, /obj/structure/bed/chair/office/dark),
		"2,3" = list(/obj/structure/vehicleparts/frame/car/toyota/lfcc, /obj/structure/bed/chair/office/dark),

		"1,4" = list(/obj/structure/vehicleparts/frame/car/toyota/rb, /obj/structure/vehicleparts/movement, /obj/structure/turret/technical_dshk),
		"2,4" = list(/obj/structure/vehicleparts/frame/car/toyota/lb, /obj/structure/vehicleparts/movement/reversed, /obj/item/ammo_magazine/ammo127, /obj/item/ammo_magazine/ammo127, /obj/item/ammo_magazine/ammo127, /obj/item/ammo_magazine/ammo127),
	)

//Toyota armored
/obj/effects/premadevehicles/car/toyota/armored
	name = "Toyota Modificated"
	icon_state = "5x5"
	custom_color = "#BDB76B"
	axis = /obj/structure/vehicleparts/axis/car/toyota
	tocreate = list(
		"1,1" = list(/obj/structure/vehicleparts/frame/car/toyota_armored/rf, /obj/structure/vehicleparts/movement/armored, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/smalltank/fueleddiesel),
		"2,1" = list(/obj/structure/vehicleparts/frame/car/toyota_armored/lf, /obj/structure/vehicleparts/movement/armored/reversed, /obj/structure/engine/internal/diesel/premade/v12),

		"1,2" = list(/obj/structure/vehicleparts/frame/car/toyota_armored/rfc, /obj/structure/bed/chair/office/dark),
		"2,2" = list(/obj/structure/vehicleparts/frame/car/toyota_armored/lfc, /obj/structure/bed/chair/drivers),

		"1,3" = list(/obj/structure/vehicleparts/frame/car/toyota_armored/rfcc, /obj/structure/bed/chair/office/dark),
		"2,3" = list(/obj/structure/vehicleparts/frame/car/toyota_armored/lfcc, /obj/structure/bed/chair/office/dark),

		"1,4" = list(/obj/structure/vehicleparts/frame/car/toyota_armored/rb, /obj/structure/vehicleparts/movement/armored),
		"2,4" = list(/obj/structure/vehicleparts/frame/car/toyota_armored/lb, /obj/structure/vehicleparts/movement/armored/reversed),
	)

///////////////////////////////////////////////TRUCKS///////////////////////////////////////////////////////
/obj/effects/premadevehicles/truck

//Dutch Truck
/obj/effects/premadevehicles/truck/daf
	name = "DAF YA-4442 Truck"
	icon_state = "4x4"
	custom_color = "#45453b"
	axis = /obj/structure/vehicleparts/axis/car/daf
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/frame/car/rf/armored, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueledgasoline, /obj/structure/vehicleparts/movement),
	"2,1" = list(/obj/structure/vehicleparts/frame/car/lf/armored, /obj/structure/engine/internal/gasoline/premade/v6, /obj/structure/vehicleparts/movement, /obj/structure/vehicleparts/license_plate/nl/centered/front),

	"1,2" = list(/obj/structure/vehicleparts/frame/car/rf/truck/armored, /obj/structure/bed/chair/office/dark),
	"2,2" = list(/obj/structure/vehicleparts/frame/car/lf/truck/armored, /obj/structure/bed/chair/drivers),

	"1,3" = list(/obj/structure/vehicleparts/frame/car/right/armored, /obj/structure/supply_crate/faction1),
	"2,3" = list(/obj/structure/vehicleparts/frame/car/left/armored),

	"1,4" = list(/obj/structure/vehicleparts/frame/car/right/armored, /obj/structure/vehicleparts/movement/reversed),
	"2,4" = list(/obj/structure/vehicleparts/frame/car/left/armored, /obj/structure/vehicleparts/movement/reversed, /obj/structure/vehicleparts/license_plate/nl/centered),
	)

//Russian Truck
/obj/effects/premadevehicles/truck/kamaz
	name = "KamAZ-4350 Truck"
	icon_state = "4x4"
	custom_color = "#45453b"
	axis = /obj/structure/vehicleparts/axis/car/kamaz
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/frame/car/rf/armored, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueledgasoline, /obj/structure/vehicleparts/movement),
	"2,1" = list(/obj/structure/vehicleparts/frame/car/lf/armored, /obj/structure/engine/internal/gasoline/premade/v6, /obj/structure/vehicleparts/movement, /obj/structure/vehicleparts/license_plate/ru_mil/centered/front),

	"1,2" = list(/obj/structure/vehicleparts/frame/car/rf/truck/armored, /obj/structure/bed/chair/office/dark),
	"2,2" = list(/obj/structure/vehicleparts/frame/car/lf/truck/armored, /obj/structure/bed/chair/drivers),

	"1,3" = list(/obj/structure/vehicleparts/frame/car/right/armored, /obj/structure/supply_crate/faction2),
	"2,3" = list(/obj/structure/vehicleparts/frame/car/left/armored),

	"1,4" = list(/obj/structure/vehicleparts/frame/car/right/armored, /obj/structure/vehicleparts/movement/reversed),
	"2,4" = list(/obj/structure/vehicleparts/frame/car/left/armored, /obj/structure/vehicleparts/movement/reversed, /obj/structure/vehicleparts/license_plate/ru_mil/centered),
	)

///////////////////////////////////////////////SHIPS///////////////////////////////////////////////////////
/obj/effects/premadevehicles/ship

/obj/effects/premadevehicles/ship/lc13
	name = "landing craft"
	icon_state = "5x5"
	custom_color = null
	axis = /obj/structure/vehicleparts/axis/ship/heavy
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/frame/ship/steel/lc13/rf),
	"2,1" = list(/obj/structure/vehicleparts/frame/ship/steel/lc13/f),
	"3,1" = list(/obj/structure/vehicleparts/frame/ship/steel/lc13/lf),

	"1,2" = list(/obj/structure/vehicleparts/frame/ship/steel/lc13/rfc),
	"2,2" = list(/obj/structure/vehicleparts/frame/ship/steel/lc13/fc),
	"3,2" = list(/obj/structure/vehicleparts/frame/ship/steel/lc13/lfc),

	"1,3" = list(/obj/structure/vehicleparts/frame/ship/steel/lc13/rc),
	"2,3" = list(/obj/structure/vehicleparts/frame/ship/steel/lc13/c),
	"3,3" = list(/obj/structure/vehicleparts/frame/ship/steel/lc13/lc),

	"1,4" = list(/obj/structure/vehicleparts/frame/ship/steel/lc13/rbc),
	"2,4" = list(/obj/structure/vehicleparts/frame/ship/steel/lc13/bc, /obj/structure/vehicleparts/shipwheel),
	"3,4" = list(/obj/structure/vehicleparts/frame/ship/steel/lc13/lbc),

	"1,5" = list(/obj/structure/vehicleparts/frame/ship/steel/lc13/rb),
	"2,5" = list(/obj/structure/vehicleparts/frame/ship/steel/lc13/b, /obj/structure/engine/internal/diesel/premade/chiha, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel),
	"3,5" = list(/obj/structure/vehicleparts/frame/ship/steel/lc13/lb),
	)
///////////////////////////////////////////////TANKS///////////////////////////////////////////////////////
/obj/effects/premadevehicles/tank

/obj/effects/premadevehicles/tank/panzeriv
	name = "Panzer IV"
	icon_state = "4x4"
	custom_color = "#585A5C"
	axis = /obj/structure/vehicleparts/axis/heavy/panzeriv
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks, /obj/structure/vehicleparts/frame/panzeriv/rf, /obj/item/ammo_magazine/mg34belt, /obj/item/ammo_magazine/mg34belt, /obj/item/ammo_magazine/mg34belt, /obj/item/ammo_magazine/mg34belt, /obj/item/weapon/gun/projectile/automatic/stationary/mg34),
	"2,1" = list(/obj/structure/vehicleparts/frame/panzeriv/front, /obj/item/weapon/storage/toolbox/emergency),
	"3,1" = list(/obj/structure/vehicleparts/movement/tracks, /obj/structure/vehicleparts/frame/panzeriv/lf, /obj/structure/bed/chair/drivers/tank),

	"1,2" = list(/obj/structure/vehicleparts/frame/panzeriv/right, /obj/structure/shellrack/full75),
	"2,2" = list(/obj/structure/vehicleparts/frame/panzeriv, /obj/structure/turret/pziv),
	"3,2" = list(/obj/structure/vehicleparts/frame/panzeriv/left, /obj/structure/shellrack/full75),

	"1,3" = list(/obj/structure/vehicleparts/frame/panzeriv/right/door),
	"2,3" = list(/obj/structure/vehicleparts/frame/panzeriv),
	"3,3" = list(/obj/structure/vehicleparts/frame/panzeriv/left/door),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/reversed, /obj/structure/vehicleparts/frame/panzeriv/rb, /obj/structure/engine/internal/gasoline/premade/panzeriv),
	"2,4" = list(/obj/structure/vehicleparts/frame/panzeriv/back),
	"3,4" = list(/obj/structure/vehicleparts/movement/tracks/reversed, /obj/structure/vehicleparts/frame/panzeriv/lb, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueledgasoline),
	)

/obj/effects/premadevehicles/tank/panzervi
	name = "Panzer VI Tiger"
	icon_state = "4x4"
	custom_color = "#585A5C"
	axis = /obj/structure/vehicleparts/axis/heavy/panzervi
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks, /obj/structure/vehicleparts/frame/panzervi/rf, /obj/item/ammo_magazine/mg34belt, /obj/item/ammo_magazine/mg34belt, /obj/item/ammo_magazine/mg34belt, /obj/item/ammo_magazine/mg34belt, /obj/structure/bed/chair/mgunner/mg34),
	"2,1" = list(/obj/structure/vehicleparts/frame/panzervi/front, /obj/item/weapon/storage/toolbox/emergency),
	"3,1" = list(/obj/structure/vehicleparts/movement/tracks, /obj/structure/vehicleparts/frame/panzervi/lf, /obj/structure/bed/chair/drivers/tank),

	"1,2" = list(/obj/structure/vehicleparts/frame/panzervi/right, /obj/structure/shellrack/full88),
	"2,2" = list(/obj/structure/vehicleparts/frame/panzervi, /obj/structure/turret/pzvi),
	"3,2" = list(/obj/structure/vehicleparts/frame/panzervi/left, /obj/structure/shellrack/full88),

	"1,3" = list(/obj/structure/vehicleparts/frame/panzervi/right),
	"2,3" = list(/obj/structure/vehicleparts/frame/panzervi),
	"3,3" = list(/obj/structure/vehicleparts/frame/panzervi/left),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/reversed, /obj/structure/vehicleparts/frame/panzeriv/rb, /obj/structure/engine/internal/gasoline/premade/panzeriv),
	"2,4" = list(/obj/structure/vehicleparts/frame/panzervi/back/door),
	"3,4" = list(/obj/structure/vehicleparts/movement/tracks/reversed, /obj/structure/vehicleparts/frame/panzeriv/lb, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueledgasoline),
	)

/obj/effects/premadevehicles/tank/omw22_2
	name = "OMW-22 mk. II"
	icon_state = "4x4"
	custom_color = "#774D4C"
	axis = /obj/structure/vehicleparts/axis/heavy/omw22_2
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks/right, /obj/structure/vehicleparts/frame/omw22_2/rf, /obj/structure/lamp/lamp_small/tank/floodlight),
	"2,1" = list(/obj/structure/vehicleparts/frame/omw22_2/front, /obj/structure/bed/chair/drivers/tank,),
	"3,1" = list(/obj/structure/vehicleparts/movement/tracks/left, /obj/structure/vehicleparts/frame/omw22_2/lf, /obj/item/ammo_magazine/pkm, /obj/item/ammo_magazine/pkm, /obj/item/ammo_magazine/pkm, /obj/item/ammo_magazine/pkm, /obj/item/weapon/gun/projectile/automatic/stationary/pkm, /obj/structure/lamp/lamp_small/tank/floodlight),

	"1,2" = list(/obj/structure/vehicleparts/frame/omw22_2/right, /obj/structure/bed/chair/commander),
	"2,2" = list(/obj/structure/vehicleparts/frame/omw22_2, /obj/structure/cannon/modern/tank/omwtc10),
	"3,2" = list(/obj/structure/vehicleparts/frame/omw22_2/left, /obj/structure/bed/chair/loader),

	"1,3" = list(/obj/structure/vehicleparts/frame/omw22_2/right/door, /obj/item/weapon/storage/toolbox/emergency),
	"2,3" = list(/obj/structure/vehicleparts/frame/omw22_2, /obj/structure/bed/chair/gunner),
	"3,3" = list(/obj/structure/vehicleparts/frame/omw22_2/left, /obj/structure/shellrack/full100modern),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/left/reversed, /obj/structure/vehicleparts/frame/omw22_2/rb),
	"2,4" = list(/obj/structure/vehicleparts/frame/omw22_2/back, /obj/structure/engine/internal/diesel/premade/omw22_2, /obj/structure/lamp/lamp_small/tank/red),
	"3,4" = list(/obj/structure/vehicleparts/movement/tracks/right/reversed, /obj/structure/vehicleparts/frame/omw22_2/lb, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel),
	)

/obj/effects/premadevehicles/tank/baf1_a
	name = "BAF I mod. A"
	icon_state = "4x4"
	custom_color = "#8383C2"
	axis = /obj/structure/vehicleparts/axis/heavy/baf1_a
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks/right, /obj/structure/vehicleparts/frame/baf1_a/rf, /obj/structure/lamp/lamp_small/tank/floodlight, /obj/structure/bed/chair/drivers/tank),
	"2,1" = list(/obj/structure/vehicleparts/frame/baf1_a/front, /obj/structure/bed/chair/commander),
	"3,1" = list(/obj/structure/vehicleparts/movement/tracks/left, /obj/structure/vehicleparts/frame/baf1_a/lf, /obj/item/ammo_magazine/pkm, /obj/item/ammo_magazine/pkm, /obj/item/ammo_magazine/pkm, /obj/item/ammo_magazine/pkm, /obj/item/weapon/gun/projectile/automatic/stationary/pkm, /obj/structure/lamp/lamp_small/tank/floodlight),

	"1,2" = list(/obj/structure/vehicleparts/frame/baf1_a/right),
	"2,2" = list(/obj/structure/vehicleparts/frame/baf1_a, /obj/structure/cannon/modern/tank/baftkn75),
	"3,2" = list(/obj/structure/vehicleparts/frame/baf1_a/left, /obj/structure/bed/chair/loader),

	"1,3" = list(/obj/structure/vehicleparts/frame/baf1_a/right/door, /obj/item/weapon/storage/toolbox/emergency),
	"2,3" = list(/obj/structure/vehicleparts/frame/baf1_a/center_back, /obj/structure/bed/chair/gunner),
	"3,3" = list(/obj/structure/vehicleparts/frame/baf1_a/left/door),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/left/reversed, /obj/structure/vehicleparts/frame/baf1_a/rb, /obj/structure/engine/internal/gasoline/premade/baf1_a),
	"2,4" = list(/obj/structure/vehicleparts/frame/baf1_a/back, /obj/structure/lamp/lamp_small/tank/red, /obj/structure/shellrack/full75),
	"3,4" = list(/obj/structure/vehicleparts/movement/tracks/right/reversed, /obj/structure/vehicleparts/frame/baf1_a/lb, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueledgasoline),
	)

/obj/effects/premadevehicles/tank/m4
	name = "M4-Sherman"
	icon_state = "4x4"
	custom_color = "#293822"
	axis = /obj/structure/vehicleparts/axis/heavy/m4
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks, /obj/structure/vehicleparts/frame/m4/rf, /obj/item/ammo_magazine/browning, /obj/item/ammo_magazine/browning, /obj/item/ammo_magazine/browning, /obj/item/ammo_magazine/browning, /obj/structure/bed/chair/mgunner/browning_lmg),
	"2,1" = list(/obj/structure/vehicleparts/frame/m4/front, /obj/item/weapon/storage/toolbox/emergency),
	"3,1" = list(/obj/structure/vehicleparts/movement/tracks, /obj/structure/vehicleparts/frame/m4/lf, /obj/structure/bed/chair/drivers/tank),

	"1,2" = list(/obj/structure/vehicleparts/frame/m4/right, /obj/structure/shellrack/full75),
	"2,2" = list(/obj/structure/vehicleparts/frame/m4, /obj/structure/turret/sherman),
	"3,2" = list(/obj/structure/vehicleparts/frame/m4/left, /obj/structure/shellrack/full75),

	"1,3" = list(/obj/structure/vehicleparts/frame/m4/right/door),
	"2,3" = list(/obj/structure/vehicleparts/frame/m4, /obj/structure/shellrack/full75),
	"3,3" = list(/obj/structure/vehicleparts/frame/m4/left/door,),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/reversed, /obj/structure/vehicleparts/frame/m4/rb, /obj/structure/engine/internal/diesel/premade/chiha),
	"2,4" = list(/obj/structure/vehicleparts/frame/m4/back),
	"3,4" = list(/obj/structure/vehicleparts/movement/tracks/reversed, /obj/structure/vehicleparts/frame/m4/lb, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel)
	)

/obj/effects/premadevehicles/tank/chiha
	name = "Type 97 Chi-Ha"
	icon_state = "4x4"
	custom_color = "#6a5a3d"
	axis = /obj/structure/vehicleparts/axis/heavy/chi_ha
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks, /obj/structure/vehicleparts/frame/chi_ha/rf, /obj/item/ammo_magazine/type92, /obj/item/ammo_magazine/type92, /obj/item/ammo_magazine/type92, /obj/item/ammo_magazine/type92, /obj/item/ammo_magazine/type92, /obj/item/weapon/gun/projectile/automatic/stationary/type98),
	"2,1" = list(/obj/structure/vehicleparts/frame/chi_ha/front, /obj/item/weapon/storage/toolbox/emergency),
	"3,1" = list(/obj/structure/vehicleparts/movement/tracks, /obj/structure/vehicleparts/frame/chi_ha/lf, /obj/structure/bed/chair/drivers/tank),

	"1,2" = list(/obj/structure/vehicleparts/frame/chi_ha/right, /obj/structure/bed/chair/commander),
	"2,2" = list(/obj/structure/vehicleparts/frame/chi_ha, /obj/structure/cannon/modern/tank/japanese57),
	"3,2" = list(/obj/structure/vehicleparts/frame/chi_ha/left, /obj/structure/bed/chair/gunner),

	"1,3" = list(/obj/structure/vehicleparts/frame/chi_ha/right/door),
	"2,3" = list(/obj/structure/vehicleparts/frame/chi_ha, /obj/structure/bed/chair/loader),
	"3,3" = list(/obj/structure/vehicleparts/frame/chi_ha/left/door,),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/reversed, /obj/structure/vehicleparts/frame/chi_ha/rb, /obj/structure/engine/internal/diesel/premade/chiha, /obj/item/ammo_magazine/type92, /obj/item/ammo_magazine/type92, /obj/item/ammo_magazine/type92, /obj/item/ammo_magazine/type92, /obj/item/ammo_magazine/type92, /obj/item/weapon/gun/projectile/automatic/stationary/type98),
	"2,4" = list(/obj/structure/vehicleparts/frame/chi_ha/back, /obj/structure/shellrack/full57),
	"3,4" = list(/obj/structure/vehicleparts/movement/tracks/reversed, /obj/structure/vehicleparts/frame/chi_ha/lb, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel)
	)

/obj/effects/premadevehicles/tank/hago
	name = "Type 95 Ha-Go"
	icon_state = "3x3"
	custom_color = "#6a5a3d"
	axis = /obj/structure/vehicleparts/axis/heavy/hago
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks/hago/right, /obj/structure/vehicleparts/frame/hago/rf, /obj/structure/bed/chair/drivers/tank),
	"2,1" = list(/obj/structure/vehicleparts/movement/tracks/hago/left, /obj/structure/vehicleparts/frame/hago/lf, /obj/structure/bed/chair/mgunner/type97, /obj/item/ammo_magazine/type99/type97, /obj/item/ammo_magazine/type99/type97, /obj/item/ammo_magazine/type99/type97, /obj/item/ammo_magazine/type99/type97, /obj/item/ammo_magazine/type99/type97, /obj/item/ammo_magazine/type99/type97, /obj/item/ammo_magazine/type99/type97, /obj/item/ammo_magazine/type99/type97, /obj/item/ammo_magazine/type99/type97, /obj/item/ammo_magazine/type99/type97),

	"1,2" = list(/obj/structure/vehicleparts/frame/hago/rc,),
	"2,2" = list(/obj/structure/vehicleparts/frame/hago/lc, /obj/structure/turret/hago),

	"1,3" = list(/obj/structure/vehicleparts/frame/hago/rb, /obj/structure/vehicleparts/movement/tracks/hago/left/reversed, /obj/structure/engine/internal/diesel/premade/hago, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel),
	"2,3" = list(/obj/structure/vehicleparts/frame/hago/lb, /obj/structure/vehicleparts/movement/tracks/hago/right/reversed, /obj/structure/shellrack/full37, /obj/item/ammo_magazine/type99/type97, /obj/item/ammo_magazine/type99/type97, /obj/item/ammo_magazine/type99/type97, /obj/item/ammo_magazine/type99/type97, /obj/item/ammo_magazine/type99/type97, /obj/item/ammo_magazine/type99/type97, /obj/item/ammo_magazine/type99/type97, /obj/item/ammo_magazine/type99/type97, /obj/item/ammo_magazine/type99/type97, /obj/item/ammo_magazine/type99/type97, /obj/item/ammo_magazine/type99/type97),
	)
/obj/effects/premadevehicles/tank/l3
	name = "L3/33"
	icon_state = "3x3"
	custom_color = "#D79E57"
	axis = /obj/structure/vehicleparts/axis/heavy/l3
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/frame/l3/rf, /obj/structure/vehicleparts/movement/tracks/right),
	"2,1" = list(/obj/structure/vehicleparts/frame/l3/lf, /obj/structure/vehicleparts/movement/tracks/left),

	"1,2" = list(/obj/structure/vehicleparts/frame/l3/rc, /obj/structure/bed/chair/drivers/tank{anchored = 1}),
	"2,2" = list(/obj/structure/vehicleparts/frame/l3/lc, /obj/structure/bed/chair/office/dark{anchored = 1}, /obj/item/weapon/gun/projectile/automatic/stationary/breda30/hull, /obj/item/ammo_magazine/breda30, /obj/item/ammo_magazine/breda30, /obj/item/ammo_magazine/breda30, /obj/item/ammo_magazine/breda30, /obj/item/ammo_magazine/breda30),

	"1,3" = list(/obj/structure/vehicleparts/frame/l3/rb, /obj/structure/vehicleparts/movement/tracks/left/reversed, /obj/structure/engine/internal/gasoline/premade/l3),
	"2,3" = list(/obj/structure/vehicleparts/frame/l3/lb, /obj/structure/vehicleparts/movement/tracks/right/reversed, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/smalltank/fueledgasoline),
	)

/obj/effects/premadevehicles/tank/l3/antitank
	name = "L3/33 CC"
	icon_state = "3x3"
	custom_color = "#D79E57"
	axis = /obj/structure/vehicleparts/axis/heavy/l3cc
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/frame/l3/rf, /obj/structure/vehicleparts/movement/tracks/right),
	"2,1" = list(/obj/structure/vehicleparts/frame/l3/lf/cc, /obj/structure/vehicleparts/movement/tracks/left),

	"1,2" = list(/obj/structure/vehicleparts/frame/l3/rc, /obj/structure/bed/chair/drivers/tank{anchored = 1}),
	"2,2" = list(/obj/structure/vehicleparts/frame/l3/lc, /obj/structure/bed/chair/office/dark{anchored = 1}, /obj/item/weapon/gun/projectile/automatic/stationary/solothurn/italian/stationary, /obj/item/ammo_magazine/a20mm_aphe, /obj/item/ammo_magazine/a20mm_aphe, /obj/item/ammo_magazine/a20mm_aphe, /obj/item/ammo_magazine/a20mm_aphe, /obj/item/ammo_magazine/a20mm_aphe),

	"1,3" = list(/obj/structure/vehicleparts/frame/l3/rb, /obj/structure/vehicleparts/movement/tracks/left/reversed, /obj/structure/engine/internal/gasoline/premade/l3),
	"2,3" = list(/obj/structure/vehicleparts/frame/l3/lb, /obj/structure/vehicleparts/movement/tracks/right/reversed, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/smalltank/fueledgasoline),
	)

/obj/effects/premadevehicles/tank/m13
	name = "M13/40"
	icon_state = "4x4"
	custom_color = "#778687"
	axis = /obj/structure/vehicleparts/axis/heavy/m13
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/frame/m13/rf, /obj/structure/vehicleparts/movement/tracks/right),
	"2,1" = list(/obj/structure/vehicleparts/frame/m13/front),
	"3,1" = list(/obj/structure/vehicleparts/frame/m13/lf, /obj/structure/vehicleparts/movement/tracks/left),

	"1,2" = list(/obj/structure/vehicleparts/frame/m13/rf/thin, /obj/item/weapon/gun/projectile/automatic/stationary/breda30/hull, /obj/item/ammo_magazine/breda30, /obj/item/ammo_magazine/breda30, /obj/item/ammo_magazine/breda30, /obj/item/ammo_magazine/breda30, /obj/item/ammo_magazine/breda30),
	"2,2" = list(/obj/structure/vehicleparts/frame/m13/front/thin),
	"3,2" = list(/obj/structure/vehicleparts/frame/m13/lf/thin, /obj/structure/bed/chair/drivers/tank),

	"1,3" = list(/obj/structure/vehicleparts/frame/m13/right/door, /obj/structure/bed/chair/commander),
	"2,3" = list(/obj/structure/vehicleparts/frame/m13, /obj/structure/cannon/modern/tank/italian47),
	"3,3" = list(/obj/structure/vehicleparts/frame/m13/left/door, /obj/structure/bed/chair/gunner),

	"1,4" = list(/obj/structure/vehicleparts/frame/m13/rb, /obj/structure/vehicleparts/movement/tracks/left/reversed, /obj/structure/shellrack/full47),
	"2,4" = list(/obj/structure/vehicleparts/frame/m13/back, /obj/structure/bed/chair/loader),
	"3,4" = list(/obj/structure/vehicleparts/frame/m13/lb, /obj/structure/vehicleparts/movement/tracks/right/reversed, /obj/structure/engine/internal/diesel/premade/m13, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel),
	)

/obj/effects/premadevehicles/tank/t34
	name = "T34"
	icon_state = "4x4"
	custom_color = "#3d5931"
	axis = /obj/structure/vehicleparts/axis/heavy/t34
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks/t34/right_front, /obj/structure/vehicleparts/frame/t34/rf, /obj/structure/bed/chair/mgunner/dt28),
	"2,1" = list(/obj/structure/vehicleparts/frame/t34/front, /obj/item/ammo_magazine/dp/dt, /obj/item/ammo_magazine/dp/dt, /obj/item/ammo_magazine/dp/dt, /obj/item/ammo_magazine/dp/dt, /obj/item/ammo_magazine/dp/dt, /obj/item/ammo_magazine/dp/dt),
	"3,1" = list(/obj/structure/vehicleparts/movement/tracks/t34/left_front, /obj/structure/vehicleparts/frame/t34/lf, /obj/structure/bed/chair/drivers/tank),

	"1,2" = list(/obj/structure/vehicleparts/frame/t34/right, /obj/structure/shellrack/full76),
	"2,2" = list(/obj/structure/vehicleparts/frame/t34/fc, /obj/structure/turret/t34),
	"3,2" = list(/obj/structure/vehicleparts/frame/t34/left, /obj/structure/shellrack/full76),

	"1,3" = list(/obj/structure/vehicleparts/frame/t34/right/door),
	"2,3" = list(/obj/structure/vehicleparts/frame/t34/bc, /obj/structure/shellrack/full76),
	"3,3" = list(/obj/structure/vehicleparts/frame/t34/left/door, /obj/item/weapon/storage/toolbox/emergency),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/t34/right_back, /obj/structure/vehicleparts/frame/t34/rb, /obj/structure/engine/internal/diesel/premade/chiha),
	"2,4" = list(/obj/structure/vehicleparts/frame/t34/back),
	"3,4" = list(/obj/structure/vehicleparts/movement/tracks/t34/left_back, /obj/structure/vehicleparts/frame/t34/lb, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel)
	)

/obj/effects/premadevehicles/tank/bt7
	name = "BT-7"
	icon_state = "4x4"
	custom_color = "#5c784f"
	axis = /obj/structure/vehicleparts/axis/heavy/bt7
	tocreate = list(
	"1,1" =list(/obj/structure/vehicleparts/movement/tracks, /obj/structure/vehicleparts/frame/bt7/rf, /obj/item/ammo_magazine/dp/dt, /obj/item/ammo_magazine/dp/dt, /obj/item/ammo_magazine/dp/dt, /obj/item/ammo_magazine/dp/dt),
	"2,1" =list(/obj/structure/vehicleparts/movement/tracks, /obj/structure/vehicleparts/frame/bt7/lf, /obj/structure/bed/chair/drivers/tank),

	"1,2" =list(/obj/structure/vehicleparts/frame/bt7/rfc, /obj/structure/shellrack/full45),
	"2,2" =list(/obj/structure/vehicleparts/frame/bt7/lfc, /obj/structure/turret/bt7,),

	"1,3" =list(/obj/structure/vehicleparts/frame/bt7/rbc, /obj/item/weapon/storage/toolbox/emergency),
	"2,3" =list(/obj/structure/vehicleparts/frame/bt7/lbc),

	"1,4" =list(/obj/structure/vehicleparts/movement/tracks/reversed, /obj/structure/vehicleparts/frame/bt7/rb, /obj/structure/engine/internal/diesel/premade/chiha),
	"2,4" =list(/obj/structure/vehicleparts/movement/tracks/reversed, /obj/structure/vehicleparts/frame/bt7/lb, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel)
	)
/obj/effects/premadevehicles/tank/t3485
	name = "T-34-85"
	icon_state = "4x4"
	custom_color = "#4a5243"
	axis = /obj/structure/vehicleparts/axis/heavy/t34/t3485
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks/t34/right_front, /obj/structure/vehicleparts/frame/t34/rf, /obj/structure/bed/chair/mgunner/dtm28),
	"2,1" = list(/obj/structure/vehicleparts/frame/t34/front, /obj/item/ammo_magazine/dp/dt, /obj/item/ammo_magazine/dp/dt, /obj/item/ammo_magazine/dp/dt, /obj/item/ammo_magazine/dp/dt, /obj/item/ammo_magazine/dp/dt, /obj/item/ammo_magazine/dp/dt),
	"3,1" = list(/obj/structure/vehicleparts/movement/tracks/t34/left_front, /obj/structure/vehicleparts/frame/t34/lf, /obj/structure/bed/chair/drivers/tank),

	"1,2" = list(/obj/structure/vehicleparts/frame/t34/right, /obj/structure/shellrack/full85),
	"2,2" = list(/obj/structure/vehicleparts/frame/t34/fc, /obj/structure/turret/t3485),
	"3,2" = list(/obj/structure/vehicleparts/frame/t34/left, /obj/structure/shellrack/full85),

	"1,3" = list(/obj/structure/vehicleparts/frame/t34/right/door),
	"2,3" = list(/obj/structure/vehicleparts/frame/t34/bc),
	"3,3" = list(/obj/structure/vehicleparts/frame/t34/left/door, /obj/item/weapon/storage/toolbox/emergency),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/t34/right_back, /obj/structure/vehicleparts/frame/t34/rb, /obj/structure/engine/internal/diesel/premade/chiha),
	"2,4" = list(/obj/structure/vehicleparts/frame/t34/back),
	"3,4" = list(/obj/structure/vehicleparts/movement/tracks/t34/left_back, /obj/structure/vehicleparts/frame/t34/lb, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel)
	)

/obj/effects/premadevehicles/tank/kv1
	name = "KV-1A"
	icon_state = "4x4"
	custom_color = "#3d5931"
	axis = /obj/structure/vehicleparts/axis/heavy/kv1a
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks, /obj/structure/vehicleparts/frame/kv1/rf, /obj/item/weapon/storage/toolbox/emergency),
	"2,1" = list(/obj/structure/vehicleparts/frame/kv1/front, /obj/structure/bed/chair/drivers/tank),
	"3,1" = list(/obj/structure/vehicleparts/movement/tracks, /obj/structure/vehicleparts/frame/kv1/lf, /obj/structure/bed/chair/mgunner/dt28, /obj/item/ammo_magazine/dp/dt, /obj/item/ammo_magazine/dp/dt, /obj/item/ammo_magazine/dp/dt),

	"1,2" = list(/obj/structure/vehicleparts/frame/kv1/right),
	"2,2" = list(/obj/structure/vehicleparts/frame/kv1, /obj/structure/turret/kv1),
	"3,2" = list(/obj/structure/vehicleparts/frame/kv1/left),

	"1,3" = list(/obj/structure/vehicleparts/frame/kv1/right/door),
	"2,3" = list(/obj/structure/vehicleparts/frame/kv1, /obj/structure/bed/chair/loader),
	"3,3" = list(/obj/structure/vehicleparts/frame/kv1/left/door),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/reversed, /obj/structure/vehicleparts/frame/kv1/rb, /obj/structure/engine/internal/diesel/premade/chiha),
	"2,4" = list(/obj/structure/vehicleparts/frame/kv1/back, /obj/structure/shellrack/full85),
	"3,4" = list(/obj/structure/vehicleparts/movement/tracks/reversed, /obj/structure/vehicleparts/frame/kv1/lb, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel)
	)

/obj/effects/premadevehicles/tank/su100
	name = "SU-100"
	icon_state = "4x4"
	custom_color = "#4a5243"
	axis = /obj/structure/vehicleparts/axis/heavy/su100
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks/t34/right_front, /obj/structure/vehicleparts/frame/su100/rf, /obj/structure/shellrack/full100ww2),
	"2,1" = list(/obj/structure/vehicleparts/frame/su100/front, /obj/structure/turret/course/su100),
	"3,1" = list(/obj/structure/vehicleparts/movement/tracks/t34/left_front, /obj/structure/vehicleparts/frame/su100/lf, /obj/structure/bed/chair/drivers/tank),

	"1,2" = list(/obj/structure/vehicleparts/frame/su100/rfc, /obj/structure/bed/chair/commander),
	"2,2" = list(/obj/structure/vehicleparts/frame/su100/fc, /obj/structure/shellrack/full100ww2),
	"3,2" = list(/obj/structure/vehicleparts/frame/su100/lfc, /obj/item/weapon/storage/toolbox/emergency),

	"1,3" = list(/obj/structure/vehicleparts/frame/su100/rbc),
	"2,3" = list(/obj/structure/vehicleparts/frame/su100/bc),
	"3,3" = list(/obj/structure/vehicleparts/frame/su100/lbc),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/t34/right_back, /obj/structure/vehicleparts/frame/su100/rb),
	"2,4" = list(/obj/structure/vehicleparts/frame/su100/back, /obj/structure/engine/internal/diesel/premade/chiha),
	"3,4" = list(/obj/structure/vehicleparts/movement/tracks/t34/left_back, /obj/structure/vehicleparts/frame/su100/lb, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel)
	)

/obj/effects/premadevehicles/tank/su85m
	name = "SU-85M"
	icon_state = "4x4"
	custom_color = "#4a5243"
	axis = /obj/structure/vehicleparts/axis/heavy/su100/su85m
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks/t34/right_front, /obj/structure/vehicleparts/frame/su100/rf, /obj/structure/shellrack/full85),
	"2,1" = list(/obj/structure/vehicleparts/frame/su100/front, /obj/structure/turret/course/su85m),
	"3,1" = list(/obj/structure/vehicleparts/movement/tracks/t34/left_front, /obj/structure/vehicleparts/frame/su100/lf, /obj/structure/bed/chair/drivers/tank),

	"1,2" = list(/obj/structure/vehicleparts/frame/su100/rfc, /obj/structure/bed/chair/commander),
	"2,2" = list(/obj/structure/vehicleparts/frame/su100/fc, /obj/structure/shellrack/full85),
	"3,2" = list(/obj/structure/vehicleparts/frame/su100/lfc, /obj/item/weapon/storage/toolbox/emergency),

	"1,3" = list(/obj/structure/vehicleparts/frame/su100/rbc),
	"2,3" = list(/obj/structure/vehicleparts/frame/su100/bc),
	"3,3" = list(/obj/structure/vehicleparts/frame/su100/lbc),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/t34/right_back, /obj/structure/vehicleparts/frame/su100/rb),
	"2,4" = list(/obj/structure/vehicleparts/frame/su100/back, /obj/structure/engine/internal/diesel/premade/chiha),
	"3,4" = list(/obj/structure/vehicleparts/movement/tracks/t34/left_back, /obj/structure/vehicleparts/frame/su100/lb, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel)
	)

/obj/effects/premadevehicles/tank/t55
	name = "T-55"
	icon_state = "4x4"
	custom_color = "#4a5243"
	axis = /obj/structure/vehicleparts/axis/heavy/t55
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks/right, /obj/structure/vehicleparts/frame/t55/rf),
	"2,1" = list(/obj/structure/vehicleparts/frame/t55/front),
	"3,1" = list(/obj/structure/vehicleparts/movement/tracks/left, /obj/structure/vehicleparts/frame/t55/lf, /obj/structure/radio/transmitter_receiver/nopower/tank/faction2, /obj/structure/bed/chair/drivers/tank),

	"1,2" = list(/obj/structure/vehicleparts/frame/t55/right),
	"2,2" = list(/obj/structure/vehicleparts/frame/t55, /obj/structure/turret/t55, /obj/structure/shellrack/full100ww2),
	"3,2" = list(/obj/structure/vehicleparts/frame/t55/left, /obj/item/ammo_magazine/ammo127, /obj/item/ammo_magazine/ammo127, /obj/item/ammo_magazine/ammo127, /obj/item/ammo_magazine/ammo127),

	"1,3" = list(/obj/structure/vehicleparts/frame/t55/right/door),
	"2,3" = list(/obj/structure/vehicleparts/frame/t55),
	"3,3" = list(/obj/structure/vehicleparts/frame/t55/left),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/left/reversed, /obj/structure/vehicleparts/frame/t55/rb, /obj/structure/engine/internal/diesel/premade/v12),
	"2,4" = list(/obj/structure/vehicleparts/frame/t55/back, /obj/structure/shellrack/full100ww2),
	"3,4" = list(/obj/structure/vehicleparts/movement/tracks/right/reversed, /obj/structure/vehicleparts/frame/t55/lb, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel)
	)

/obj/effects/premadevehicles/tank/t64bm
	name = "T-64BM"
	icon_state = "4x4"
	custom_color = "#5c5c4c"
	axis = /obj/structure/vehicleparts/axis/heavy/t64bm
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks/right, /obj/structure/vehicleparts/frame/t72/rf, /obj/item/ammo_magazine/pkm, /obj/item/ammo_magazine/pkm, /obj/item/ammo_magazine/pkm),
	"2,1" = list(/obj/structure/vehicleparts/frame/t72/front, /obj/structure/bed/chair/drivers/tank),
	"3,1" = list(/obj/structure/vehicleparts/movement/tracks/left, /obj/structure/vehicleparts/frame/t72/lf, /obj/structure/radio/transmitter_receiver/nopower/tank/faction2),

	"1,2" = list(/obj/structure/vehicleparts/frame/t72/right),
	"2,2" = list(/obj/structure/vehicleparts/frame/t72, /obj/structure/shellrack/autoloader/full125/, /obj/structure/turret/t64bm),
	"3,2" = list(/obj/structure/vehicleparts/frame/t72/left),

	"1,3" = list(/obj/structure/vehicleparts/frame/t72/right/door{doorcode = 4975}),
	"2,3" = list(/obj/structure/vehicleparts/frame/t72),
	"3,3" = list(/obj/structure/vehicleparts/frame/t72/left),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/left/reversed, /obj/structure/vehicleparts/frame/t72/rb, /obj/structure/engine/internal/diesel/premade/v12),
	"2,4" = list(/obj/structure/vehicleparts/frame/t72/back),
	"3,4" = list(/obj/structure/vehicleparts/movement/tracks/right/reversed, /obj/structure/vehicleparts/frame/t72/lb, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel)
	)

/obj/effects/premadevehicles/tank/t72
	name = "T-72"
	icon_state = "4x4"
	custom_color = "#5c5c4c"
	axis = /obj/structure/vehicleparts/axis/heavy/t72
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks/right, /obj/structure/vehicleparts/frame/t72/rf, /obj/item/ammo_magazine/pkm, /obj/item/ammo_magazine/pkm, /obj/item/ammo_magazine/pkm, /obj/item/ammo_magazine/pkm),
	"2,1" = list(/obj/structure/vehicleparts/frame/t72/front, /obj/structure/bed/chair/drivers/tank),
	"3,1" = list(/obj/structure/vehicleparts/movement/tracks/left, /obj/structure/vehicleparts/frame/t72/lf, /obj/structure/radio/transmitter_receiver/nopower/tank/faction2),

	"1,2" = list(/obj/structure/vehicleparts/frame/t72/right),
	"2,2" = list(/obj/structure/vehicleparts/frame/t72, /obj/structure/shellrack/autoloader/full125, /obj/structure/turret/t72),
	"3,2" = list(/obj/structure/vehicleparts/frame/t72/left),

	"1,3" = list(/obj/structure/vehicleparts/frame/t72/right/door{doorcode = 4975}),
	"2,3" = list(/obj/structure/vehicleparts/frame/t72),
	"3,3" = list(/obj/structure/vehicleparts/frame/t72/left),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/left/reversed, /obj/structure/vehicleparts/frame/t72/rb, /obj/structure/engine/internal/diesel/premade/v12),
	"2,4" = list(/obj/structure/vehicleparts/frame/t72/back),
	"3,4" = list(/obj/structure/vehicleparts/movement/tracks/right/reversed, /obj/structure/vehicleparts/frame/t72/lb, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel)
	)

/obj/effects/premadevehicles/tank/t72b3 //UK = B3?
	name = "T-72B3"
	icon_state = "4x4"
	custom_color = "#5c5c4c"
	axis = /obj/structure/vehicleparts/axis/heavy/t72b3
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks/right, /obj/structure/vehicleparts/frame/t90a/rf, /obj/item/ammo_magazine/pkm, /obj/item/ammo_magazine/pkm, /obj/item/ammo_magazine/pkm),
	"2,1" = list(/obj/structure/vehicleparts/frame/t90a/front, /obj/structure/bed/chair/drivers/tank),
	"3,1" = list(/obj/structure/vehicleparts/movement/tracks/left, /obj/structure/vehicleparts/frame/t90a/lf, /obj/structure/radio/transmitter_receiver/nopower/tank/faction2),

	"1,2" = list(/obj/structure/vehicleparts/frame/t90a/right),
	"2,2" = list(/obj/structure/vehicleparts/frame/t90a, /obj/structure/shellrack/autoloader/full125, /obj/structure/turret/t72/t72b3),
	"3,2" = list(/obj/structure/vehicleparts/frame/t90a/left),

	"1,3" = list(/obj/structure/vehicleparts/frame/t90a/right/door{doorcode = 4975}),
	"2,3" = list(/obj/structure/vehicleparts/frame/t90a),
	"3,3" = list(/obj/structure/vehicleparts/frame/t90a/left),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/left/reversed, /obj/structure/vehicleparts/frame/t90a/rb, /obj/structure/engine/internal/diesel/premade/v12),
	"2,4" = list(/obj/structure/vehicleparts/frame/t90a/back),
	"3,4" = list(/obj/structure/vehicleparts/movement/tracks/right/reversed, /obj/structure/vehicleparts/frame/t90a/lb, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel)
	)
/obj/effects/premadevehicles/tank/t72m1
	name = "T-72M1"
	icon_state = "4x4"
	custom_color = "#5c5c4c"
	axis = /obj/structure/vehicleparts/axis/heavy/t72m1
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks/right, /obj/structure/vehicleparts/frame/t72/rf, /obj/item/ammo_magazine/pkm, /obj/item/ammo_magazine/pkm, /obj/item/ammo_magazine/pkm, /obj/item/ammo_magazine/pkm),
	"2,1" = list(/obj/structure/vehicleparts/frame/t72/front, /obj/structure/bed/chair/drivers/tank),
	"3,1" = list(/obj/structure/vehicleparts/movement/tracks/left, /obj/structure/vehicleparts/frame/t72/lf, /obj/structure/radio/transmitter_receiver/nopower/tank/faction2),

	"1,2" = list(/obj/structure/vehicleparts/frame/t72/right),
	"2,2" = list(/obj/structure/vehicleparts/frame/t72, /obj/structure/shellrack/autoloader/full125, /obj/structure/turret/t72/t72m1),
	"3,2" = list(/obj/structure/vehicleparts/frame/t72/left),

	"1,3" = list(/obj/structure/vehicleparts/frame/t72/right/door{doorcode = 4975}),
	"2,3" = list(/obj/structure/vehicleparts/frame/t72),
	"3,3" = list(/obj/structure/vehicleparts/frame/t72/left),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/left/reversed, /obj/structure/vehicleparts/frame/t72/rb, /obj/structure/engine/internal/diesel/premade/v12),
	"2,4" = list(/obj/structure/vehicleparts/frame/t72/back),
	"3,4" = list(/obj/structure/vehicleparts/movement/tracks/right/reversed, /obj/structure/vehicleparts/frame/t72/lb, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel)
	)

/obj/effects/premadevehicles/tank/t80uk
	name = "T-80UK"
	icon_state = "4x4"
	custom_color = "#5c5c4c"
	axis = /obj/structure/vehicleparts/axis/heavy/t80uk
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks/right, /obj/structure/vehicleparts/frame/t90a/rf, /obj/item/ammo_magazine/pkm, /obj/item/ammo_magazine/pkm, /obj/item/ammo_magazine/pkm, /obj/item/ammo_magazine/pkm),
	"2,1" = list(/obj/structure/vehicleparts/frame/t90a/front, /obj/structure/bed/chair/drivers/tank),
	"3,1" = list(/obj/structure/vehicleparts/movement/tracks/left, /obj/structure/vehicleparts/frame/t90a/lf, /obj/structure/radio/transmitter_receiver/nopower/tank/faction2),

	"1,2" = list(/obj/structure/vehicleparts/frame/t90a/right, /obj/structure/bed/chair/commander),
	"2,2" = list(/obj/structure/vehicleparts/frame/t90a, /obj/structure/turret/t80u/t80uk, /obj/structure/shellrack/autoloader/full125),
	"3,2" = list(/obj/structure/vehicleparts/frame/t90a/left, /obj/structure/bed/chair/gunner),

	"1,3" = list(/obj/structure/vehicleparts/frame/t90a/right/door{doorcode = 4975}),
	"2,3" = list(/obj/structure/vehicleparts/frame/t90a),
	"3,3" = list(/obj/structure/vehicleparts/frame/t90a/left),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/left/reversed, /obj/structure/vehicleparts/frame/t90a/rb, /obj/structure/engine/internal/diesel/premade/v12),
	"2,4" = list(/obj/structure/vehicleparts/frame/t90a/back),
	"3,4" = list(/obj/structure/vehicleparts/movement/tracks/right/reversed, /obj/structure/vehicleparts/frame/t90a/lb, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel)
	)

/obj/effects/premadevehicles/tank/t90a
	name = "T-90A"
	icon_state = "4x4"
	custom_color = "#4a5243"
	axis = /obj/structure/vehicleparts/axis/heavy/t90a
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks/right, /obj/structure/vehicleparts/frame/t90a/rf, /obj/item/ammo_magazine/pkm, /obj/item/ammo_magazine/pkm, /obj/item/ammo_magazine/pkm),
	"2,1" = list(/obj/structure/vehicleparts/frame/t90a/front, /obj/structure/bed/chair/drivers/tank),
	"3,1" = list(/obj/structure/vehicleparts/movement/tracks/left, /obj/structure/vehicleparts/frame/t90a/lf, /obj/structure/radio/transmitter_receiver/nopower/tank/faction2),

	"1,2" = list(/obj/structure/vehicleparts/frame/t90a/right),
	"2,2" = list(/obj/structure/vehicleparts/frame/t90a, /obj/structure/shellrack/autoloader/full125/, /obj/structure/turret/t90a),
	"3,2" = list(/obj/structure/vehicleparts/frame/t90a/left),

	"1,3" = list(/obj/structure/vehicleparts/frame/t90a/right/door{doorcode = 4975}),
	"2,3" = list(/obj/structure/vehicleparts/frame/t90a),
	"3,3" = list(/obj/structure/vehicleparts/frame/t90a/left),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/left/reversed, /obj/structure/vehicleparts/frame/t90a/rb, /obj/structure/engine/internal/diesel/premade/v12),
	"2,4" = list(/obj/structure/vehicleparts/frame/t90a/back),
	"3,4" = list(/obj/structure/vehicleparts/movement/tracks/right/reversed, /obj/structure/vehicleparts/frame/t90a/lb, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel)
	)

/obj/effects/premadevehicles/tank/m1a1_abrams
	name = "M1A1 Abrams"
	icon_state = "4x4"
	custom_color = "#58564a"
	axis = /obj/structure/vehicleparts/axis/heavy/m1a1_abrams
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks/right, /obj/structure/vehicleparts/frame/baf1_a/rf, /obj/item/ammo_magazine/a50cal_can, /obj/item/ammo_magazine/a50cal_can, /obj/item/ammo_magazine/a50cal_can, /obj/item/weapon/gun/projectile/automatic/stationary/m2browning),
	"2,1" = list(/obj/structure/vehicleparts/frame/baf1_a/front, /obj/structure/bed/chair/drivers/tank),
	"3,1" = list(/obj/structure/vehicleparts/movement/tracks/left, /obj/structure/vehicleparts/frame/baf1_a/lf, /obj/structure/radio/transmitter_receiver/nopower/tank/faction1),

	"1,2" = list(/obj/structure/vehicleparts/frame/baf1_a/right, /obj/structure/shellrack/full120),
	"2,2" = list(/obj/structure/vehicleparts/frame/baf1_a, /obj/structure/turret/m1abrams),
	"3,2" = list(/obj/structure/vehicleparts/frame/baf1_a/left, /obj/structure/shellrack/full120),

	"1,3" = list(/obj/structure/vehicleparts/frame/baf1_a/right/door{doorcode = 9950}),
	"2,3" = list(/obj/structure/vehicleparts/frame/baf1_a),
	"3,3" = list(/obj/structure/vehicleparts/frame/baf1_a/left),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/left/reversed, /obj/structure/vehicleparts/frame/baf1_a/rb, /obj/structure/engine/internal/turbine/abrams),
	"2,4" = list(/obj/structure/vehicleparts/frame/baf1_a/back, /obj/structure/shellrack/full120),
	"3,4" = list(/obj/structure/vehicleparts/movement/tracks/right/reversed, /obj/structure/vehicleparts/frame/baf1_a/lb, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel)
	)

/obj/effects/premadevehicles/tank/challenger2
	name = "FV4034 Challenger 2"
	icon_state = "4x4"
	custom_color = "#CCC0A6"
	axis = /obj/structure/vehicleparts/axis/heavy/challenger2
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks/right, /obj/structure/vehicleparts/frame/omw22_2/rf, /obj/item/ammo_magazine/mg3belt, /obj/item/ammo_magazine/mg3belt, /obj/item/ammo_magazine/mg3belt),
	"2,1" = list(/obj/structure/vehicleparts/frame/omw22_2/front, /obj/structure/bed/chair/drivers/tank),
	"3,1" = list(/obj/structure/vehicleparts/movement/tracks/left, /obj/structure/vehicleparts/frame/omw22_2/lf),

	"1,2" = list(/obj/structure/vehicleparts/frame/omw22_2/right),
	"2,2" = list(/obj/structure/vehicleparts/frame/omw22_2, /obj/structure/turret/challenger2),
	"3,2" = list(/obj/structure/vehicleparts/frame/omw22_2/left),

	"1,3" = list(/obj/structure/vehicleparts/frame/omw22_2/right/door{doorcode = 5970}),
	"2,3" = list(/obj/structure/vehicleparts/frame/omw22_2),
	"3,3" = list(/obj/structure/vehicleparts/frame/omw22_2/left),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/left/reversed, /obj/structure/vehicleparts/frame/omw22_2/rb, /obj/structure/engine/internal/diesel/premade/v12),
	"2,4" = list(/obj/structure/vehicleparts/frame/omw22_2/back, /obj/structure/shellrack/full100modern),
	"3,4" = list(/obj/structure/vehicleparts/movement/tracks/right/reversed, /obj/structure/vehicleparts/frame/omw22_2/lb, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel)
	)

/obj/effects/premadevehicles/tank/leopard2a6
	name = "Leopard 2A6"
	icon_state = "4x4"
	custom_color = "#4a5243"
	axis = /obj/structure/vehicleparts/axis/heavy/leopard
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks/right, /obj/structure/vehicleparts/frame/leopard/rf, /obj/item/ammo_magazine/mg3belt, /obj/item/ammo_magazine/mg3belt, /obj/item/ammo_magazine/mg3belt),
	"2,1" = list(/obj/structure/vehicleparts/frame/leopard/front),
	"3,1" = list(/obj/structure/vehicleparts/movement/tracks/left, /obj/structure/vehicleparts/frame/leopard/lf, /obj/structure/bed/chair/drivers/tank),

	"1,2" = list(/obj/structure/vehicleparts/frame/leopard/right),
	"2,2" = list(/obj/structure/vehicleparts/frame/leopard, /obj/structure/turret/leo2a6),
	"3,2" = list(/obj/structure/vehicleparts/frame/leopard/left),

	"1,3" = list(/obj/structure/vehicleparts/frame/leopard/right/door{doorcode = 5970}),
	"2,3" = list(/obj/structure/vehicleparts/frame/leopard),
	"3,3" = list(/obj/structure/vehicleparts/frame/leopard/left),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/left/reversed, /obj/structure/vehicleparts/frame/leopard/rb, /obj/structure/engine/internal/diesel/premade/v12),
	"2,4" = list(/obj/structure/vehicleparts/frame/leopard/back, /obj/structure/shellrack/full120),
	"3,4" = list(/obj/structure/vehicleparts/movement/tracks/right/reversed, /obj/structure/vehicleparts/frame/leopard/lb, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel)
	)

////////////APCS/////////////

/obj/effects/premadevehicles/apc

/obj/effects/premadevehicles/apc/mtlb
	name = "MT-LB"
	icon_state = "4x4"
	custom_color = "#4A5243"
	axis = /obj/structure/vehicleparts/axis/heavy/mtlb
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks/mtlb/right_front, /obj/structure/vehicleparts/frame/mtlb/rf, /obj/structure/turret/mtlb, /obj/item/ammo_magazine/pkm, /obj/item/ammo_magazine/pkm),
	"2,1" = list(/obj/structure/vehicleparts/movement/tracks/mtlb/left_front, /obj/structure/vehicleparts/frame/mtlb/lf, /obj/structure/bed/chair/drivers/tank),

	"1,2" = list(/obj/structure/vehicleparts/frame/mtlb/rfc, /obj/structure/engine/internal/diesel/premade/mtlb, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel),
	"2,2" = list(/obj/structure/vehicleparts/frame/mtlb/lfc),

	"1,3" = list(/obj/structure/vehicleparts/frame/mtlb/rbc),
	"2,3" = list(/obj/structure/vehicleparts/frame/mtlb/lbc),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/mtlb/right_back, /obj/structure/vehicleparts/frame/mtlb/rb),
	"2,4" = list(/obj/structure/vehicleparts/movement/tracks/mtlb/left_back, /obj/structure/vehicleparts/frame/mtlb/lb),
	)

/obj/effects/premadevehicles/apc/m113
	name = "M113"
	icon_state = "4x4"
	axis = /obj/structure/vehicleparts/axis/heavy/m113
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks/m113/right, /obj/structure/vehicleparts/frame/m113/rf, /obj/structure/engine/internal/diesel/premade/m113, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel),
	"2,1" = list(/obj/structure/vehicleparts/frame/m113/front, /obj/item/ammo_magazine/browning, /obj/item/ammo_magazine/browning, /obj/item/ammo_magazine/browning, /obj/item/ammo_magazine/browning, /obj/item/weapon/gun/projectile/automatic/stationary/browning),
	"3,1" = list(/obj/structure/vehicleparts/movement/tracks/m113/left, /obj/structure/bed/chair/drivers/tank, /obj/structure/vehicleparts/frame/m113/lf),

	"1,2" = list(/obj/structure/vehicleparts/frame/m113/rfc),
	"2,2" = list(/obj/structure/vehicleparts/frame/m113/fc, /obj/item/weapon/storage/toolbox/emergency),
	"3,2" = list(/obj/structure/vehicleparts/frame/m113/lfc),

	"1,3" = list(/obj/structure/vehicleparts/frame/m113/rbc),
	"2,3" = list(/obj/structure/vehicleparts/frame/m113/bc),
	"3,3" = list(/obj/structure/vehicleparts/frame/m113/lfc),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/m113/left/reversed, /obj/structure/vehicleparts/frame/m113/rb),
	"2,4" = list(/obj/structure/vehicleparts/frame/m113/back),
	"3,4" = list(/obj/structure/vehicleparts/movement/tracks/m113/right/reversed, /obj/structure/vehicleparts/frame/m113/lb),
	)

/obj/effects/premadevehicles/apc/bmd2
	name = "BMD-2"
	icon_state = "3x3"
	custom_color = "#4A5243"
	axis = /obj/structure/vehicleparts/axis/heavy/bmd2
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks/bmd2new/right_front, /obj/structure/vehicleparts/frame/bmd2/rf, /obj/structure/bed/chair/drivers/tank),
	"2,1" = list(/obj/structure/vehicleparts/movement/tracks/bmd2new/left_front, /obj/structure/vehicleparts/frame/bmd2/lf, /obj/structure/bed/chair/mgunner/pkm, /obj/item/ammo_magazine/pkm, /obj/item/ammo_magazine/pkm),

	"1,2" = list(/obj/structure/vehicleparts/frame/bmd2/rc, /obj/structure/turret/bmd2, /obj/item/ammo_magazine/a30mm_ap, /obj/item/ammo_magazine/a30mm_ap, /obj/item/ammo_magazine/a30mm_he, /obj/item/ammo_magazine/a30mm_he, /obj/structure/lamp/lamp_small/tank/red),
	"2,2" = list(/obj/structure/vehicleparts/frame/bmd2/lc),

	"1,3" = list(/obj/structure/vehicleparts/movement/tracks/bmd2new/right_back, /obj/structure/vehicleparts/frame/bmd2/rb, /obj/structure/engine/internal/diesel/premade/bmd2, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel),
	"2,3" = list(/obj/structure/vehicleparts/movement/tracks/bmd2new/left_back, /obj/structure/vehicleparts/frame/bmd2/lb),
	)

/obj/effects/premadevehicles/apc/ba64
	name = "Ba-64"
	icon_state = "3x3"
	custom_color = "#3d5931"
	axis = /obj/structure/vehicleparts/axis/car/ba64
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/armored, /obj/structure/vehicleparts/frame/su85/rf, /obj/item/ammo_magazine/maxim, /obj/item/ammo_magazine/maxim, /obj/item/ammo_magazine/maxim, /obj/item/ammo_magazine/maxim, /obj/item/weapon/gun/projectile/automatic/stationary/maxim/ww2),
	"2,1" = list(/obj/structure/vehicleparts/movement/armored/reversed, /obj/structure/vehicleparts/frame/su85/lf, /obj/structure/bed/chair/drivers/tank),

	"1,2" = list(/obj/structure/vehicleparts/frame/su85/right/door),
	"2,2" = list(/obj/structure/vehicleparts/frame/car/left/metalreinforced, /obj/item/weapon/storage/toolbox/emergency),

	"1,3" = list(/obj/structure/vehicleparts/movement/armored, /obj/structure/vehicleparts/frame/defaultarmored/rb, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel),
	"2,3" = list(/obj/structure/vehicleparts/movement/armored/reversed, /obj/structure/vehicleparts/frame/defaultarmored/lb, /obj/structure/engine/internal/diesel/premade/chiha),
	)

/obj/effects/premadevehicles/apc/btr80
	name = "BTR-80"
	icon_state = "2x4"
	custom_color = "#4A5243"
	axis = /obj/structure/vehicleparts/axis/heavy/btr80
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/armored/btr/right, /obj/structure/vehicleparts/frame/btr80/rf),
	"2,1" = list(/obj/structure/vehicleparts/movement/armored/btr/left, /obj/structure/vehicleparts/frame/btr80/lf, /obj/structure/bed/chair/drivers/tank, /obj/structure/radio/transmitter_receiver/nopower/tank/faction2),

	"1,2" = list(/obj/structure/vehicleparts/frame/btr80/rfc, /obj/structure/turret/btr80),
	"2,2" = list(/obj/structure/vehicleparts/frame/btr80/lfc, /obj/item/ammo_magazine/pkm, /obj/item/ammo_magazine/pkm),

	"1,3" = list(/obj/structure/vehicleparts/frame/btr80/rbc, /obj/structure/lamp/lamp_small/tank/red),
	"2,3" = list(/obj/structure/vehicleparts/frame/btr80/lbc, /obj/item/ammo_magazine/a30mm_ap/btr80, /obj/item/ammo_magazine/a30mm_ap/btr80, /obj/item/ammo_magazine/a30mm_he/btr80),

	"1,4" = list(/obj/structure/vehicleparts/movement/armored/btr/right/reversed, /obj/structure/vehicleparts/frame/btr80/rb, /obj/structure/engine/internal/diesel/premade/btr80, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel),
	"2,4" = list(/obj/structure/vehicleparts/movement/armored/btr/left/reversed, /obj/structure/vehicleparts/frame/btr80/lb),
	)

/obj/effects/premadevehicles/apc/cv90
	name = "CV90"
	icon_state = "4x4"
	custom_color = "#4A5243"
	axis = /obj/structure/vehicleparts/axis/heavy/cv90
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks/right, /obj/structure/vehicleparts/frame/cv90/rf),
	"2,1" = list(/obj/structure/vehicleparts/frame/cv90/front),
	"3,1" = list(/obj/structure/vehicleparts/movement/tracks/left, /obj/structure/vehicleparts/frame/cv90/lf, /obj/structure/bed/chair/drivers/tank),

	"1,2" = list(/obj/structure/vehicleparts/frame/cv90/right, /obj/structure/lamp/lamp_small/tank/red, /obj/item/ammo_magazine/a35mm_fap, /obj/item/ammo_magazine/a35mm_fap, /obj/item/ammo_magazine/a35mm_hei, /obj/item/ammo_magazine/a35mm_hei),
	"2,2" = list(/obj/structure/vehicleparts/frame/cv90, /obj/structure/turret/cv90),
	"3,2" = list(/obj/structure/vehicleparts/frame/cv90/left, /obj/item/ammo_magazine/m249, /obj/item/ammo_magazine/m249, /obj/item/ammo_magazine/m249),

	"1,3" = list(/obj/structure/vehicleparts/frame/cv90/right),
	"2,3" = list(/obj/structure/vehicleparts/frame/cv90),
	"3,3" = list(/obj/structure/vehicleparts/frame/cv90/left),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/left/reversed, /obj/structure/vehicleparts/frame/cv90/rb, /obj/structure/engine/internal/diesel/premade/btr80, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel),
	"2,4" = list(/obj/structure/vehicleparts/frame/cv90/back),
	"3,4" = list(/obj/structure/vehicleparts/movement/tracks/right/reversed, /obj/structure/vehicleparts/frame/cv90/lb),
	)

/obj/effects/premadevehicles/apc/bradley
	name = "M2 Bradley"
	icon_state = "4x4"
	custom_color = "#CCC0A6"
	axis = /obj/structure/vehicleparts/axis/heavy/bradley
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks/bradley/right_front, /obj/structure/vehicleparts/frame/bradley/rf, /obj/structure/engine/internal/diesel/premade/m113, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel),
	"2,1" = list(/obj/structure/vehicleparts/movement/tracks/bradley/left_front, /obj/structure/vehicleparts/frame/bradley/lf, /obj/structure/bed/chair/drivers/tank),

	"1,2" = list(/obj/structure/vehicleparts/frame/bradley/rfc),
	"2,2" = list(/obj/structure/vehicleparts/frame/bradley/lfc),

	"1,3" = list(/obj/structure/vehicleparts/frame/bradley/rbc, /obj/item/ammo_magazine/a25mm_ap/bradley, /obj/item/ammo_magazine/a25mm_ap/bradley, /obj/item/ammo_magazine/a25mm_he/bradley, /obj/item/ammo_magazine/a25mm_he/bradley, /obj/structure/turret/bradley),
	"2,3" = list(/obj/structure/vehicleparts/frame/bradley/lbc, /obj/item/ammo_magazine/m249, /obj/item/ammo_magazine/m249, /obj/item/ammo_magazine/m249),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/bradley/right_back, /obj/structure/vehicleparts/frame/bradley/rb, /obj/item/weapon/storage/toolbox/emergency),
	"2,4" = list(/obj/structure/vehicleparts/movement/tracks/bradley/left_back, /obj/structure/vehicleparts/frame/bradley/lb),
	)

/obj/effects/premadevehicles/apc/bradley/green
	custom_color = "#313831"

/obj/effects/premadevehicles/tank/bmv1
	name = "BMV-1 mk. I"
	icon_state = "3x3"
	custom_color = "#3d5931"
	axis = /obj/structure/vehicleparts/axis/heavy/bmv1_1
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/frame/bmv1/rf, /obj/structure/vehicleparts/movement/tracks/char1/right_front, /obj/structure/bed/chair/drivers/tank),
	"2,1" = list(/obj/structure/vehicleparts/frame/bmv1/front),
	"3,1" = list(/obj/structure/vehicleparts/frame/bmv1/lf, /obj/structure/vehicleparts/movement/tracks/char1/left_front, /obj/structure/bed/chair/mgunner/dt28, /obj/item/ammo_magazine/dp/dt, /obj/item/ammo_magazine/dp/dt, /obj/item/ammo_magazine/dp/dt, /obj/item/ammo_magazine/dp/dt, /obj/item/ammo_magazine/dp/dt, /obj/item/ammo_magazine/dp/dt),

	"1,2" = list(/obj/structure/vehicleparts/frame/bmv1/right/door),
	"2,2" = list(/obj/structure/vehicleparts/frame/bmv1/center, /obj/structure/turret/bmv1),
	"3,2" = list(/obj/structure/vehicleparts/frame/bmv1/left, /obj/structure/shellrack/full75),

	"1,3" = list(/obj/structure/vehicleparts/frame/bmv1/rb, /obj/structure/vehicleparts/movement/tracks/char1/right_back, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel, /obj/structure/engine/internal/diesel/premade/chiha),
	"2,3" = list(/obj/structure/vehicleparts/frame/bmv1/back, /obj/structure/shellrack/full75),
	"3,3" = list(/obj/structure/vehicleparts/frame/bmv1/lb, /obj/structure/vehicleparts/movement/tracks/char1/left_back, /obj/item/weapon/reagent_containers/food/drinks/teapot/filled)
	)

/obj/effects/premadevehicles/tank/smf1
	name = "SMF I mod. A"
	icon_state = "4x4"
	custom_color = "#555346"
	axis = /obj/structure/vehicleparts/axis/heavy/smf1_a
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/frame/smf1/rf, /obj/structure/vehicleparts/movement/tracks/t34/right_front, /obj/structure/bed/chair/mgunner/dt28),
	"2,1" = list(/obj/structure/vehicleparts/frame/smf1/front, /obj/item/ammo_magazine/dp/dt, /obj/item/ammo_magazine/dp/dt, /obj/item/ammo_magazine/dp/dt, /obj/item/ammo_magazine/dp/dt, /obj/item/ammo_magazine/dp/dt, /obj/item/ammo_magazine/dp/dt),
	"3,1" = list(/obj/structure/vehicleparts/frame/smf1/lf, /obj/structure/vehicleparts/movement/tracks/t34/left_front, /obj/structure/bed/chair/drivers/tank),

	"1,2" = list(/obj/structure/vehicleparts/frame/smf1/right, /obj/structure/shellrack/full75),
	"2,2" = list(/obj/structure/vehicleparts/frame/smf1/fc, /obj/structure/turret/smf1, /obj/structure/shellrack/full75),
	"3,2" = list(/obj/structure/vehicleparts/frame/smf1/left),

	"1,3" = list(/obj/structure/vehicleparts/frame/smf1/right/door),
	"2,3" = list(/obj/structure/vehicleparts/frame/smf1/bc),
	"3,3" = list(/obj/structure/vehicleparts/frame/smf1/left/door),

	"1,4" = list(/obj/structure/vehicleparts/frame/smf1/rb, /obj/structure/vehicleparts/movement/tracks/t34/right_back, /obj/structure/engine/internal/diesel/premade/chiha, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel),
	"2,4" = list(/obj/structure/vehicleparts/frame/smf1/back),
	"3,4" = list(/obj/structure/vehicleparts/frame/smf1/lb, /obj/structure/vehicleparts/movement/tracks/t34/left_back, /obj/structure/shellrack/full75)
	)