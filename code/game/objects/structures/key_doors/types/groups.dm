/var/global/REDCODE = 1000
/var/global/BLUECODE = 2000
/var/global/YELLOWCODE = 3000
/var/global/GREENCODE = 4000
/////////313 stuff//////////

#define AN_CODE 1000
/datum/keyslot/ancient
	code = AN_CODE

/obj/item/weapon/key/ancient
	code = AN_CODE
	name = "Key"

/obj/structure/simple_door/key_door/ancient
	keyslot_type = /datum/keyslot/ancient
	unique_door_name = "Locked"
#undef AN_CODE
#define AN_CODE2 11546
/datum/keyslot/ancient/roman
	code = AN_CODE2

/obj/item/weapon/key/ancient/roman
	code = AN_CODE2
	name = "Roman Fortress Key"

/obj/structure/simple_door/key_door/ancient/roman
	keyslot_type = /datum/keyslot/ancient/roman
	unique_door_name = "Roman Fortress"
#undef AN_CODE2
#define AN_CODE3 11311
/datum/keyslot/ancient/greek
	code = AN_CODE3

/obj/item/weapon/key/ancient/greek
	code = AN_CODE3
	name = "Greek Fortress Key"

/obj/structure/simple_door/key_door/ancient/greek
	keyslot_type = /datum/keyslot/ancient/greek
	unique_door_name = "Greek Fortress"
#undef AN_CODE3


////////1713 stuff//////////
#define CV_CUSTOM 999
/obj/structure/simple_door/key_door/custom
	custom = TRUE
	custom_code = 999
	unique_door_name = "Private"
#undef CV_CUSTOM

#define CV_CUSTOM_WOODJAIL 999
/obj/structure/simple_door/key_door/custom/jail/woodjail
	custom = TRUE
	custom_code = 999
	unique_door_name = "Private"
	opacity = 0
#undef CV_CUSTOM_WOODJAIL

#define CV_CUSTOM_STEELJAIL 999
/obj/structure/simple_door/key_door/custom/jail/steeljail
	custom = TRUE
	custom_code = 999
	unique_door_name = "Private"
	opacity = 0
#undef CV_CUSTOM_STEELJAIL

#define CV_CODE 1000
/datum/keyslot/civ
	code = CV_CODE

/obj/item/weapon/key/civ
	code = CV_CODE
	name = "Key"

/obj/structure/simple_door/key_door/civ
	keyslot_type = /datum/keyslot/civ
	unique_door_name = "Locked"
#undef CV_CODE
#define CV_CODE2 11546
/datum/keyslot/civ/hall
	code = CV_CODE2

/obj/item/weapon/key/civ/hall
	code = CV_CODE2
	name = "Gaurd's Key"

/obj/structure/simple_door/key_door/civ/hall
	keyslot_type = /datum/keyslot/civ/hall
	unique_door_name = "Colony Hall"
#undef CV_CODE2
#define CV_CODE3 11311
/datum/keyslot/civ/gov
	code = CV_CODE3

/obj/item/weapon/key/civ/gov
	code = CV_CODE3
	name = "Leader's Key"

/obj/structure/simple_door/key_door/civ/gov
	keyslot_type = /datum/keyslot/civ/gov
	unique_door_name = "Governor's Office"
#undef CV_CODE3
#define CV_ROOM1 12311
/datum/keyslot/civ/room1
	code = CV_ROOM1

/obj/item/weapon/key/civ/room1
	code = CV_ROOM1
	name = "Room #1 Key"

/obj/structure/simple_door/key_door/civ/room1
	keyslot_type = /datum/keyslot/civ/room1
	unique_door_name = "Room #1"
#undef CV_ROOM1

#define CV_ROOM2 22322
/datum/keyslot/civ/room2
	code = CV_ROOM2

/obj/item/weapon/key/civ/room2
	code = CV_ROOM2
	name = "Room #2 Key"

/obj/structure/simple_door/key_door/civ/room2
	keyslot_type = /datum/keyslot/civ/room2
	unique_door_name = "Room #2"
#undef CV_ROOM2

#define CV_ROOM3 32333
/datum/keyslot/civ/room3
	code = CV_ROOM3

/obj/item/weapon/key/civ/room3
	code = CV_ROOM3
	name = "Room #3 Key"

