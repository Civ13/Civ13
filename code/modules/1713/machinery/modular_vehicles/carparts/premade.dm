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
			if (map.ID == MAP_CAMPAIGN && !istype(src, /obj/effects/premadevehicles/tank))
				var/rangeto = range(2,autoassembler_loc)
				for (var/obj/structure/vehicleparts/frame/A in rangeto)
					A.w_front[7] = TRUE
					A.w_back[7] = TRUE
					A.w_left[7] = TRUE
					A.w_right[7] = TRUE
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
	"1,1" = list(/obj/item/weapon/reagent_containers/glass/barrel/fueltank/smalltank/fueledgasoline,/obj/structure/vehicleparts/movement,/obj/structure/vehicleparts/frame/car/piccolino/rf),
	"2,1" = list(/obj/structure/vehicleparts/frame/car/piccolino/lf,/obj/structure/engine/internal/gasoline/ethanol/premade/piccolino,/obj/structure/vehicleparts/movement,/obj/structure/vehicleparts/license_plate/eu/centered/front),

	"1,2" = list(/obj/structure/bed/chair/carseat/right,/obj/structure/vehicleparts/frame/car/piccolino/rc),
	"2,2" = list(/obj/structure/bed/chair/drivers/car,/obj/structure/vehicleparts/frame/car/piccolino/lc),

	"1,3" = list(/obj/structure/table/carboot,/obj/structure/vehicleparts/frame/car/piccolino/rb,/obj/structure/vehicleparts/movement/reversed),
	"2,3" = list(/obj/structure/table/carboot,/obj/structure/vehicleparts/frame/car/piccolino/lb,/obj/structure/vehicleparts/movement/reversed,/obj/structure/vehicleparts/license_plate/eu/centered),
	)

/obj/effects/premadevehicles/asno/quattroporte
	name = "ASNO Quattroporte"
	icon_state = "3x3"
	custom_color = "#076007"
	axis = /obj/structure/vehicleparts/axis/car/quattroporte
	tocreate = list(
	"1,1" = list(/obj/item/weapon/reagent_containers/glass/barrel/fueltank/smalltank/fueledgasoline,/obj/structure/vehicleparts/movement,/obj/structure/vehicleparts/frame/car/quattroporte/rf),
	"2,1" = list(/obj/structure/vehicleparts/frame/car/quattroporte/lf,/obj/structure/engine/internal/gasoline/premade/quattroporte,/obj/structure/vehicleparts/movement,/obj/structure/vehicleparts/license_plate/eu/centered/front),

	"1,2" = list(/obj/structure/bed/chair/carseat/right,/obj/structure/vehicleparts/frame/car/quattroporte/rc),
	"2,2" = list(/obj/structure/bed/chair/drivers/car,/obj/structure/vehicleparts/frame/car/quattroporte/lc),
	
	"1,3" = list(/obj/structure/bed/chair/carseat/right,/obj/structure/vehicleparts/frame/car/quattroporte/rb,/obj/structure/vehicleparts/movement/reversed),
	"2,3" = list(/obj/structure/bed/chair/carseat/left,/obj/structure/vehicleparts/frame/car/quattroporte/lb,/obj/structure/vehicleparts/license_plate/eu/centered,/obj/structure/vehicleparts/movement/reversed),
	)
//Ubermacht
/obj/effects/premadevehicles/ubermacht/erstenklasse
	name = "Ubermacht Erstenklasse"
	icon_state = "4x4"
	custom_color = "#1b1f1b"
	axis = /obj/structure/vehicleparts/axis/car/erstenklasse
	tocreate = list(
	"1,1" = list(/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueled,/obj/structure/vehicleparts/movement,/obj/structure/vehicleparts/frame/car/umek/rf),
	"2,1" = list(/obj/structure/vehicleparts/frame/car/umek/lf,/obj/structure/engine/internal/diesel/premade/erstenklasse,/obj/structure/vehicleparts/movement,/obj/structure/vehicleparts/license_plate/eu/centered/front),

	"1,2" = list(/obj/structure/vehicleparts/frame/car/umek/rfc,/obj/structure/bed/chair/carseat/right/lion),
	"2,2" = list(/obj/structure/vehicleparts/frame/car/umek/lfc,/obj/structure/bed/chair/drivers/car/lion),

	"1,3" = list(/obj/structure/vehicleparts/frame/car/umek/rbc,/obj/structure/bed/chair/carseat/right/lion),
	"2,3" = list(/obj/structure/vehicleparts/frame/car/umek/lbc,/obj/structure/bed/chair/carseat/left/lion),

	"1,4" = list(/obj/structure/vehicleparts/frame/car/umek/rb,/obj/structure/table/carboot,/obj/structure/vehicleparts/movement/reversed),
	"2,4" = list(/obj/structure/vehicleparts/frame/car/umek/lb,/obj/structure/table/carboot,/obj/structure/vehicleparts/movement/reversed),
	)

//SMC
//falcon
/obj/effects/premadevehicles/smc/falcon
	name = "SMC Falcon"
	icon_state = "4x4"
	custom_color = "#1b1f1b"
	axis = /obj/structure/vehicleparts/axis/car/falcon
	tocreate = list(
	"1,1" = list(/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueledgasoline,/obj/structure/vehicleparts/movement,/obj/structure/vehicleparts/frame/car/falcon/rf),
	"2,1" = list(/obj/structure/vehicleparts/frame/car/falcon/lf,/obj/structure/engine/internal/gasoline/premade/falcon,/obj/structure/vehicleparts/movement,/obj/structure/vehicleparts/license_plate/us/centered/front),

	"1,2" = list(/obj/structure/vehicleparts/frame/car/falcon/rfc,/obj/structure/bed/chair/carseat/right),
	"2,2" = list(/obj/structure/vehicleparts/frame/car/falcon/lfc,/obj/structure/bed/chair/drivers/car,),

	"1,3" = list(/obj/structure/vehicleparts/frame/car/falcon/rbc,/obj/structure/bed/chair/carseat/right),
	"2,3" = list(/obj/structure/vehicleparts/frame/car/falcon/lbc,/obj/structure/bed/chair/carseat/left),

	"1,4" = list(/obj/structure/vehicleparts/frame/car/falcon/rb,/obj/structure/table/carboot,/obj/structure/vehicleparts/movement/reversed),
	"2,4" = list(/obj/structure/vehicleparts/frame/car/falcon/lb,/obj/structure/table/carboot,/obj/structure/vehicleparts/movement/reversed,/obj/structure/vehicleparts/license_plate/us/centered),
	)

