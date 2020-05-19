//overlay chat mostly ported from BurgerStation, 17/05/2020

#define TILE_SIZE 32

/client
	var/obj/chat_text/chat_text
	var/list/stored_chat_text = list()
	var/list/seen_chat_text = list()

/obj/chat_text
	name = "overlay"
	desc = "overlay object"
	plane = CHAT_PLANE
	icon = null

	var/client/owner
	var/client/target
	var/image/message
/obj/chat_text/Destroy()
	if (owner)
		owner.stored_chat_text -= src
		owner = null
	if (target)
		target.stored_chat_text -= src
		target = null
	return ..()

/obj/chat_text/New(var/atom/desired_loc, var/mob/origin_loc, var/desired_text, var/mob/target_mob)
	..()
	loc = null
	if(isliving(origin_loc) && origin_loc.client && target_mob && target_mob.client)
		owner = origin_loc.client
		if (!owner)
			return

		owner.stored_chat_text += src

/*
		//check the owner location in relation to who it is displayed to
		var/base_x = target_mob.x-8
		var/base_y = target_mob.y-8

		if (abs(origin_loc.x-base_x)>9 || abs(origin_loc.y-base_y)>9)
			qdel(src)
		screen_loc = "[origin_loc.x-base_x],[origin_loc.y-base_y]"
*/
		message = image(loc = origin_loc)
		message.plane = CHAT_PLANE
		message.maptext_width = TILE_SIZE*ceil(11*0.5)
		message.maptext_x = -(maptext_width-TILE_SIZE)*0.5
		message.maptext_y = TILE_SIZE*0.75
		message.maptext = "<center>[desired_text]</center>"
		target.images += message
		spawn(100)
			animate(src,alpha=0,time=10)
			sleep(10)
			if(src)
				if (target)
					target.seen_chat_text -= src
					target.images -= message
				if (owner)
					owner.stored_chat_text -= src
				qdel(src)

	else
		qdel(src)

	return FALSE
var/global/sound_tts_num = 0

/mob/proc/play_tts(message,var/mob/living/human/speaker)
	if (!message || message == "" || !client || !speaker)
		return
	var/voice = "Matthew"
	if (!speaker.original_job)
		return
	if (gender == MALE)
		voice = speaker.original_job.male_tts_voice
	else
		voice = speaker.original_job.female_tts_voice
	sound_tts_num+=1
	var/genUID = sound_tts_num
	shell("sudo python3 tts/amazontts.py \"[message]\" [voice] [genUID]")
	spawn(2)
		var/fpath = "[genUID].ogg"
		if (fexists(fpath))
			if (client)
				send_rsc(src, file(fpath), "loc-[genUID].ogg")
				client << sound("loc-[genUID].ogg")
			spawn(50)
				fdel(fpath)
		return


/////AMAZON AWS POLLY VOICES///////////////
/*
Arabic (arb)
Zeina		Female

Chinese, Mandarin (cmn-CN)
Zhiyu		Female

Danish (da-DK)
Naja		Female
Mads		Male

Dutch (nl-NL)
Lotte		Female
Ruben		Male

English (Australian) (en-AU)
Nicole		Female
Russell		Male

English (British) (en-GB)
Amy		Female
Emma		Female
Brian		Male

English (Indian) (en-IN)
Aditi		Female
Raveena		Female

English (US) (en-US)
Ivy		Female (child)
Joanna		Female
Kendra		Female
Kimberly		Female
Salli		Female
Joey		Male
Justin		Male (child)
Matthew		Male

English (Welsh) (en-GB-WLS)
Geraint		Male

French (fr-FR)
Céline/Celine		Female
Léa	Femal
Mathieu		Male

French (Canadian) (fr-CA)
Chantal		Female

German (de-DE)
Marlene		Female
Vicki		Female
Hans		Male

Hindi (hi-IN)
Aditi*		Female

Icelandic (is-IS)
Dóra/Dora		Female
Karl		Male

Italian (it-IT)
Carla		Female
Bianca		Female
Giorgio		Male

Japanese (ja-JP)
Mizuki		Female
Takumi		Male

Korean (ko-KR)
Seoyeon		Female

Norwegian (nb-NO)
Liv		Female

Polish (pl-PL)
Ewa		Female
Maja		Female
Jacek		Male
Jan		Male

Portuguese (Brazilian) (pt-BR)
Camila		Female
Vitória/Vitoria		Female
Ricardo		Male

Portuguese (European) (pt-PT)
Inês/Ines		Female
Cristiano		Male

Romanian (ro-RO)
Carmen		Female

Russian (ru-RU)
Tatyana		Female
Maxim		Male

Spanish (European) (es-ES)
Conchita		Female
Lucia		Female
Enrique		Male

Spanish (Mexican) (es-MX)
Mia		Female

US Spanish (es-US)
Lupe		Female
Penelope		Female
Miguel		Male

Swedish (sv-SE)
Astrid		Female

Turkish (tr-TR)
Filiz		Female

Welsh (cy-GB)
Gwyneth		Female

*/