/obj/structure/simple_door/key_door/civ/room3
	keyslot_type = /datum/keyslot/civ/room3
	unique_door_name = "Room #3"
#undef CV_ROOM3

#define CV_ROOM4 42344
/datum/keyslot/civ/room4
	code = CV_ROOM4

/obj/item/weapon/key/civ/room4
	code = CV_ROOM4
	name = "Room #4 Key"

/obj/structure/simple_door/key_door/civ/room4
	keyslot_type = /datum/keyslot/civ/room4
	unique_door_name = "Room #4"
#undef CV_ROOM4

#define CV_ROOM5 52355
/datum/keyslot/civ/room5
	code = CV_ROOM5

/obj/item/weapon/key/civ/room5
	code = CV_ROOM5
	name = "Room #5 Key"

/obj/structure/simple_door/key_door/civ/room5
	keyslot_type = /datum/keyslot/civ/room5
	unique_door_name = "Room #5"
#undef CV_ROOM5

#define CV_ROOM6 62366
/datum/keyslot/civ/room6
	code = CV_ROOM6

/obj/item/weapon/key/civ/room6
	code = CV_ROOM6
	name = "Room #6 Key"

/obj/structure/simple_door/key_door/civ/room6
	keyslot_type = /datum/keyslot/civ/room6
	unique_door_name = "Room #6"
#undef CV_ROOM6

#define CV_ROOM7 72377
/datum/keyslot/civ/room7
	code = CV_ROOM7

/obj/item/weapon/key/civ/room7
	code = CV_ROOM7
	name = "Room #7 Key"

/obj/structure/simple_door/key_door/civ/room7
	keyslot_type = /datum/keyslot/civ/room7
	unique_door_name = "Room #7"
#undef CV_ROOM7

#define CV_ROOM8 82388
/datum/keyslot/civ/room8
	code = CV_ROOM8

/obj/item/weapon/key/civ/room8
	code = CV_ROOM8
	name = "Room #8 Key"

/obj/structure/simple_door/key_door/civ/room8
	keyslot_type = /datum/keyslot/civ/room8
	unique_door_name = "Room #8"
#undef CV_ROOM8

#define CV_INN 82111
/datum/keyslot/civ/inn
	code = CV_INN

/obj/item/weapon/key/civ/inn
	code = CV_INN
	name = "Private Inn Key"

/obj/structure/simple_door/key_door/civ/inn
	keyslot_type = /datum/keyslot/civ/inn
	unique_door_name = "staff only area"

/obj/structure/simple_door/key_door/custom/jail/steeljail/inn
	unique_door_name = "Locked Staff Only"
	locked = TRUE
	custom_code = CV_INN

/obj/structure/closet/crate/cash_register/inn
	name = "Inn till"
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "cash_register_antique"
	icon_opened = "cash_register_antique_opened"
	icon_closed = "cash_register_antique"
	custom_code = CV_INN
	locked = TRUE
/obj/structure/closet/cabinet/ceiling/liquer
	name = "Liquer cabinet"
	custom_code = CV_INN
	locked = TRUE

#undef CV_INN

/datum/keyslot/civ/businessred/New()
	..()
	code = REDCODE

/obj/item/weapon/key/civ/businessred/New()
	..()
	code = REDCODE
	name = "Headquarters key"

/obj/structure/simple_door/key_door/civ/businessred
	keyslot_type = /datum/keyslot/civ/businessred
	unique_door_name = "Headquarters"
	health = 45000

/datum/keyslot/civ/businessblue/New()
	..()
	code = BLUECODE

/obj/item/weapon/key/civ/businessblue/New()
	..()
	code = BLUECODE
	name = "Headquarters key"

/obj/structure/simple_door/key_door/civ/businessblue
	keyslot_type = /datum/keyslot/civ/businessblue
	unique_door_name = "Headquarters"
	health = 45000

/datum/keyslot/civ/businessgreen/New()
	..()
	code = GREENCODE

/obj/item/weapon/key/civ/businessgreen/New()
	..()
	code = GREENCODE
	name = "Headquarters key"

/obj/structure/simple_door/key_door/civ/businessgreen
	keyslot_type = /datum/keyslot/civ/businessgreen
	unique_door_name = "Headquarters"
	health = 45000

/datum/keyslot/civ/businessyellow/New()
	..()
	code = YELLOWCODE

