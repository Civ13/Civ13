/obj/structure/sign/flag
	var/ripped = FALSE
	icon = 'icons/obj/decals.dmi'
	flammable = TRUE
/obj/structure/sign/flag/attack_hand(mob/user as mob)
	if (!ripped)
		playsound(loc, 'sound/items/poster_ripped.ogg', 100, TRUE)
		for (var/i = FALSE to 3)
			if (do_after(user, 10))
				playsound(loc, 'sound/items/poster_ripped.ogg', 100, TRUE)
			else
				return
		visible_message("<span class='warning'>[user] rips [src]!</span>" )
		qdel(src)
	not_movable = FALSE
	not_disassemblable = TRUE
/obj/structure/sign/flag/green
	name = "\improper green banner"
	desc = "A green linen banner."
	icon_state = "green_banner"
/obj/structure/sign/flag/red
	name = "\improper red banner"
	desc = "A red linen banner."
	icon_state = "red_banner"
/obj/structure/sign/flag/red2
	name = "\improper red banner"
	desc = "A red linen banner, with golden trims."
	icon_state = "red_banner2"

/obj/structure/sign/flag/blue
	name = "\improper blue banner"
	desc = "A blue linen banner."
	icon_state = "blue_banner"

/obj/structure/sign/flag/reich
	name = "Reich Flag"
	desc = "A Reich flag for glory."
	icon_state = "reich"

/obj/structure/sign/flag/gb/imperial
	name = "Extra-Galactic Empire Flag"
	desc = "An Imperial Flag for the Extra-Galactic Empire."
	icon_state = "flag_galacticempire"

/obj/structure/sign/flag/gb/rebel
	name = "Alliance to Restore the Democracy Flag"
	desc = "A Rebellious flag for the Alliance."
	icon_state = "flag_rebelalliance"

/obj/structure/sign/flag/gb/pysker
	name = "Pysker Order Flag"
	desc = "A blue and white flag for the ancient order of pyskers."
	icon_state = "flag_pysker"

/obj/structure/sign/flag/gb/cis
	name = "Confederacy of Issolationist Star-Systems Flag"
	desc = "A bright blue and white with a circular emblem."
	icon_state = "flag_cis"

/obj/structure/sign/flag/blue2
	name = "\improper blue banner"
	desc = "A blue linen banner, with golden trims."
	icon_state = "blue_banner2"

/obj/structure/sign/flag/templar1
	name = "\improper templar banner"
	desc = "A white banner with the red cross of the templars in the middle."
	icon_state = "templar_banner1"

/obj/structure/sign/flag/templar2
	name = "\improper templar banner"
	desc = "A white banner with the red cross of the templars in the middle."
	icon_state = "templar_banner2"

/obj/structure/sign/flag/jihad1
	name = "\improper black islamic flag"
	desc = "A black flag with Allah written in Arabic."
	icon_state = "jihad1"

/obj/structure/sign/flag/jihad2
	name = "\improper green islamic flag"
	desc = "A green flag with Allah written in Arabic."
	icon_state = "jihad2"

/obj/structure/sign/flag/jihad3
	name = "\improper red islamic banner"
	desc = "A red banner with three moons."
	icon_state = "jihad3"

/obj/structure/sign/flag/jihad4
	name = "\improper green islamic banner"
	desc = "A green banner with the shadada."
	icon_state = "jihad4"

/obj/structure/sign/flag/taliban
	name = "\improper taliban flag"
	desc = "A white flag of the Taliban."
	icon_state = "flag_taliban"

/obj/structure/sign/flag/isis
	name = "\improper ISIS flag"
	desc = "A black flag of the ISIS."
	icon_state = "flag_isis"

/obj/structure/sign/flag/chechen
	name = "\improper chechen flag"
	desc = "The Chechen Separatist flag."
	icon_state = "flag_chechen"

/obj/structure/sign/flag/ireland
	name = "\improper irish flag"
	desc = "The Irish Republic flag."
	icon_state = "flag_ireland"

/obj/structure/sign/flag/gadsen
	name = "\improper Gadsen flag"
	desc = "The classic Gadsen flag."
	icon_state = "flag_gadsen"
/obj/structure/sign/clock
	name = "\improper clock"
	desc = "A clock."
	icon_state = "clock"
/obj/structure/sign/clock/examine(mob/user)
	..()
	user << "<big>It is now [clock_time()].</big>"
/obj/structure/sign/wide
	icon = 'icons/obj/decals_wide.dmi'
	bound_x = 32