/obj/effects/premadevehicles/smc/falcon/unmarked
	name = "SMC Falcon"
	icon_state = "4x4"
	custom_color = "#13161c"
	axis = /obj/structure/vehicleparts/axis/car/falcon/police
	tocreate = list(
	"1,1" = list(/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueledgasoline,/obj/structure/vehicleparts/movement,/obj/structure/vehicleparts/frame/car/falcon/rf),
	"2,1" = list(/obj/structure/vehicleparts/frame/car/falcon/lf,/obj/structure/engine/internal/gasoline/premade/falcon,/obj/structure/vehicleparts/movement,/obj/structure/vehicleparts/license_plate/us/centered/front),

	"1,2" = list(/obj/structure/vehicleparts/frame/car/falcon/rfc,/obj/structure/bed/chair/carseat/right),
	"2,2" = list(/obj/structure/vehicleparts/frame/car/falcon/lfc,/obj/structure/bed/chair/drivers/car,/obj/structure/emergency_lights/police2),

	"1,3" = list(/obj/structure/vehicleparts/frame/car/falcon/rbc,/obj/structure/bed/chair/carseat/right),
	"2,3" = list(/obj/structure/vehicleparts/frame/car/falcon/lbc,/obj/structure/bed/chair/carseat/left),

	"1,4" = list(/obj/structure/vehicleparts/frame/car/falcon/rb,/obj/structure/table/carboot,/obj/structure/vehicleparts/movement/reversed),
	"2,4" = list(/obj/structure/vehicleparts/frame/car/falcon/lb,/obj/structure/table/carboot,/obj/structure/vehicleparts/movement/reversed,/obj/structure/vehicleparts/license_plate/us/centered),
	)

/obj/effects/premadevehicles/smc/wyoming
	name = "SMC Wyoming"
	icon_state = "4x4"
	custom_color = "#392f92"
	axis = /obj/structure/vehicleparts/axis/car/wyoming
	tocreate = list(
	"1,1" = list(/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueled,/obj/structure/vehicleparts/movement,/obj/structure/vehicleparts/frame/car/wyoming/rf),
	"2,1" = list(/obj/structure/vehicleparts/frame/car/wyoming/lf,/obj/structure/engine/internal/diesel/premade/wyoming,/obj/structure/vehicleparts/movement,/obj/structure/vehicleparts/license_plate/us/centered/front),

	"1,2" = list(/obj/structure/vehicleparts/frame/car/wyoming/rfc,/obj/structure/bed/chair/carseat/right),
	"2,2" = list(/obj/structure/vehicleparts/frame/car/wyoming/lfc,/obj/structure/bed/chair/drivers/car),

	"1,3" = list(/obj/structure/vehicleparts/frame/car/wyoming/rbc),
	"2,3" = list(/obj/structure/vehicleparts/frame/car/wyoming/lbc),

	"1,4" = list(/obj/structure/vehicleparts/frame/car/wyoming/rb,/obj/structure/vehicleparts/movement/reversed),
	"2,4" = list(/obj/structure/vehicleparts/frame/car/wyoming/lb,/obj/structure/vehicleparts/movement/reversed,/obj/structure/vehicleparts/license_plate/us/centered),
	)
//Yamasaki
//Shinobu
/obj/effects/premadevehicles/yamasaki/shinobu
	name = "Yamasaki Shinobu 5000"
	icon_state = "4x4"
	custom_color = "#7F0000"
	axis = /obj/structure/vehicleparts/axis/car/shinobu
	tocreate = list(
	"1,1" = list(/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueledgasoline,/obj/structure/vehicleparts/movement,/obj/structure/vehicleparts/frame/car/shinobu/rf),
	"2,1" = list(/obj/structure/vehicleparts/frame/car/shinobu/lf,/obj/structure/engine/internal/gasoline/wankel/premade/shinobu,/obj/structure/vehicleparts/movement,/obj/structure/vehicleparts/license_plate/eu/centered/front),

	"1,2" = list(/obj/structure/vehicleparts/frame/car/shinobu/rcf,/obj/structure/bed/chair/carseat/right),
	"2,2" = list(/obj/structure/vehicleparts/frame/car/shinobu/lcf,/obj/structure/bed/chair/drivers/car,),

	"1,3" = list(/obj/structure/vehicleparts/frame/car/shinobu/rbc,/obj/structure/bed/chair/carseat/right),
	"2,3" = list(/obj/structure/vehicleparts/frame/car/shinobu/lbc,/obj/structure/bed/chair/carseat/left),

	"1,4" = list(/obj/structure/vehicleparts/frame/car/shinobu/rb,/obj/structure/table/carboot,/obj/structure/vehicleparts/movement/reversed),
	"2,4" = list(/obj/structure/vehicleparts/frame/car/shinobu/lb,/obj/structure/table/carboot,/obj/structure/vehicleparts/movement/reversed,/obj/structure/vehicleparts/license_plate/eu/centered),
	)
//Shinobu interceptor

/obj/effects/premadevehicles/yamasaki/shinobu/police
	name = "Yamasaki Police Interceptor Shinobu"
	icon_state = "4x4"
	custom_color = "#383838"
	axis = /obj/structure/vehicleparts/axis/car/shinobu/police
	tocreate = list(
	"1,1" = list(/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueledgasoline,/obj/structure/vehicleparts/movement,/obj/structure/vehicleparts/frame/car/shinobu/rf),
	"2,1" = list(/obj/structure/vehicleparts/frame/car/shinobu/lf,/obj/structure/engine/internal/gasoline/wankel/premade/shinobu,/obj/structure/vehicleparts/movement,/obj/structure/vehicleparts/license_plate/us/centered/front),

	"1,2" = list(/obj/structure/vehicleparts/frame/car/shinobu/rcf,/obj/structure/bed/chair/carseat/right/dark),
	"2,2" = list(/obj/structure/vehicleparts/frame/car/shinobu/lcf,/obj/structure/bed/chair/drivers/car/dark,/obj/structure/emergency_lights),

	"1,3" = list(/obj/structure/vehicleparts/frame/car/shinobu/rbc,/obj/structure/bed/chair/carseat/right/dark),
	"2,3" = list(/obj/structure/vehicleparts/frame/car/shinobu/lbc,/obj/structure/bed/chair/carseat/left/dark),

	"1,4" = list(/obj/structure/vehicleparts/frame/car/shinobu/rb,/obj/structure/table/carboot,/obj/structure/vehicleparts/movement/reversed,/obj/item/weapon/storage/toolbox/emergency),
	"2,4" = list(/obj/structure/vehicleparts/frame/car/shinobu/lb,/obj/structure/table/carboot,/obj/structure/vehicleparts/movement/reversed,/obj/structure/vehicleparts/license_plate/us/centered,/obj/item/weapon/trafficcone,/obj/item/weapon/trafficcone,/obj/item/weapon/trafficcone,/obj/item/weapon/reagent_containers/glass/barrel/jerrycan/gasoline),
	)