/obj/item/weapon/key/civ/businessyellow/New()
	..()
	code = YELLOWCODE
	name = "Headquarters key"

/obj/structure/simple_door/key_door/civ/businessyellow
	keyslot_type = /datum/keyslot/civ/businessyellow
	unique_door_name = "Headquarters"
	health = 45000
#define CV_BANK 82111
/datum/keyslot/civ/bank
	code = CV_BANK

/obj/item/weapon/key/civ/bank
	code = CV_BANK
	name = "staff only area"

/obj/structure/simple_door/key_door/civ/bank
	keyslot_type = /datum/keyslot/civ/bank
	unique_door_name = "Bank Key"
#undef CV_BANK

#define CV_SHERIFF 42111
/datum/keyslot/civ/sheriff
	code = CV_SHERIFF

/obj/item/weapon/key/civ/sheriff
	code = CV_SHERIFF
	name = "Sheriff's Office"

/obj/structure/simple_door/key_door/civ/sherif
	keyslot_type = /datum/keyslot/civ/sheriff
	unique_door_name = "Sheriff Office Key"

#define PI_CODE 995
/datum/keyslot/pirates
	code = PI_CODE

/obj/item/weapon/key/pirates
	code = PI_CODE
	name = "Pirate key"

/obj/structure/simple_door/key_door/pirates
	keyslot_type = /datum/keyslot/pirates
	unique_door_name = "Pirate locked"
#undef PI_CODE

#define RN_CODE 995 * 2
/datum/keyslot/british
	code = RN_CODE

/obj/item/weapon/key/british
	code = RN_CODE
	name = "British key"

/obj/structure/simple_door/key_door/british
	keyslot_type = /datum/keyslot/british
	unique_door_name = "British locked"
#undef RN_CODE

#define SP_CODE 995 * 3
/datum/keyslot/spanish
	code = SP_CODE

/obj/item/weapon/key/spanish
	code = SP_CODE
	name = "Spanish Key"

/obj/structure/simple_door/key_door/spanish
	keyslot_type = /datum/keyslot/spanish
	unique_door_name = "Spanish locked"
#undef SP_CODE

#define FR_CODE 995 * 4
/datum/keyslot/french
	code = FR_CODE

/obj/item/weapon/key/french
	code = FR_CODE
	name = "French key"

/obj/structure/simple_door/key_door/french
	keyslot_type = /datum/keyslot/french
	unique_door_name = "French locked"
#undef FR_CODE

#define PT_CODE 995 * 5
/datum/keyslot/portuguese
	code = PT_CODE

/obj/item/weapon/key/portuguese
	code = PT_CODE
	name = "Portuguese key"

/obj/structure/simple_door/key_door/portuguese
	keyslot_type = /datum/keyslot/portuguese
	unique_door_name = "Portuguese locked"
#undef PT_CODE

#define RU_CODE 995 * 5
/datum/keyslot/russian
	code = RU_CODE

/obj/item/weapon/key/russian
	code = RU_CODE
	name = "Russian key"

/obj/structure/simple_door/key_door/russian
	keyslot_type = /datum/keyslot/russian
	unique_door_name = "Russian locked"

/datum/keyslot/soviet
	code = RU_CODE

/datum/keyslot/soviet/guard
	code = RU_CODE

/datum/keyslot/soviet/guard/max
	code = RU_CODE+2

/datum/keyslot/soviet/guard/max/command
	code = RU_CODE+8

/obj/item/weapon/key/soviet
	code = RU_CODE
	name = "Soviet key"

/obj/item/weapon/key/soviet/guard
	code = RU_CODE
	name = "GULAG guard key"
	health = 90000
/obj/item/weapon/key/soviet/guard/max
	code = RU_CODE+2
	name = "Maximum Security guard key"
/obj/item/weapon/key/soviet/guard/max/command
	code = RU_CODE+8
	name = "Maximum Security commander key"

/obj/structure/simple_door/key_door/soviet
	keyslot_type = /datum/keyslot/soviet
	unique_door_name = "Soviet locked"
/obj/structure/simple_door/key_door/soviet/guard
	keyslot_type = /datum/keyslot/soviet/guard
	unique_door_name = "GULAG locked"
/obj/structure/simple_door/key_door/soviet/guard/chainlink
	icon_state = "chainlink"
	basic_icon = "chainlink"
	override_opacity = TRUE
	override_material = TRUE
