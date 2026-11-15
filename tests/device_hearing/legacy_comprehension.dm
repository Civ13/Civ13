	//non-verbal languages are garbled if you can't see the speaker. Yes, this includes if they are inside a closet.
	if (language && (language.flags & NONVERBAL))
		if (!speaker || (sdisabilities & BLIND) || blinded || find_trait("Blind") || !(speaker in view(src)))
			message = stars(message)

	if (!(language && (language.flags & INNATE))) // skip understanding checks for INNATE languages
		if (!say_understands(speaker,language))
			if (istype(speaker,/mob/living/simple_animal))
				var/mob/living/simple_animal/S = speaker
				if (S.speak && S.speak.len)
					message = pick(S.speak)
				else
					return
			else
				if (language)
					message = language.scramble(message, src)
				else
					message = stars(message)