//Kazoku
/obj/effects/premadevehicles/yamasaki/kazoku
	name = "Yamasaki Kazoku"
	icon_state = "3x3"
	custom_color = "#3b3a3a"
	axis = /obj/structure/vehicleparts/axis/car/kazoku
	tocreate = list(
	"1,1" = list(/obj/item/weapon/reagent_containers/glass/barrel/fueltank/smalltank/fueledgasoline,/obj/structure/vehicleparts/movement,/obj/structure/vehicleparts/frame/car/kazoku/rf),
	"2,1" = list(/obj/structure/vehicleparts/frame/car/kazoku/lf,/obj/structure/engine/internal/gasoline/premade/kazoku,/obj/structure/vehicleparts/movement,/obj/structure/vehicleparts/license_plate/eu/centered/front),

	"1,2" = list(/obj/structure/bed/chair/carseat/right,/obj/structure/vehicleparts/frame/car/kazoku/rc),
	"2,2" = list(/obj/structure/bed/chair/drivers/car,/obj/structure/vehicleparts/frame/car/kazoku/lc),

	
	"1,3" = list(/obj/structure/bed/chair/carseat/right,/obj/structure/vehicleparts/frame/car/kazoku/rb,/obj/structure/vehicleparts/movement/reversed),
	"2,3" = list(/obj/structure/bed/chair/carseat/left,/obj/structure/vehicleparts/frame/car/kazoku/lb,/obj/structure/vehicleparts/license_plate/eu/centered,/obj/structure/vehicleparts/movement/reversed),
	)
//Kurogane Type 95
/obj/effects/premadevehicles/kurogane/type95
	name = "Kurogane type 95"
	icon_state = "3x3"
	custom_color = "#736953"
	axis = /obj/structure/vehicleparts/axis/car/type95
	tocreate = list(
	"1,1" = list(/obj/item/weapon/reagent_containers/glass/barrel/fueltank/smalltank/fueledgasoline,/obj/structure/vehicleparts/movement,/obj/structure/vehicleparts/frame/car/type95/rf),
	"2,1" = list(/obj/structure/vehicleparts/frame/car/type95/lf,/obj/structure/engine/internal/gasoline/premade/type95,/obj/structure/vehicleparts/movement),

	"1,2" = list(/obj/structure/bed/chair/drivers/car/type95,/obj/structure/vehicleparts/frame/car/type95/rc),
	"2,2" = list(/obj/structure/bed/chair/carseat/left/type95,/obj/structure/vehicleparts/frame/car/type95/lc),

	"1,3" = list(/obj/structure/bed/chair/carseat/right/type95,/obj/structure/vehicleparts/frame/car/type95/rb,/obj/structure/vehicleparts/movement/reversed),
	"2,3" = list(/obj/structure/bed/chair/carseat/left/type95,/obj/structure/vehicleparts/frame/car/type95/lb,/obj/structure/vehicleparts/movement/reversed),
	)
///////////////////////////////////////////////JEEPS///////////////////////////////////////////////////////
/obj/effects/premadevehicles/jeep

//Dutch Jeep
/obj/effects/premadevehicles/truck/mercedes
	name = "Mercedes-Benz G280"
	icon_state = "3x3"
	custom_color = "#45453b"
	axis = /obj/structure/vehicleparts/axis/car/mercedes
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/frame/car/rf/armored,/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueled{density = 0},/obj/structure/vehicleparts/movement/armored),
	"2,1" = list(/obj/structure/vehicleparts/frame/car/lf/armored,/obj/structure/engine/internal/diesel/premade/v6,/obj/structure/vehicleparts/movement/armored/reversed,/obj/structure/vehicleparts/license_plate/nl/centered/front),

	"1,2" = list(/obj/structure/vehicleparts/frame/car/rf/truck/armored,/obj/structure/bed/chair/office/dark),
	"2,2" = list(/obj/structure/vehicleparts/frame/car/lf/truck/armored,/obj/structure/bed/chair/drivers),

	"1,3" = list(/obj/structure/vehicleparts/frame/car/rb/armored,/obj/structure/bed/chair/office/dark,/obj/structure/vehicleparts/movement/armored/reversed),
	"2,3" = list(/obj/structure/vehicleparts/frame/car/lb/armored,/obj/structure/bed/chair/office/dark,/obj/structure/vehicleparts/movement/armored/reversed,/obj/structure/vehicleparts/license_plate/nl/centered),
	)
/obj/effects/premadevehicles/truck/mercedes/mg
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/frame/car/rf/armored,/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueled{density = 0},/obj/structure/vehicleparts/movement/armored),
	"2,1" = list(/obj/structure/vehicleparts/frame/car/lf/armored,/obj/structure/engine/internal/diesel/premade/v6,/obj/structure/vehicleparts/movement/armored/reversed,/obj/structure/vehicleparts/license_plate/nl/centered/front),

	"1,2" = list(/obj/structure/vehicleparts/frame/car/rf/truck/armored,/obj/structure/bed/chair/office/dark,/obj/item/weapon/gun/projectile/automatic/stationary/modern/m2browning),
	"2,2" = list(/obj/structure/vehicleparts/frame/car/lf/truck/armored,/obj/structure/bed/chair/drivers),

	"1,3" = list(/obj/structure/vehicleparts/frame/car/rb/armored,/obj/structure/bed/chair/office/dark,/obj/structure/vehicleparts/movement/armored/reversed,/obj/item/ammo_magazine/a50cal_can,/obj/item/ammo_magazine/a50cal_can,/obj/item/ammo_magazine/a50cal_can),
	"2,3" = list(/obj/structure/vehicleparts/frame/car/lb/armored,/obj/structure/bed/chair/office/dark,/obj/structure/vehicleparts/movement/armored/reversed,/obj/structure/vehicleparts/license_plate/nl/centered),
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
	"1,1" = list(/obj/structure/vehicleparts/frame/car/rf/armored,/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueledgasoline,/obj/structure/vehicleparts/movement),
	"2,1" = list(/obj/structure/vehicleparts/frame/car/lf/armored,/obj/structure/engine/internal/gasoline/premade/v6,/obj/structure/vehicleparts/movement,/obj/structure/vehicleparts/license_plate/nl/centered/front),

	"1,2" = list(/obj/structure/vehicleparts/frame/car/rf/truck/armored,/obj/structure/bed/chair/office/dark),
	"2,2" = list(/obj/structure/vehicleparts/frame/car/lf/truck/armored,/obj/structure/bed/chair/drivers),

	"1,3" = list(/obj/structure/vehicleparts/frame/car/right/armored),
	"2,3" = list(/obj/structure/vehicleparts/frame/car/left/armored),

	"1,4" = list(/obj/structure/vehicleparts/frame/car/right/armored,/obj/structure/vehicleparts/movement/reversed),
	"2,4" = list(/obj/structure/vehicleparts/frame/car/left/armored,/obj/structure/vehicleparts/movement/reversed,/obj/structure/vehicleparts/license_plate/nl/centered),
	)