/obj/structure/simple_door/key_door/soviet/guard/max
	keyslot_type = /datum/keyslot/soviet/guard/max
	unique_door_name = "Maximum Security locked"
/obj/structure/simple_door/key_door/soviet/guard/max/command
	keyslot_type = /datum/keyslot/soviet/guard/max/command
	unique_door_name = "Maximum Security - Command Only locked"
/obj/structure/simple_door/key_door/custom/jail/steeljail/guard
	unique_door_name = "GULAG locked"
	locked = TRUE
	custom_code = RU_CODE
/obj/structure/simple_door/key_door/custom/jail/steeljail/guard/max
	unique_door_name = "Maximum Security locked"
	custom_code = RU_CODE+2
/obj/structure/simple_door/key_door/custom/jail/steeljail/guard/max/command
	unique_door_name = "Maximum Security - Command Only locked"
	custom_code = RU_CODE+8

/obj/structure/simple_door/key_door/custom/jail/steeljail/guard/open
	starts_open = TRUE
	locked = FALSE
	custom_code = RU_CODE
	New()
		..()
		icon_state = "cellopen"
		density = FALSE

#undef RU_CODE

#define NL_CODE 995 * 6
/datum/keyslot/dutch
	code = NL_CODE

/obj/item/weapon/key/dutch
	code = NL_CODE
	name = "Dutch key"

/obj/structure/simple_door/key_door/dutch
	keyslot_type = /datum/keyslot/dutch
	unique_door_name = "Dutch locked"
#undef NL_CODE



#define JP_CODE 995 * 6
/datum/keyslot/japanese
	code = JP_CODE

/obj/item/weapon/key/japanese
	code = JP_CODE
	name = "Japanese key"

/obj/structure/simple_door/key_door/japanese
	keyslot_type = /datum/keyslot/japanese
	unique_door_name = "Japanese locked"
#undef JP_CODE
#define JPABA_CODE 994 * 6
/datum/keyslot/abashiri
	code = JPABA_CODE

/obj/item/weapon/key/abashiri
	code = JPABA_CODE
	name = "Abashiri Guard key"

/obj/structure/simple_door/key_door/abashiri
	keyslot_type = /datum/keyslot/abashiri
	unique_door_name = "Abashiri locked"
	health = 900000

/obj/item/weapon/key/abashiri/head
	code = JPABA_CODE + 2
	name = "Abashiri Head Guard key"
/datum/keyslot/abashiri/head
	code = JPABA_CODE + 2
/obj/structure/simple_door/key_door/abashiri/head
	keyslot_type = /datum/keyslot/abashiri/head
	unique_door_name = "Abashiri locked"
	health = 900000
#undef JPABA_CODE

/obj/item/weapon/key/japanese/german////yeah ik i'm just lazy and already mapped so stfu bish
	name = "German Officer key"

#define JP_OFF_CODE 995 * 7
/datum/keyslot/japanese_officer
	code = JP_OFF_CODE

/obj/item/weapon/key/japanese_officer
	code = JP_OFF_CODE
	name = "Japanese Officer key"

/obj/structure/simple_door/key_door/japanese_officer
	keyslot_type = /datum/keyslot/japanese_officer
	unique_door_name = "Japanese locked"
#undef JP_OFF_CODE

#define DE_CODE 995 * 12
/datum/keyslot/german
	code = DE_CODE

/obj/item/weapon/key/german
	code = DE_CODE
	name = "German key"

/obj/structure/simple_door/key_door/german
	keyslot_type = /datum/keyslot/german
	unique_door_name = "German locked"

/obj/structure/simple_door/key_door/custom/jail/steeljail/german
	unique_door_name = "German locked"
	locked = TRUE
	custom_code = DE_CODE

/obj/structure/closet/crate/cash_register/germ
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "cash_register_antique"
	icon_opened = "cash_register_antique_opened"
	icon_closed = "cash_register_antique"
	custom_code = DE_CODE
	locked = TRUE

#undef DE_CODE

#define DE_CODE_OFF 995 * 1
/datum/keyslot/german/officer
	code = DE_CODE_OFF

/obj/item/weapon/key/german/officer
	code = DE_CODE_OFF
	name = "German Officer key"

