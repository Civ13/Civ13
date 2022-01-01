//overlay chat mostly ported from BurgerStation, 17/05/2020

#define TILE_SIZE 32

/client
	var/obj/chat_text/chat_text
	var/list/stored_chat_text = list()
	var/list/seen_chat_text = list()

/client/proc/overlay_cleaner(message = null)
	spawn(50)
		if (message)
			src.images -= message

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
		owner.seen_chat_text -= src
		owner = null
	if (target)
		target.stored_chat_text -= src
		target.seen_chat_text -= src
		target.images -= src.message
		target = null
	return ..()

/image/var/target = null
/image/var/owner = null

/obj/chat_text/New(var/mob/origin_loc, var/desired_text, var/mob/target_mob)
	..()
	loc = null
	if(isliving(origin_loc) && origin_loc.client && target_mob && target_mob.client)
		owner = origin_loc.client
		target = target_mob.client

		for (var/image/CT in target.images)
			if(CT.plane == CHAT_PLANE && CT.owner == owner)
				animate(CT,pixel_y = CT.pixel_y + 11,time = 1)

		message = image(loc = origin_loc)
		message.target = target
		message.owner = owner
		message.plane = CHAT_PLANE
		message.maptext_width = TILE_SIZE*7
		message.maptext_x = (maptext_width * -0.5)-TILE_SIZE*2.5
		message.maptext_y = TILE_SIZE*1
		message.maptext = "<center>[desired_text]</center>"
		if(target)
			target.images += message
			target.overlay_cleaner(message)
		spawn(50)
			animate(message,alpha=0,time=10)
			sleep(10)
			if(src)
				Destroy()
	else
		Destroy()

	return FALSE

//TTS stuff

var/global/sound_tts_num = 0

/mob/living/human/var/voice_pitch = 100
/mob/living/human/New()
	..()
	voice_pitch = rand(70,140)

/mob/proc/play_tts(message,var/mob/living/human/speaker)
	if (!message || message == "" || !client || !speaker)
		return
	message = replacetext(message, "&#39", "'")
	var/voice = "ap --setf duration_stretch=0.9 --setf int_f0_target_mean=100"
	if (!speaker.original_job)
		return
	if (speaker.gender == MALE)
		voice = "ap --setf duration_stretch=0.9 --setf int_f0_target_mean=[speaker.voice_pitch]"
	else
		voice = "slt --setf duration_stretch=0.9 --setf int_f0_target_mean=[speaker.voice_pitch]"
	sound_tts_num+=1
	var/genUID = sound_tts_num
	if (world.system_type != UNIX)
		shell("./tts/mimic -t \"[message]\" -voice [voice] -o [genUID].wav")
	else
		shell("mimic -t \"[message]\" -voice [voice] -o [genUID].wav")
	spawn(2)
		var/fpath = "[genUID].wav"
		if (fexists(fpath))
			if (client)
				src.playsound_local(loc,fpath,100)
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