//Russian Truck
/obj/effects/premadevehicles/truck/kamaz
	name = "KamAZ-4350 Truck"
	icon_state = "4x4"
	custom_color = "#45453b"
	axis = /obj/structure/vehicleparts/axis/car/kamaz
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/frame/car/rf/armored,/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueledgasoline,/obj/structure/vehicleparts/movement),
	"2,1" = list(/obj/structure/vehicleparts/frame/car/lf/armored,/obj/structure/engine/internal/gasoline/premade/v6,/obj/structure/vehicleparts/movement,/obj/structure/vehicleparts/license_plate/eu/centered/front),

	"1,2" = list(/obj/structure/vehicleparts/frame/car/rf/truck/armored,/obj/structure/bed/chair/office/dark),
	"2,2" = list(/obj/structure/vehicleparts/frame/car/lf/truck/armored,/obj/structure/bed/chair/drivers),

	"1,3" = list(/obj/structure/vehicleparts/frame/car/right/armored),
	"2,3" = list(/obj/structure/vehicleparts/frame/car/left/armored),

	"1,4" = list(/obj/structure/vehicleparts/frame/car/right/armored,/obj/structure/vehicleparts/movement/reversed),
	"2,4" = list(/obj/structure/vehicleparts/frame/car/left/armored,/obj/structure/vehicleparts/movement/reversed,/obj/structure/vehicleparts/license_plate/eu/centered),
	)

///////////////////////////////////////////////TANKS///////////////////////////////////////////////////////
/obj/effects/premadevehicles/tank

/obj/effects/premadevehicles/tank/panzeriv
	name = "Panzer IV"
	icon_state = "4x4"
	custom_color = "#585A5C"
	axis = /obj/structure/vehicleparts/axis/heavy/panzeriv
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks,/obj/structure/vehicleparts/frame/panzeriv/rf,/obj/item/ammo_magazine/mg34belt,/obj/item/ammo_magazine/mg34belt,/obj/item/ammo_magazine/mg34belt,/obj/item/ammo_magazine/mg34belt,/obj/item/weapon/gun/projectile/automatic/stationary/modern/mg34),
	"2,1" = list(/obj/structure/vehicleparts/frame/panzeriv/front,/obj/item/weapon/storage/toolbox/emergency),
	"3,1" = list(/obj/structure/vehicleparts/movement/tracks,/obj/structure/vehicleparts/frame/panzeriv/lf, /obj/structure/bed/chair/drivers/tank),

	"1,2" = list(/obj/structure/vehicleparts/frame/panzeriv/right, /obj/structure/bed/chair/commander),
	"2,2" = list(/obj/structure/vehicleparts/frame/panzeriv,/obj/structure/cannon/modern/tank/german75),
	"3,2" = list(/obj/structure/vehicleparts/frame/panzeriv/left, /obj/structure/bed/chair/gunner),

	"1,3" = list(/obj/structure/vehicleparts/frame/panzeriv/right/door),
	"2,3" = list(/obj/structure/vehicleparts/frame/panzeriv, /obj/structure/bed/chair/loader),
	"3,3" = list(/obj/structure/vehicleparts/frame/panzeriv/left/door,),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/reversed,/obj/structure/vehicleparts/frame/panzeriv/rb, /obj/structure/engine/internal/gasoline/premade/panzeriv),
	"2,4" = list(/obj/structure/vehicleparts/frame/panzeriv/back, /obj/structure/shellrack/full75),
	"3,4" = list(/obj/structure/vehicleparts/movement/tracks/reversed,/obj/structure/vehicleparts/frame/panzeriv/lb,/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueledgasoline),
	)

/obj/effects/premadevehicles/tank/omw22_2
	name = "OMW-22 mk. II"
	icon_state = "4x4"
	custom_color = "#774D4C"
	axis = /obj/structure/vehicleparts/axis/heavy/omw22_2
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks/right,/obj/structure/vehicleparts/frame/omw22_2/rf,/obj/structure/lamp/lamp_small/tank/floodlight),
	"2,1" = list(/obj/structure/vehicleparts/frame/omw22_2/front, /obj/structure/bed/chair/drivers/tank,),
	"3,1" = list(/obj/structure/vehicleparts/movement/tracks/left,/obj/structure/vehicleparts/frame/omw22_2/lf,/obj/item/ammo_magazine/pkm,/obj/item/ammo_magazine/pkm,/obj/item/ammo_magazine/pkm,/obj/item/ammo_magazine/pkm,/obj/item/weapon/gun/projectile/automatic/stationary/modern/pkm,/obj/structure/lamp/lamp_small/tank/floodlight),

	"1,2" = list(/obj/structure/vehicleparts/frame/omw22_2/right, /obj/structure/bed/chair/commander),
	"2,2" = list(/obj/structure/vehicleparts/frame/omw22_2,/obj/structure/cannon/modern/tank/omwtc10),
	"3,2" = list(/obj/structure/vehicleparts/frame/omw22_2/left, /obj/structure/bed/chair/loader),

	"1,3" = list(/obj/structure/vehicleparts/frame/omw22_2/right/door,/obj/item/weapon/storage/toolbox/emergency),
	"2,3" = list(/obj/structure/vehicleparts/frame/omw22_2, /obj/structure/bed/chair/gunner),
	"3,3" = list(/obj/structure/vehicleparts/frame/omw22_2/left,/obj/structure/shellrack/full100),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/left/reversed,/obj/structure/vehicleparts/frame/omw22_2/rb),
	"2,4" = list(/obj/structure/vehicleparts/frame/omw22_2/back,/obj/structure/engine/internal/diesel/premade/omw22_2,/obj/structure/lamp/lamp_small/tank/red),
	"3,4" = list(/obj/structure/vehicleparts/movement/tracks/right/reversed,/obj/structure/vehicleparts/frame/omw22_2/lb,/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueled),
	)