/obj/structure/sign/wide/carpet
	name = "\improper Carpet"
	desc = "A low quality carpet dangling on the wall."
	icon = 'icons/obj/decals_wide.dmi'
	icon_state = "carpet"
	layer = OBJ_LAYER - 0.1

/obj/structure/sign/wide/carpet/purple
	name = "\improper Carpet"
	desc = "A low quality carpet dangling on the wall."
	icon = 'icons/obj/decals_wide.dmi'
	icon_state = "carpet2"
	layer = OBJ_LAYER - 0.1

/obj/structure/sign/wide/carpet/red
	name = "\improper Carpet"
	desc = "A low quality carpet dangling on the wall."
	icon = 'icons/obj/decals_wide.dmi'
	icon_state = "carpet3"
	layer = OBJ_LAYER - 0.1

/obj/structure/sign/wide/carpet/green
	name = "\improper Carpet"
	desc = "A low quality carpet dangling on the wall."
	icon = 'icons/obj/decals_wide.dmi'
	icon_state = "carpet4"
	layer = OBJ_LAYER - 0.1

/obj/structure/sign/wide/stalingrad
	name = "Stalingrad sign"
	desc = "A worn-out sign displaying Stalingrad in cyrilic."
	icon = 'icons/obj/decals_wide.dmi'
	icon_state = "stalingrad"

/obj/structure/sign/wide/kandahar
	name = "Kandahar sign"
	desc = "A worn-out sign displaying Kandahar."
	icon = 'icons/obj/decals_wide.dmi'
	icon_state = "kandahar"

/obj/structure/sign/wide/grestin
	name = "East Grestin sign"
	desc = "A somewhat worn-out sign displaying East Grestin Border Checkpoint."
	icon = 'icons/obj/decals_wide.dmi'
	icon_state = "grestin"

/obj/structure/sign
	anchored = TRUE

/obj/structure/sign/ex_act(severity)
	switch(severity)
		if (1.0)
			qdel(src)
			return
		if (2.0)
			if (prob(66))
				qdel(src)
			return
		if (3.0)
			if (prob(33))
				qdel(src)
			return
		else
	return
/obj/structure/sign/radiation
	name = "radiation in the area!"
	icon_state = "radiation"

/obj/structure/sign/traffic
	name = "STOP sign"
	desc = ""
	icon_state = "stop"

/obj/structure/sign/traffic/stop

/obj/structure/sign/traffic/crossing
	name = "pedestrian crossing sign"
	icon_state = "zebracrossing"

/obj/structure/sign/traffic/noentry
	name = "no entry sign"
	icon_state = "donotenter"

/obj/structure/sign/traffic/yeld
	name = "yeld sign"
	icon_state = "yeld"

/obj/structure/sign/traffic/gas
	name = "gas station sign"
	icon_state = "gasolinesign"

/obj/structure/sign/traffic/cafe
	name = "cafe sign"
	icon_state = "cafesign"

/obj/structure/sign/traffic/parking
	name = "parking sign"
	icon_state = "parking"

/obj/structure/sign/traffic/waysign
	name = "intersection sign"
	icon_state = "waysign"

/obj/structure/sign/traffic/zebracrossing
	name = "pedestrian crossing"
	icon_state = "zebra"
	layer = 2

/obj/structure/sign/traffic/central
	name = "white line"
	icon_state = "centralline"
	layer = 2

/obj/structure/sign/traffic/semicircle
	name = "white line"
	icon = 'icons/obj/decals_wider.dmi'
	icon_state = "circle"
	layer = 2

/obj/structure/sign/traffic/semicircle/largest
	name = "white line"
	icon = 'icons/obj/decals_widest.dmi'
	pixel_y = -6
	icon_state = "circle"
	layer = 2

/obj/structure/sign/traffic/side
	name = "yellow line"
	icon_state = "sideline"
	layer = 2

/obj/item/weapon/trafficcone
	name = "traffic cone"
	icon = 'icons/obj/decals.dmi'
	icon_state = "cone1"
	anchored = FALSE
	w_class = ITEM_SIZE_LARGE
	flags = FALSE

/obj/item/weapon/trafficcone/New()
	..()
	icon_state = pick("cone1","cone2")

/obj/structure/sign/flag/medical
	name = "Medical flag"
	desc = "A flag with the universally recognized symbol for medicine and humanitarian aid."
	icon_state = "medical_flag"

/obj/structure/sign/flag/medical/crescent
	name = "Red crescent flag"
	desc = "A flag with the crescent emblem for medicine and humanitarian aid."
	icon_state = "medical_flag_crescent"

/obj/structure/sign/flag/medical/crystal
	name = "Medical crystal flag"
	desc = "A flag with the crystal symbol for medicine and humaniarian aid."
	icon_state = "medical_flag_crystal"