/obj/structure/simple_door/key_door/german/officer
	keyslot_type = /datum/keyslot/german/officer
	unique_door_name = "German locked"
#undef DE_CODE_OFF

#define VC_CODE 995 * 8
/datum/keyslot/vietnamese
	code = VC_CODE

/obj/item/weapon/key/vietnamese
	code = VC_CODE
	name = "Vietnamese key"

/obj/structure/simple_door/key_door/vietnamese
	keyslot_type = /datum/keyslot/vietnamese
	unique_door_name = "Vietnamese locked"
#undef VC_CODE

#define CH_CODE 995 * 11
/datum/keyslot/chinese
	code = CH_CODE

/obj/item/weapon/key/chinese
	code = CH_CODE
	name = "Chinese key"

/obj/structure/simple_door/key_door/chinese
	keyslot_type = /datum/keyslot/chinese
	unique_door_name = "Chinese locked"
#undef CH_CODE

#define INS_CODE 995 * 9
/datum/keyslot/insurgent
	code = INS_CODE

/obj/item/weapon/key/insurgent
	code = INS_CODE
	name = "Insurgent key"

/obj/structure/simple_door/key_door/insurgent
	keyslot_type = /datum/keyslot/insurgent
	unique_door_name = "Insurgent locked"
#undef INS_CODE

#define US_CODE 995 * 10
/datum/keyslot/american
	code = US_CODE

/obj/item/weapon/key/american
	code = US_CODE
	name = "American key"

/obj/item/weapon/key/american/facility
	desc = "A Facility Key."
	name = "Facility key"

/obj/structure/simple_door/key_door/american
	keyslot_type = /datum/keyslot/american
	unique_door_name = "American locked"
#undef US_CODE


/obj/item/weapon/key/civ/police
	code = 13443
	name = "Police Officer key"
	health = 90000

/obj/item/weapon/key/civ/police/chief
	code = 13444
	name = "Police Chief key"

/datum/keyslot/police
	code = 13443

/datum/keyslot/police/chief
	code = 13444

/obj/structure/simple_door/key_door/civ/police
	keyslot_type = /datum/keyslot/police
	unique_door_name = "Police Station"
	locked = TRUE
	health = 90000

/obj/structure/simple_door/key_door/civ/police/chief
	keyslot_type = /datum/keyslot/police/chief
	unique_door_name = "Police Station"
	locked = TRUE
	health = 90000

/obj/structure/simple_door/key_door/custom/jail/steeljail/police
	unique_door_name = "jail cell"
	locked = TRUE
	custom_code = 13443
	health = 90000

/obj/item/weapon/key/civ/paramedics
	code = 12443
	name = "Hospital key"
	health = 90000

/datum/keyslot/paramedics
	code = 12443

/obj/structure/simple_door/key_door/civ/paramedics
	keyslot_type = /datum/keyslot/paramedics
	unique_door_name = "Hospital Door"
	locked = TRUE
	health = 90000

/obj/item/weapon/key/civ/mechanic
	code = 12448
	name = "Mechanic key"
	health = 90000

/datum/keyslot/mechanic
	code = 12448

/obj/structure/simple_door/key_door/civ/mechanic
	keyslot_type = /datum/keyslot/mechanic
	unique_door_name = "Mechanic Door"
	locked = TRUE
	health = 90000

/obj/item/weapon/key/civ/mckellen
	code = 211919
	name = "McKellen's key"

/datum/keyslot/mckellen
	code = 211919

/obj/structure/simple_door/key_door/civ/mckellen
	keyslot_type = /datum/keyslot/mckellen
	unique_door_name = "McKellen's"
	locked = TRUE
	health = 40000

/obj/item/weapon/key/civ/mckellen/manager
	code = 121922
	name = "McKellen's Manager key"

/datum/keyslot/mckellen/manager
	code = 121922

/obj/structure/simple_door/key_door/civ/mckellen/manager
	keyslot_type = /datum/keyslot/mckellen/manager
	unique_door_name = "McKellen's Manager"
	locked = TRUE
	health = 80000

/obj/structure/simple_door/key_door/custom/jail/woodjail/tribal
	unique_door_name = "Tribal Sealed Bars"
	locked = TRUE
	custom_code = 666999

/obj/item/weapon/key/tribal
	code = 666999
	name = "tribal key"

/datum/keyslot/tribal
	code = 666999