/obj/effects/premadevehicles/tank/baf1_a
	name = "BAF I mod. A"
	icon_state = "4x4"
	custom_color = "#8383C2"
	axis = /obj/structure/vehicleparts/axis/heavy/baf1_a
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks/right,/obj/structure/vehicleparts/frame/baf1_a/rf,/obj/structure/lamp/lamp_small/tank/floodlight,/obj/structure/bed/chair/drivers/tank),
	"2,1" = list(/obj/structure/vehicleparts/frame/baf1_a/front, /obj/structure/bed/chair/commander),
	"3,1" = list(/obj/structure/vehicleparts/movement/tracks/left,/obj/structure/vehicleparts/frame/baf1_a/lf,/obj/item/ammo_magazine/pkm,/obj/item/ammo_magazine/pkm,/obj/item/ammo_magazine/pkm,/obj/item/ammo_magazine/pkm,/obj/item/weapon/gun/projectile/automatic/stationary/modern/pkm,/obj/structure/lamp/lamp_small/tank/floodlight),

	"1,2" = list(/obj/structure/vehicleparts/frame/baf1_a/right),
	"2,2" = list(/obj/structure/vehicleparts/frame/baf1_a,/obj/structure/cannon/modern/tank/baftkn75),
	"3,2" = list(/obj/structure/vehicleparts/frame/baf1_a/left, /obj/structure/bed/chair/loader),

	"1,3" = list(/obj/structure/vehicleparts/frame/baf1_a/right/door,/obj/item/weapon/storage/toolbox/emergency),
	"2,3" = list(/obj/structure/vehicleparts/frame/baf1_a/center_back, /obj/structure/bed/chair/gunner),
	"3,3" = list(/obj/structure/vehicleparts/frame/baf1_a/left/door),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/left/reversed,/obj/structure/vehicleparts/frame/baf1_a/rb,/obj/structure/engine/internal/gasoline/premade/baf1_a),
	"2,4" = list(/obj/structure/vehicleparts/frame/baf1_a/back,/obj/structure/lamp/lamp_small/tank/red,/obj/structure/shellrack/full75),
	"3,4" = list(/obj/structure/vehicleparts/movement/tracks/right/reversed,/obj/structure/vehicleparts/frame/baf1_a/lb,/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueledgasoline),
	)

/obj/effects/premadevehicles/tank/chiha
	name = "Type 97 Chi-Ha"
	icon_state = "4x4"
	custom_color = "#6a5a3d"
	axis = /obj/structure/vehicleparts/axis/heavy/chi_ha
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks,/obj/structure/vehicleparts/frame/chi_ha/rf,/obj/item/ammo_magazine/type92,/obj/item/ammo_magazine/type92,/obj/item/ammo_magazine/type92,/obj/item/ammo_magazine/type92,/obj/item/ammo_magazine/type92,/obj/item/weapon/gun/projectile/automatic/stationary/modern/type98),
	"2,1" = list(/obj/structure/vehicleparts/frame/chi_ha/front,/obj/item/weapon/storage/toolbox/emergency),
	"3,1" = list(/obj/structure/vehicleparts/movement/tracks,/obj/structure/vehicleparts/frame/chi_ha/lf, /obj/structure/bed/chair/drivers/tank),

	"1,2" = list(/obj/structure/vehicleparts/frame/chi_ha/right, /obj/structure/bed/chair/commander),
	"2,2" = list(/obj/structure/vehicleparts/frame/chi_ha,/obj/structure/cannon/modern/tank/japanese57),
	"3,2" = list(/obj/structure/vehicleparts/frame/chi_ha/left, /obj/structure/bed/chair/gunner),

	"1,3" = list(/obj/structure/vehicleparts/frame/chi_ha/right/door),
	"2,3" = list(/obj/structure/vehicleparts/frame/chi_ha, /obj/structure/bed/chair/loader),
	"3,3" = list(/obj/structure/vehicleparts/frame/chi_ha/left/door,),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/reversed,/obj/structure/vehicleparts/frame/chi_ha/rb, /obj/structure/engine/internal/diesel/premade/chiha, /obj/item/ammo_magazine/type92,/obj/item/ammo_magazine/type92,/obj/item/ammo_magazine/type92,/obj/item/ammo_magazine/type92,/obj/item/ammo_magazine/type92,/obj/item/weapon/gun/projectile/automatic/stationary/modern/type98),
	"2,4" = list(/obj/structure/vehicleparts/frame/chi_ha/back, /obj/structure/shellrack/full57),
	"3,4" = list(/obj/structure/vehicleparts/movement/tracks/reversed,/obj/structure/vehicleparts/frame/chi_ha/lb,/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueled)
	)

/obj/effects/premadevehicles/tank/t34
	name = "T34"
	icon_state = "4x4"
	custom_color = "#3d5931"
	axis = /obj/structure/vehicleparts/axis/heavy/t34
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks,/obj/structure/vehicleparts/frame/t34/rf,/obj/item/ammo_magazine/maxim,/obj/item/ammo_magazine/maxim,/obj/item/ammo_magazine/maxim,/obj/item/ammo_magazine/maxim,/obj/item/weapon/gun/projectile/automatic/stationary/modern/maxim/ww2),
	"2,1" = list(/obj/structure/vehicleparts/frame/t34/front,/obj/item/weapon/storage/toolbox/emergency),
	"3,1" = list(/obj/structure/vehicleparts/movement/tracks,/obj/structure/vehicleparts/frame/t34/lf, /obj/structure/bed/chair/drivers/tank),

	"1,2" = list(/obj/structure/vehicleparts/frame/t34/right, /obj/structure/bed/chair/commander),
	"2,2" = list(/obj/structure/vehicleparts/frame/t34,/obj/structure/cannon/modern/tank/russian76),
	"3,2" = list(/obj/structure/vehicleparts/frame/t34/left, /obj/structure/bed/chair/gunner),

	"1,3" = list(/obj/structure/vehicleparts/frame/t34/right/door),
	"2,3" = list(/obj/structure/vehicleparts/frame/t34, /obj/structure/bed/chair/loader),
	"3,3" = list(/obj/structure/vehicleparts/frame/t34/left/door,),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/reversed,/obj/structure/vehicleparts/frame/t34/rb, /obj/structure/engine/internal/diesel/premade/chiha),
	"2,4" = list(/obj/structure/vehicleparts/frame/t34/back, /obj/structure/shellrack/full76),
	"3,4" = list(/obj/structure/vehicleparts/movement/tracks/reversed,/obj/structure/vehicleparts/frame/t34/lb,/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueled)
	)