/obj/structure/sign/flag/japanese
	name = "Imperial Japanese flag"
	desc = "A flag with the imperial Japanese rising sun."
	icon_state = "flag_japan_empire"

/obj/structure/sign/flag/japanese/modern
	name = "Japanese flag"
	desc = "A flag with the Japanese rising sun."
	icon_state = "flag_japan"

/obj/structure/sign/flag/chinese
	name = "Republic of China flag"
	desc = "A flag with the republic of China design."
	icon_state = "flag_china"
/obj/structure/sign/flag/chinese/prc
	name = "People's Republic of China flag"
	desc = "A flag with the PRC design."
	icon_state = "flag_chinacommie"

/obj/structure/sign/flag/mongolia
	name = "Mongolian State flag"
	desc = "A flag of the state of Mongolia."
	icon_state = "flag_mongolia"

/obj/structure/sign/flag/mongolia/communist
	name = "Mongolian People's Republic flag"
	desc = "A flag of the Mongolian People's Republic."
	icon_state = "flag_mongolia_communist"

/obj/structure/sign/flag/french
	name = "French flag"
	desc = "A flag with the tricolour french flag."
	icon_state = "flag_france"

/obj/structure/sign/flag/denmark
	name = "Danish flag"
	desc = "A flag with the red and white dannebrog."
	icon_state = "flag_denmark"

/obj/structure/sign/flag/german
	name = "German Empire flag"
	desc = "A horizontal tricolour flag of the German Empire."
	icon_state = "flag_germany"

/obj/structure/sign/flag/german/modern
	name = "German flag"
	desc = "A horizontal tricolour flag of the German Republic."
	icon_state = "flag_germany_republic"

/obj/structure/sign/flag/german/east
	name = "East German flag"
	desc = "A horizontal tricolour flag of the German Democratic Republic."
	icon_state = "flag_germany_east"

/obj/structure/sign/flag/uk
	name = "United Kingdom flag"
	desc = "A flag of the United Kingdom."
	icon_state = "flag_uk"

/obj/structure/sign/flag/russia
	name = "Russian flag"
	desc = "A flag of Russsia."
	icon_state = "flag_russia"

/obj/structure/sign/flag/russia/empire
	name = "Russian Empire flag"
	desc = "A flag of the Russsian Empire."
	icon_state = "flag_russia_empire"

/obj/structure/sign/flag/russia/kornilov
	name = "Kornilov Shock Regiment flag"
	desc = "A flag of the infamous regiment of the Volunteer Army."
	icon_state = "flag_russia_kornilov"

/obj/structure/sign/flag/russia/navy
	name = "Russian Navy flag"
	desc = "A flag of Russsian Navy."
	icon_state = "flag_russia_andreev"

/obj/structure/sign/flag/russia/rsfsr
	name = "RSFSR flag"
	desc = "A flag of the Russian Soviet Federative Socialist Republic."
	icon_state = "flag_rsfsr"

/obj/structure/sign/flag/ukraine
	name = "Ukrainian flag"
	desc = "A flag of Ukraine."
	icon_state = "flag_ukraine"

/obj/structure/sign/flag/ukraine/upa
	name = "flag of the UPA"
	desc = "The flag of the Ukrainian Insurgent Army called UPA."
	icon_state ="flag_ukraine_upa"

/obj/structure/sign/flag/ukraine/makhno
	name = "Makhnovsti flag"
	desc = "A flag of the Revolutionary Insurgent Army of Ukraine. Also known as the Black Army or Makhnovsti."
	icon_state = "flag_makhno"

/obj/structure/sign/flag/doncossack
	name = "Don Cossack Host flag"
	desc = "A flag of the Don cossacks."
	icon_state = "flag_doncossack"

/obj/structure/sign/flag/terekcossack
	name = "Terek Cossack Host flag"
	desc = "A flag of the Terek cossacks."
	icon_state = "flag_terekcossack"

/obj/structure/sign/flag/poland
	name = "Polish flag"
	desc = "A flag of Poland."
	icon_state = "flag_poland"

/obj/structure/sign/flag/ukraine/azov
	name = "flag of the Azov regiment"
	desc = "The flag of the infamous Azov regiment of the Ukrainian National Guard."
	icon_state ="flag_ukraine_azov"

/obj/structure/sign/flag/ukraine/rightsector
	name = "flag of the Right Sector"
	desc = "The flag of the Ukrainian far-right paramilitary movement."
	icon_state ="flag_ukraine_rightsector"