/obj/effects/premadevehicles/tank/kv1
	name = "KV-1A"
	icon_state = "4x4"
	custom_color = "#3d5931"
	axis = /obj/structure/vehicleparts/axis/heavy/kv1a
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks,/obj/structure/vehicleparts/frame/kv1/rf,/obj/item/ammo_magazine/maxim,/obj/item/ammo_magazine/maxim,/obj/item/ammo_magazine/maxim,/obj/item/ammo_magazine/maxim,/obj/item/weapon/gun/projectile/automatic/stationary/modern/maxim/ww2),
	"2,1" = list(/obj/structure/vehicleparts/frame/kv1/front,/obj/item/weapon/storage/toolbox/emergency),
	"3,1" = list(/obj/structure/vehicleparts/movement/tracks,/obj/structure/vehicleparts/frame/kv1/lf, /obj/structure/bed/chair/drivers/tank),

	"1,2" = list(/obj/structure/vehicleparts/frame/kv1/right, /obj/structure/bed/chair/commander),
	"2,2" = list(/obj/structure/vehicleparts/frame/kv1,/obj/structure/cannon/modern/tank/russian85/kv1),
	"3,2" = list(/obj/structure/vehicleparts/frame/kv1/left, /obj/structure/bed/chair/gunner),

	"1,3" = list(/obj/structure/vehicleparts/frame/kv1/right/door),
	"2,3" = list(/obj/structure/vehicleparts/frame/kv1, /obj/structure/bed/chair/loader),
	"3,3" = list(/obj/structure/vehicleparts/frame/kv1/left/door,),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/reversed,/obj/structure/vehicleparts/frame/kv1/rb, /obj/structure/engine/internal/diesel/premade/chiha),
	"2,4" = list(/obj/structure/vehicleparts/frame/kv1/back, /obj/structure/shellrack/full85),
	"3,4" = list(/obj/structure/vehicleparts/movement/tracks/reversed,/obj/structure/vehicleparts/frame/kv1/lb,/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueled)
	)

/obj/effects/premadevehicles/tank/m4
	name = "M4-Sherman"
	icon_state = "4x4"
	custom_color = "#293822"
	axis = /obj/structure/vehicleparts/axis/heavy/m4
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks,/obj/structure/vehicleparts/frame/m4/rf,/obj/item/ammo_magazine/browning,/obj/item/ammo_magazine/browning,/obj/item/ammo_magazine/browning,/obj/item/ammo_magazine/browning,/obj/item/weapon/gun/projectile/automatic/stationary/modern/browning),
	"2,1" = list(/obj/structure/vehicleparts/frame/m4/front,/obj/item/weapon/storage/toolbox/emergency),
	"3,1" = list(/obj/structure/vehicleparts/movement/tracks,/obj/structure/vehicleparts/frame/m4/lf, /obj/structure/bed/chair/drivers/tank),

	"1,2" = list(/obj/structure/vehicleparts/frame/m4/right, /obj/structure/bed/chair/commander),
	"2,2" = list(/obj/structure/vehicleparts/frame/m4,/obj/structure/shellrack/full75/american),
	"3,2" = list(/obj/structure/vehicleparts/frame/m4/left, /obj/structure/bed/chair/gunner),

	"1,3" = list(/obj/structure/vehicleparts/frame/m4/right/door),
	"2,3" = list(/obj/structure/vehicleparts/frame/m4, /obj/structure/bed/chair/loader),
	"3,3" = list(/obj/structure/vehicleparts/frame/m4/left/door,),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/reversed,/obj/structure/vehicleparts/frame/m4/rb, /obj/structure/engine/internal/diesel/premade/chiha),
	"2,4" = list(/obj/structure/vehicleparts/frame/m4/back, /obj/structure/shellrack/full76),
	"3,4" = list(/obj/structure/vehicleparts/movement/tracks/reversed,/obj/structure/vehicleparts/frame/m4/lb,/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueled)
	)

/obj/effects/premadevehicles/tank/panzervi
	name = "Panzer VI"
	icon_state = "4x4"
	custom_color = "#585A5C"
	axis = /obj/structure/vehicleparts/axis/heavy/panzervi
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks,/obj/structure/vehicleparts/frame/panzervi/rf,/obj/structure/bed/chair/drivers/tank),
	"2,1" = list(/obj/structure/vehicleparts/frame/panzervi/front,/obj/item/weapon/storage/toolbox/emergency),
	"3,1" = list(/obj/structure/vehicleparts/movement/tracks,/obj/structure/vehicleparts/frame/panzervi/lf,/obj/item/ammo_magazine/mg34belt,/obj/item/ammo_magazine/mg34belt,/obj/item/ammo_magazine/mg34belt,/obj/item/ammo_magazine/mg34belt,/obj/item/weapon/gun/projectile/automatic/stationary/modern/mg34),

	"1,2" = list(/obj/structure/vehicleparts/frame/panzervi/right, /obj/structure/bed/chair/commander),
	"2,2" = list(/obj/structure/vehicleparts/frame/panzervi,/obj/structure/cannon/modern/tank/german88),
	"3,2" = list(/obj/structure/vehicleparts/frame/panzervi/left, /obj/structure/bed/chair/gunner),

	"1,3" = list(/obj/structure/vehicleparts/frame/panzervi/right, /obj/structure/shellrack/full88),
	"2,3" = list(/obj/structure/vehicleparts/frame/panzervi, /obj/structure/bed/chair/loader),
	"3,3" = list(/obj/structure/vehicleparts/frame/panzervi/left),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/reversed,/obj/structure/vehicleparts/frame/panzeriv/rb, /obj/structure/engine/internal/gasoline/premade/panzeriv),
	"2,4" = list(/obj/structure/vehicleparts/frame/panzervi/back/door),
	"3,4" = list(/obj/structure/vehicleparts/movement/tracks/reversed,/obj/structure/vehicleparts/frame/panzeriv/lb,/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueledgasoline),
	)

/obj/effects/premadevehicles/tank/t90a
	name = "T-90A"
	icon_state = "4x4"
	custom_color = "#3d5931"
	axis = /obj/structure/vehicleparts/axis/heavy/t90a
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks/right,/obj/structure/vehicleparts/frame/omw22_2/rf,/obj/item/ammo_magazine/pkm,/obj/item/ammo_magazine/pkm,/obj/item/ammo_magazine/pkm,/obj/item/weapon/gun/projectile/automatic/stationary/modern/pkm),
	"2,1" = list(/obj/structure/vehicleparts/frame/omw22_2/front),
	"3,1" = list(/obj/structure/vehicleparts/movement/tracks/left,/obj/structure/vehicleparts/frame/omw22_2/lf,/obj/structure/bed/chair/drivers/tank,/obj/structure/radio/transmitter_receiver/nopower/tank/faction2),

	"1,2" = list(/obj/structure/vehicleparts/frame/omw22_2/right, /obj/structure/bed/chair/commander),
	"2,2" = list(/obj/structure/vehicleparts/frame/omw22_2,/obj/structure/cannon/modern/tank/autoloader/t90a),
	"3,2" = list(/obj/structure/vehicleparts/frame/omw22_2/left, /obj/structure/bed/chair/gunner),

	"1,3" = list(/obj/structure/vehicleparts/frame/omw22_2/right/door{doorcode = 4975}),
	"2,3" = list(/obj/structure/vehicleparts/frame/omw22_2),
	"3,3" = list(/obj/structure/vehicleparts/frame/omw22_2/left),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/left/reversed,/obj/structure/vehicleparts/frame/omw22_2/rb, /obj/structure/engine/internal/diesel/premade/v12),
	"2,4" = list(/obj/structure/vehicleparts/frame/omw22_2/back, /obj/structure/shellrack/full100),
	"3,4" = list(/obj/structure/vehicleparts/movement/tracks/right/reversed,/obj/structure/vehicleparts/frame/omw22_2/lb,/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueled)
	)

/obj/effects/premadevehicles/tank/leopard
	name = "Leopard 2A6"
	icon_state = "4x4"
	custom_color = "#3d5931"
	axis = /obj/structure/vehicleparts/axis/heavy/leopard
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks/right,/obj/structure/vehicleparts/frame/omw22_2/rf,/obj/item/ammo_magazine/mg3belt,/obj/item/ammo_magazine/mg3belt,/obj/item/ammo_magazine/mg3belt,/obj/item/weapon/gun/projectile/automatic/stationary/modern/mg3),
	"2,1" = list(/obj/structure/vehicleparts/frame/omw22_2/front),
	"3,1" = list(/obj/structure/vehicleparts/movement/tracks/left,/obj/structure/vehicleparts/frame/omw22_2/lf,/obj/structure/bed/chair/drivers/tank,/obj/structure/radio/transmitter_receiver/nopower/tank/faction1),

	"1,2" = list(/obj/structure/vehicleparts/frame/omw22_2/right,/obj/structure/bed/chair/commander),
	"2,2" = list(/obj/structure/vehicleparts/frame/omw22_2,/obj/structure/cannon/modern/tank/leopard),
	"3,2" = list(/obj/structure/vehicleparts/frame/omw22_2/left,/obj/structure/bed/chair/gunner),

	"1,3" = list(/obj/structure/vehicleparts/frame/omw22_2/right/door{doorcode = 5970}),
	"2,3" = list(/obj/structure/vehicleparts/frame/omw22_2,/obj/structure/bed/chair/loader),
	"3,3" = list(/obj/structure/vehicleparts/frame/omw22_2/left),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/left/reversed,/obj/structure/vehicleparts/frame/omw22_2/rb, /obj/structure/engine/internal/diesel/premade/v12),
	"2,4" = list(/obj/structure/vehicleparts/frame/omw22_2/back, /obj/structure/shellrack/full100),
	"3,4" = list(/obj/structure/vehicleparts/movement/tracks/right/reversed,/obj/structure/vehicleparts/frame/omw22_2/lb,/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueled)
	)

/obj/effects/premadevehicles/tank/challenger2
	name = "FV4034 Challenger 2"
	icon_state = "4x4"
	custom_color = "#CCC0A6"
	axis = /obj/structure/vehicleparts/axis/heavy/challenger2
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks/right,/obj/structure/vehicleparts/frame/omw22_2/rf,/obj/item/ammo_magazine/mg3belt,/obj/item/ammo_magazine/mg3belt,/obj/item/ammo_magazine/mg3belt,/obj/item/weapon/gun/projectile/automatic/stationary/modern/mg3),
	"2,1" = list(/obj/structure/vehicleparts/frame/omw22_2/front,/obj/structure/bed/chair/drivers/tank),
	"3,1" = list(/obj/structure/vehicleparts/movement/tracks/left,/obj/structure/vehicleparts/frame/omw22_2/lf,/obj/structure/radio/transmitter_receiver/nopower/tank/faction1),

	"1,2" = list(/obj/structure/vehicleparts/frame/omw22_2/right,/obj/structure/bed/chair/commander),
	"2,2" = list(/obj/structure/vehicleparts/frame/omw22_2,/obj/structure/cannon/modern/tank/leopard),
	"3,2" = list(/obj/structure/vehicleparts/frame/omw22_2/left,/obj/structure/bed/chair/gunner),

	"1,3" = list(/obj/structure/vehicleparts/frame/omw22_2/right/door{doorcode = 5970}),
	"2,3" = list(/obj/structure/vehicleparts/frame/omw22_2,/obj/structure/bed/chair/loader),
	"3,3" = list(/obj/structure/vehicleparts/frame/omw22_2/left),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/left/reversed,/obj/structure/vehicleparts/frame/omw22_2/rb, /obj/structure/engine/internal/diesel/premade/v12),
	"2,4" = list(/obj/structure/vehicleparts/frame/omw22_2/back, /obj/structure/shellrack/full100),
	"3,4" = list(/obj/structure/vehicleparts/movement/tracks/right/reversed,/obj/structure/vehicleparts/frame/omw22_2/lb,/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueled)
	)

////////////APCS/////////////

/obj/effects/premadevehicles/apc

/obj/effects/premadevehicles/apc/mtlb
	name = "MT-LB"
	icon_state = "4x4"
	custom_color = "#4A5243"
	axis = /obj/structure/vehicleparts/axis/heavy/mtlb
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks/mtlb/right_front,/obj/structure/vehicleparts/frame/mtlb/rf),
	"2,1" = list(/obj/structure/vehicleparts/movement/tracks/mtlb/left_front,/obj/structure/vehicleparts/frame/mtlb/lf,/obj/structure/bed/chair/drivers/tank),

	"1,2" = list(/obj/structure/vehicleparts/frame/mtlb/rfc,/obj/structure/engine/internal/diesel/premade/mtlb,/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueled),
	"2,2" = list(/obj/structure/vehicleparts/frame/mtlb/lfc),

	"1,3" = list(/obj/structure/vehicleparts/frame/mtlb/rbc),
	"2,3" = list(/obj/structure/vehicleparts/frame/mtlb/lbc),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/mtlb/right_back,/obj/structure/vehicleparts/frame/mtlb/rb),
	"2,4" = list(/obj/structure/vehicleparts/movement/tracks/mtlb/left_back,/obj/structure/vehicleparts/frame/mtlb/lb),
	)