/obj/structure/sign/flag/ukraine/dnr
	name = "flag of the Donetsk People's Republic"
	desc = "The flag of the self-proclaimed state of the Donetsk People's Republic"
	icon_state = "flag_ukraine_dnr"

/obj/structure/sign/flag/ukraine/lnr
	name = "flag of the Luhansk People's Republic"
	desc = "The flag of the self-proclaimed state of the Luhansk People's Republic"
	icon_state = "flag_ukraine_lnr"

/obj/structure/sign/flag/ukraine/afu
	name = "AFU flag"
	desc = "The flag of the Armed Forces of Ukraine."
	icon_state ="flag_ukraine_vsu"

/obj/structure/sign/flag/vietnam
	name = "North Vietnam flag"
	desc = "The North Vietnamese flag."
	icon_state = "flag_vietnam"

/obj/structure/sign/flag/vietcong
	name = "Viet Cong flag"
	desc = "The blue and red flag of the Viet Cong forces."
	icon_state = "flag_vietcong"

/obj/structure/sign/flag/usa
	name = "USA flag"
	desc = "The star-spangled banner."
	icon_state = "flag_usa"

/obj/structure/sign/flag/usa_union
	name = "Union flag"
	desc = "The red, white and blue flag flying above ranks of blue-clad troops."
	icon_state = "flag_union"

/obj/structure/sign/flag/texas
	name = "Texan flag"
	desc = "The flag of the state of Texas."
	icon_state = "flag_texas"

/obj/structure/sign/flag/sov
	name = "Soviet Union flag"
	desc = "The red flag of the Soviet Union."
	icon_state = "flag_sov"

/obj/structure/sign/flag/sov/navy
	name = "Soviet Navy flag"
	desc = "The flag of the naval service branch of the Soviet Armed Forces."
	icon_state = "flag_sovfleet"

/obj/structure/sign/flag/sov/vdv
	name = "Soviet VDV flag"
	desc = "The flag of the Soviet Airborne Forces."
	icon_state = "flag_vdv"

/obj/structure/sign/flag/sov/air
	name = "Soviet Air Forces flag"
	desc = "The flag of the Soviet Air Forces."
	icon_state = "flag_sovair"

/obj/structure/sign/flag/sov/border
	name = "Soviet Border Troops flag"
	desc = "The flag of the Soviet Border Troops."
	icon_state = "flag_sovborder"

/obj/structure/sign/flag/nazi
	name = "Third Reich flag"
	desc = "The red, white and black flag of the Third Reich."
	icon_state = "flag_nazi"

/obj/structure/sign/flag/israel
	name = "Israel flag"
	desc = "The white and blue flag of Israel, with the 6 pointed star in the middle."
	icon_state = "flag_israel"

/obj/structure/sign/flag/un
	name = "UN flag"
	desc = "The flag of the United Nations."
	icon_state = "flag_un"

/obj/structure/sign/flag/dutch
	name = "Dutch flag"
	desc = "The flag of Netherlands."
	icon_state = "flag_netherlands"

/obj/structure/sign/flag/dutch_old
	name = "Prince's flag"
	desc = "The Dutch flag."
	icon_state = "flag_netherlands_old"

/obj/structure/sign/flag/chetnik
	name = "Chetnik flag"
	desc = "A Chetnik flag."
	icon_state = "flag_chetnik"

/obj/structure/sign/flag/yugoslavia
	name = "Yugoslavian flag"
	desc = "The flag of Yugoslavia."
	icon_state = "flag_yugo"

/obj/structure/sign/flag/yugoslavia/partisan
	name = "Yugoslavian flag"
	desc = "The flag of Yugoslavian partisans."
	icon_state = "flag_yugopart"

/obj/structure/sign/flag/gns
	name = "GNS flag"
	desc = "The flag of the Goverment of National Salvation."
	icon_state = "flag_gns"

/obj/structure/sign/flag/ssg
	name = "SSG flag"
	desc = "The flag of the Serbian State Guard."
	icon_state = "flag_ssg"

/obj/structure/sign/flag/australia
	name = "Australian flag"
	desc = "The flag of Australia."
	icon_state = "flag_australia"

/obj/structure/sign/flag/canada
	name = "Canadian flag"
	desc = "The flag of Canada."
	icon_state = "flag_canada"

/obj/structure/sign/flag/hezbollah
	name = "Hezbollah flag"
	desc = "The yellow and green flag of the Shia Hezbollah organization."
	icon_state = "flag_hezbollah"

/obj/structure/sign/flag/philippine
	name = "Filipino flag"
	desc = "The flag of the Philippines."
	icon_state = "flag_fp"

/obj/structure/sign/flag/philippine_war
	name = "Filipino flag"
	desc = "The flag of the Philippines. Flipped for wartime."
	icon_state = "flag_fp_war"

/obj/structure/sign/flag/pirate
	name = "Pirate flag"
	desc = "The black pirate flag, with a skull in the middle."
	icon_state = "pirate"

/obj/structure/sign/flag/firstcav
	name = "1st Cavalry Division flag"
	desc = "Flag of the United States Army 1st Cavalry Division."
	icon_state = "flag_1stcav"

/obj/structure/sign/flag/cuba
	name = "Cuban flag"
	desc = "The Cuban flag."
	icon_state = "flag_cuba"

/obj/structure/sign/flag/colombia
	name = "Colombian flag"
	desc = "The flag of Colombia."
	icon_state = "flag_colombia"

/obj/structure/sign/flag/colombia/farc
	name = "FARC flag"
	desc = "The flag of the Revolutionary Armed Forces of Columbia."
	icon_state = "flag_colombia_farc"

/obj/structure/sign/flag/mexico
	name = "Mexican flag"
	desc = "The flag of Mexico."
	icon_state = "flag_mexico"

/obj/structure/sign/flag/brazil
	name = "Brazilian flag"
	desc = "The flag of Brazil."
	icon_state = "flag_brazil"

/obj/structure/sign/flag/brazil/empire
	name = "Empire of Brazil flag"
	desc = "The flag of the Empire of Brazil."
	icon_state = "flag_brazil_empire"

/obj/structure/sign/flag/paraguay
	name = "Paraguayan flag"
	desc = "The flag of Paraguay."
	icon_state = "flag_paraguay"

/obj/structure/sign/flag/argentina
	name = "Argentinian flag"
	desc = "The flag of Argentina."
	icon_state = "flag_argentina"

/obj/structure/sign/flag/venezuela
	name = "Venezuelan flag"
	desc = "The flag of Venezuela."
	icon_state = "flag_venezuela"

/obj/structure/sign/flag/peru
	name = "Peruvian flag"
	desc = "The flag of Peru."
	icon_state = "flag_peru"

/obj/structure/sign/flag/bolivia
	name = "Bolivian flag"
	desc = "The flag of Bolivia."
	icon_state = "flag_bolivia"

/obj/structure/sign/flag/chile
	name = "Chilean flag"
	desc = "The flag of Chile."
	icon_state = "flag_chile"

/obj/structure/sign/flag/afghan/dra
	name = "DRA flag"
	desc = "The Democratic Republic of Afghanistan flag."
	icon_state = "flag_dra"

/obj/structure/sign/flag/iran
	name = "Iranian flag"
	desc = "The Iranian flag."
	icon_state = "flag_iran"

/obj/structure/sign/flag/iraq
	name = "Iraqui flag"
	desc = "The flag of Iraq."
	icon_state = "flag_iraq"

/obj/structure/sign/flag/syria
	name = "Syrian flag"
	desc = "The flag of Syria."
	icon_state = "flag_syria"

/obj/structure/sign/flag/fsa
	name = "FSA flag"
	desc = "The flag of the Free Syrian Army."
	icon_state = "flag_syria_fsa"

/obj/structure/sign/flag/turkey
	name = "Turkish flag"
	desc = "The flag of Turkey."
	icon_state = "flag_turkey"

/obj/structure/sign/flag/kurdistan
	name = "Kurdish flag"
	desc = "The flag of Kurdistan."
	icon_state = "flag_kurdistan"

/obj/structure/sign/flag/georgia
	name = "Georgian flag"
	desc = "The flag of Georgia."
	icon_state = "flag_georgia"

/obj/structure/sign/flag/georgia/old
	name = "Georgian flag"
	desc = "The flag of Georgia. Used from 1990 to 2004."
	icon_state = "flag_georgia_old"

/obj/structure/sign/flag/india
	name = "Indian flag"
	desc = "The flag of India."
	icon_state = "flag_india"

/obj/structure/sign/flag/pakistan
	name = "Pakistani flag"
	desc = "The flag of Pakistan."
	icon_state = "flag_pakistan"

/obj/structure/sign/flag/italy
	name = "Italian flag"
	desc = "The Italian flag."
	icon_state = "flag_italy"

/obj/structure/sign/flag/finland
	name = "Finnish flag"
	desc = "The flag of Finland."
	icon_state = "flag_finland"

/obj/structure/sign/flag/nigeria
	name = "Nigerian flag"
	desc = "The flag of Nigeria."
	icon_state = "flag_nigeria"