/obj/effects/premadevehicles/apc/m113
	name = "M113"
	icon_state = "3x3"
	axis = /obj/structure/vehicleparts/axis/heavy/m113
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks/m113/right,/obj/structure/vehicleparts/frame/m113/rf,/obj/structure/engine/internal/diesel/premade/m113,/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueled),
	"2,1" = list(/obj/structure/vehicleparts/frame/m113/front,/obj/item/ammo_magazine/browning,/obj/item/ammo_magazine/browning,/obj/item/ammo_magazine/browning,/obj/item/ammo_magazine/browning,/obj/item/weapon/gun/projectile/automatic/stationary/modern/browning),
	"3,1" = list(/obj/structure/vehicleparts/movement/tracks/m113/left,/obj/structure/bed/chair/drivers/tank,/obj/structure/vehicleparts/frame/m113/lf),

	"1,2" = list(/obj/structure/vehicleparts/frame/m113/rfc),
	"2,2" = list(/obj/structure/vehicleparts/frame/m113/fc,/obj/item/weapon/storage/toolbox/emergency),
	"3,2" = list(/obj/structure/vehicleparts/frame/m113/lfc),

	"1,3" = list(/obj/structure/vehicleparts/frame/m113/rbc),
	"2,3" = list(/obj/structure/vehicleparts/frame/m113/bc),
	"3,3" = list(/obj/structure/vehicleparts/frame/m113/lfc),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/m113/left/reversed,/obj/structure/vehicleparts/frame/m113/rb),
	"2,4" = list(/obj/structure/vehicleparts/frame/m113/back),
	"3,4" = list(/obj/structure/vehicleparts/movement/tracks/m113/right/reversed,/obj/structure/vehicleparts/frame/m113/lb),
	)

/obj/effects/premadevehicles/apc/bmd2
	name = "BMD-2"
	icon_state = "4x4"
	custom_color = "#4A5243"
	axis = /obj/structure/vehicleparts/axis/heavy/bmd2
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/movement/tracks/bmd2/right,/obj/structure/vehicleparts/frame/bmd2/rf),
	"2,1" = list(/obj/structure/vehicleparts/movement/tracks/bmd2/left,/obj/structure/vehicleparts/frame/bmd2/lf),

	"1,2" = list(/obj/structure/vehicleparts/frame/bmd2/rfc,/obj/item/weapon/gun/projectile/automatic/stationary/autocannon/shipunov),
	"2,2" = list(/obj/structure/vehicleparts/frame/bmd2/lfc,/obj/structure/bed/chair/drivers/tank,/obj/structure/radio/transmitter_receiver/nopower/tank/faction2),

	"1,3" = list(/obj/structure/vehicleparts/frame/bmd2/rbc,/obj/structure/lamp/lamp_small/tank/red),
	"2,3" = list(/obj/structure/vehicleparts/frame/bmd2/lbc),

	"1,4" = list(/obj/structure/vehicleparts/movement/tracks/mtlb/left_front,/obj/structure/vehicleparts/frame/bmd2/rb,/obj/structure/engine/internal/diesel/premade/bmd2,/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueled{density = 0}),
	"2,4" = list(/obj/structure/vehicleparts/movement/tracks/mtlb/right_front,/obj/structure/vehicleparts/frame/bmd2/lb),
	)

/obj/effects/premadevehicles/apc/bmd2new
	name = "BMD-2"
	icon_state = "4x4"
	custom_color = "#4A5243"
	axis = /obj/structure/vehicleparts/axis/heavy/bmd2new
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/frame/bmd2new/rf,/obj/structure/vehicleparts/movement/tracks/bmd2new/right_front,/obj/item/weapon/gun/projectile/automatic/stationary/autocannon/shipunov),
	"2,1" = list(/obj/structure/vehicleparts/frame/bmd2new/lf,/obj/structure/vehicleparts/movement/tracks/bmd2new/left_front,/obj/structure/bed/chair/drivers/tank),

	"1,2" = list(/obj/structure/vehicleparts/frame/bmd2new/rc,/obj/structure/lamp/lamp_small/tank/red),
	"2,2" = list(/obj/structure/vehicleparts/frame/bmd2new/lc),

	"1,3" = list(/obj/structure/vehicleparts/frame/bmd2new/rb,/obj/structure/vehicleparts/movement/tracks/bmd2new/left_back,/obj/structure/engine/internal/diesel/premade/bmd2,/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueled{density = 0}),
	"2,3" = list(/obj/structure/vehicleparts/frame/bmd2new/lb,/obj/structure/vehicleparts/movement/tracks/bmd2new/right_back),
	)

/obj/effects/premadevehicles/apc/adrian
	name = "Type-9 Adrian"
	icon_state = "3x3"
	custom_color = "#555346"
	axis = /obj/structure/vehicleparts/axis/heavy/adrian
	tocreate = list(
	"1,1" = list(/obj/structure/vehicleparts/frame/adrian/rf,/obj/structure/vehicleparts/movement/tracks/bmd2new/right_front,/obj/item/weapon/gun/projectile/automatic/stationary/autocannon/shipunov),
	"2,1" = list(/obj/structure/vehicleparts/frame/adrian/lf,/obj/structure/vehicleparts/movement/tracks/bmd2new/left_front,/obj/structure/bed/chair/drivers/tank),

	"1,2" = list(/obj/structure/vehicleparts/frame/adrian/rc,/obj/structure/lamp/lamp_small/tank/red),
	"2,2" = list(/obj/structure/vehicleparts/frame/adrian/lc),

	"1,3" = list(/obj/structure/vehicleparts/frame/adrian/rb,/obj/structure/vehicleparts/movement/tracks/bmd2new/left_back,/obj/structure/engine/internal/diesel/premade/bmd2,/obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueled{density = 0}),
	"2,3" = list(/obj/structure/vehicleparts/frame/adrian/lb,/obj/structure/vehicleparts/movement/tracks/bmd2new/right_back),
	)