/obj/structure/sign/flag/ethiopia
	name = "Ethiopian flag"
	desc = "The flag of Ethiopia."
	icon_state = "flag_ethiopia"

/obj/structure/sign/flag/armenia
	name = "Armenian flag"
	desc = "The flag of Armenia."
	icon_state = "flag_armenia"

/obj/structure/sign/flag/azerbaijan
	name = "Azerbaijani flag"
	desc = "The flag of the Republic of Azerbaijan."
	icon_state = "flag_azerbaijan"

/obj/structure/sign/flag/bosnia
	name = "Bosnian flag"
	desc = "The flag of Bosnia."
	icon_state = "flag_bosnia"

/obj/structure/sign/flag/kosovo
	name = "Kosovo flag"
	desc = "The flag of Kosovo."
	icon_state = "flag_kosovo"

/obj/structure/sign/flag/albania
	name = "Albanian flag"
	desc = "The flag of Albania."
	icon_state = "flag_albania"

/obj/structure/sign/flag/spain
	name = "Spanish flag"
	desc = "The flag of Spain."
	icon_state = "flag_spain"

/obj/structure/sign/flag/spain/nationalist
	name = "Spanish Nationalist flag"
	desc = "The flag of Nationalist Spain."
	icon_state = "flag_spainn"

/obj/structure/sign/flag/serbia
	name = "Serbian flag"
	desc = "The flag of Serbia."
	icon_state = "flag_serbia"

/obj/structure/sign/flag/romania
	name = "Romanian flag"
	desc = "The flag of Romania."
	icon_state = "flag_romania"

/obj/structure/sign/flag/romania/socialist
	name = "RSR flag"
	desc = "The flag of the Socialist Republic of Romania."
	icon_state = "flag_romania_soc"

/obj/structure/sign/flag/moldova
	name = "Moldovan flag"
	desc = "The flag of the Republic of Moldova."
	icon_state = "flag_moldova"

/obj/structure/sign/flag/moldova/transnistria
	name = "Transnistrian flag"
	desc = "The flag of the Pridnestrovian Moldavian Republic."
	icon_state = "flag_transnistria"

/obj/structure/sign/flag/czech
	name = "Czechoslovakian flag"
	desc = "The flag of Czechoslovakia."
	icon_state = "flag_czech"

/obj/structure/sign/flag/hungary
	name = "Hungarian flag"
	desc = "The flag of Hungary."
	icon_state = "flag_hungary"

/obj/structure/sign/flag/hungary/sov
	name = "Hungarian People's Republic flag"
	desc = "The flag of the Hungarian People's Republic."
	icon_state = "flag_hungary_sov"

/obj/structure/sign/flag/hungary/old
	desc = "The flag of Hungary with the small coat of arms."
	icon_state = "flag_hungary_kingdom"

/obj/structure/sign/flag/finland
	name = "Finnish flag"
	desc = "The flag of Finland."
	icon_state = "flag_finland"

/obj/structure/sign/flag/warpact
	name = "WARPACT flag"
	desc = "The flag of the Wasrsaw Pact."
	icon_state = "flag_warpact"

/obj/structure/sign/flag/warpact/alt
	icon_state = "flag_warpact2"

/obj/structure/sign/flag/nato
	name = "NATO flag"
	desc = "The flag of North Atlantic Treaty Organization."
	icon_state = "flag_nato"

/obj/structure/sign/flag/redmenia
	name = "Redmenian flag"
	desc = "The flag of the Empire of Redmenia."
	icon_state = "flag_redmenia"

/obj/structure/sign/flag/blugoslavia
	name = "Blugoslavian flag"
	desc = "The flag of the Republic of Blugoslavia."
	icon_state = "flag_blugoslavia"

/obj/structure/sign/flag/blugoslavia/old
	name = "old Blugoslavian flag"
	desc = "The flag of the old Republic of Blugoslavia."
	icon_state = "flag_blugoslavia-old"

/obj/structure/sign/flag/arstotzka
	name = "Arstotzkan flag"
	desc = "Glory to Arstotzka!"
	icon_state = "flag_arstotzka"

/obj/structure/sign/flag/custom
	name = "flag"
	desc = "A flag."
	icon_state = "f_white"

/obj/structure/sign/logo/red
	name = "Rednikov Industries Logo"
	desc = "A sign with the logo of Rednikov Industries"
	icon_state = "red_logo"
/obj/structure/sign/logo/yellow
	name = "Goldstein Solutions"
	desc = "A sign with the logo of Goldstein Solutions"
	icon_state = "yellow_logo"
/obj/structure/sign/logo/blue
	name = "Giovanni Blu Stocks"
	desc = "A sign with the logo of Giovanni Blu Stocks"
	icon_state = "blue_logo"
/obj/structure/sign/logo/green
	name = "Kogama Kraftsmen"
	desc = "A sign with the logo of Kogama Kraftsmen Traders"
	icon_state = "green_logo"

/obj/item/flagmaker
	name = "custom flag maker"
	desc = "A white cotton sheet and some colored ink."
	icon = 'icons/obj/decals.dmi'
	icon_state = "flagmaker"
	var/new_icon_state = "White"

/obj/item/flagmaker/attack_self(mob/user)
	var/stop = FALSE

	var/list/display1 = list("White", "Black", "Yellow", "Blue", "Red", "Green", "Cancel")
	var/choice1 = WWinput(user, "What background color do you want for the flag?", "Flag Maker", "Cancel", display1)
	switch (choice1)
		if ("Cancel")
			new_icon_state = "none"
			icon_state = "none"
			stop = TRUE
			return
		if ("White")
			new_icon_state = "f_white"
			icon_state = "f_white"
		if ("Black")
			new_icon_state = "f_black"
			icon_state = "f_black"
		if ("Yellow")
			new_icon_state = "f_yellow"
			icon_state = "f_yellow"
		if ("Blue")
			new_icon_state = "f_blue"
			icon_state = "f_blue"
		if ("Red")
			new_icon_state = "f_red"
			icon_state = "f_red"
		if ("Green")
			new_icon_state = "f_green"
			icon_state = "f_green"

	var/list/display2 = list("White", "Black", "Yellow", "Blue", "Red", "Green", "No")
	var/choice2 = WWinput(user, "Add a left-half color?", "Flag Maker", "No", display2)
	switch (choice2)
		if ("No")
			icon_state = new_icon_state
		if ("White")
			var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "fl_white")
			overlays += flag_left
		if ("Black")
			var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "fl_black")
			overlays += flag_left
		if ("Yellow")
			var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "fl_yellow")
			overlays += flag_left
		if ("Blue")
			var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "fl_blue")
			overlays += flag_left
		if ("Red")
			var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "fl_red")
			overlays += flag_left
		if ("Green")
			var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "fl_green")
			overlays += flag_left

	var/list/display3 = list("White", "Black", "Yellow", "Blue", "Red", "Green", "No")
	var/choice3 = WWinput(user, "Add a right-half color?", "Flag Maker", "No", display3)
	switch (choice3)
		if ("No")
			icon_state = new_icon_state
		if ("White")
			var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "fr_white")
			overlays += flag_left
		if ("Black")
			var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "fr_black")
			overlays += flag_left
		if ("Yellow")
			var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "fr_yellow")
			overlays += flag_left
		if ("Blue")
			var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "fr_blue")
			overlays += flag_left
		if ("Red")
			var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "fr_red")
			overlays += flag_left
		if ("Green")
			var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "fr_green")
			overlays += flag_left

	var/list/display4 = list("White", "Black", "Yellow", "Blue", "Red", "Green", "No")
	var/choice4 = WWinput(user, "Add a left-third color?", "Flag Maker", "No", display4)
	switch (choice4)
		if ("No")
			icon_state = new_icon_state
		if ("White")
			var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "f1_white")
			overlays += flag_left
		if ("Black")
			var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "f1_black")
			overlays += flag_left
		if ("Yellow")
			var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "f1_yellow")
			overlays += flag_left
		if ("Blue")
			var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "f1_blue")
			overlays += flag_left
		if ("Red")
			var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "f1_red")
			overlays += flag_left
		if ("Green")
			var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "f1_green")
			overlays += flag_left

	var/list/display5 = list("White", "Black", "Yellow", "Blue", "Red", "Green", "No")
	var/choice5 = WWinput(user, "Add a center-third color?", "Flag Maker", "No", display5)
	switch (choice5)
		if ("No")
			icon_state = new_icon_state
		if ("White")
			var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "f2_white")
			overlays += flag_left
		if ("Black")
			var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "f2_black")
			overlays += flag_left
		if ("Yellow")
			var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "f2_yellow")
			overlays += flag_left
		if ("Blue")
			var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "f2_blue")
			overlays += flag_left
		if ("Red")
			var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "f2_red")
			overlays += flag_left
		if ("Green")
			var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "f2_green")
			overlays += flag_left

	var/list/display6 = list("White", "Black", "Yellow", "Blue", "Red", "Green", "No")
	var/choice6 = WWinput(user, "Add a right-third color?", "Flag Maker", "No", display6)
	switch (choice6)
		if ("No")
			icon_state = new_icon_state
		if ("White")
			var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "f3_white")
			overlays += flag_left
		if ("Black")
			var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "f3_black")
			overlays += flag_left
		if ("Yellow")
			var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "f3_yellow")
			overlays += flag_left
		if ("Blue")
			var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "f3_blue")
			overlays += flag_left
		if ("Red")
			var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "f3_red")
			overlays += flag_left
		if ("Green")
			var/image/flag_left = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "f3_green")
			overlays += flag_left

	var/list/display7 = list("White Cross", "Black Cross", "Blue Cross", "Red Cross", "Green Cross", "No")
	var/choice7 = WWinput(user, "Add a cross?", "Flag Maker", "No", display7)
	switch (choice7)
		if ("No")
			icon_state = new_icon_state
		if ("White Cross")
			var/image/cross = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_bigcross0")
			overlays += cross
		if ("Black Cross")
			var/image/cross = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_bigcross1")
			overlays += cross
		if ("Blue Cross")
			var/image/cross = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_bigcross2")
			overlays += cross
		if ("Red Cross")
			var/image/cross = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_bigcross3")
			overlays += cross
		if ("Green Cross")
			var/image/cross = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_bigcross4")
			overlays += cross

	var/list/display8 = list("White Saltire", "Black Saltire", "Blue Saltire", "Red Saltire", "Green Saltire", "No")
	var/choice8 = WWinput(user, "Add a saltire?", "Flag Maker", "No", display8)
	switch (choice8)
		if ("No")
			icon_state = new_icon_state
		if ("White Saltire")
			var/image/saltire = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_saltire0")
			overlays += saltire
		if ("Black Saltire")
			var/image/saltire = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_saltire1")
			overlays += saltire
		if ("Blue Saltire")
			var/image/saltire = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_saltire2")
			overlays += saltire
		if ("Red Saltire")
			var/image/saltire = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_saltire3")
			overlays += saltire
		if ("Green Saltire")
			var/image/saltire = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_saltire4")
			overlays += saltire

	var/list/display9 = list("White Star", "Golden Star", "Black Star", "White Moon", "Golden Moon", "Black Moon", "White Cross", "Golden Cross", "Black Cross", "Red Circle", "Thin Red Sun", "Thick Red Sun", "White Skull", "White Peace Sign", "Black Peace Sign", "No")
	var/choice9 = WWinput(user, "Add a symbol?", "Flag Maker", "No", display9)
	switch (choice9)
		if ("No")
			icon_state = new_icon_state
		if ("White Star")
			var/image/flag_symbol = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_star0")
			overlays += flag_symbol
		if ("Golden Star")
			var/image/flag_symbol = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_star1")
			overlays += flag_symbol
		if ("Black Star")
			var/image/flag_symbol = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_star2")
			overlays += flag_symbol

		if ("White Moon")
			var/image/flag_symbol = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_moon0")
			overlays += flag_symbol
		if ("Golden Moon")
			var/image/flag_symbol = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_moon1")
			overlays += flag_symbol
		if ("Black Moon")
			var/image/flag_symbol = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_moon2")
			overlays += flag_symbol

		if ("White Cross")
			var/image/flag_symbol = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_cross0")
			overlays += flag_symbol
		if ("Golden Cross")
			var/image/flag_symbol = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_cross1")
			overlays += flag_symbol
		if ("Black Cross")
			var/image/flag_symbol = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_cross2")
			overlays += flag_symbol

		if ("Red Circle")
			var/image/flag_symbol = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_circle0")
			overlays += flag_symbol
		if ("Thin Red Sun")
			var/image/flag_symbol = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_sun0")
			overlays += flag_symbol
		if ("Thick Red Sun")
			var/image/flag_symbol = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_sun1")
			overlays += flag_symbol

		if ("Black Peace Sign")
			var/image/flag_symbol = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_peace0")
			overlays += flag_symbol
		if ("White Peace Sign")
			var/image/flag_symbol = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_peace1")
			overlays += flag_symbol

		if ("White Skull")
			var/image/flag_symbol = image("icon" = 'icons/obj/decals.dmi', "icon_state" = "e_skull0")
			overlays += flag_symbol

	var/flag_name = input(usr, "Name the flag:") as text|null
	if (flag_name == "" || flag_name == null)
		name = "flag"
	else
		name = sanitize(flag_name, 50)

	var/obj/structure/sign/flag/custom/CF = new/obj/structure/sign/flag/custom(user.loc)
	CF.overlays = overlays
	CF.icon_state = new_icon_state
	CF.name = name
	if (stop)
		qdel(CF)
	else
		qdel(src)
	return