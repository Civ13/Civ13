/mob/living/simple_animal/wizard
	name = "Llanboarwart Student"
	desc = "They look tired and damp."
	icon = 'icons/mob/npcs.dmi'
	icon_state = "wizard_base1"
	icon_living = "wizard_base1"
	icon_dead = "wizard_boy_dead"
	speak = list()
	speak_emote = list()
	emote_see = list("walks around", "waves his hands")
	meat_amount = 0
	attacktext = "hit"
	melee_damage_lower = 6
	melee_damage_upper = 9
	mob_size = MOB_MEDIUM
	possession_candidate = FALSE
	move_to_delay = 4
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak_chance = FALSE
	speed = 4
	maxHealth = 150
	health = 150
	stop_automated_movement_when_pulled = TRUE
	stop_automated_movement = TRUE
	wander = FALSE
	faction = "Unknown"
	var/image/clothing_colours = null

	var/list/flavour_text = list(
	"They say the deep slate mines are strictly off-limits to all students because of mortal danger. Which is weird, because we serve detention down there literally every Tuesday.",
	"I tried to prune the Shrieking Shrub yesterday for Madame Shrub's class. I haven't been able to hear out of my left ear since.",
	"I accidentally cast Barrelus! on my roommate last week. Honestly? He makes a much better wooden barrel than he ever did a student.",
	"The ghost that haunts the third-floor boys' lavatory won't stop complaining about the damp. We're in Wales! Everything is damp!",
	"One does not simply walk into the Headmaster's office. Mainly because the stairs move randomly and usually dump you straight into a coal chute.",
	"Everyone makes fun of Mustardweasel, but our common room is right next to the kitchens. Who's laughing at 2 AM when we have infinite cheese sandwiches?",
	"Franco Badfaith told me his father will hear about this. His father works in mid-level accounting in Cardiff, I don't know what he expects him to do.",
	"I asked a Slatepie student for help with my homework, and they just pushed up their glasses, stole my inkwell, and sighed loudly for five minutes straight.",
	"I wanted to be in Mintysnek, but The Placing Fedora told me I wasn't 'edgy' enough and dumped me in Mustardweasel.",
	"Madame McGronk just gave Rubywyrm fifty points because Barry Hatter tied his rugby boots correctly. This whole school is rigged.",
	"I paid three gold coins for a Choco-Toad and the stupid thing hopped right into a puddle of mud before I could eat it. What a scam.",
	"My parents are Nuggles. My dad still thinks I go to a highly exclusive boarding school for junior tax attorneys, not a leaky castle in Cwm-Pimple.",
	"Someone told me the Deadum! spell is unforgivable, but I saw Hagrag use it on a particularly large swamp rat just yesterday.",
	"I bought a pet from Hagrag. He said it was a rare Welsh Fire-Hound, but I'm pretty sure it's just a badger glued to a lighter.",
	"Don't drink more than three mugs of I-Can't-Believe-It's-Not-Butter-Beer. It doesn't actually have alcohol, it's just pure fermented corn syrup and green food dye.",
	"I used to be a star Mop Ball player for Rubywyrm, until I fell off my O-Cedar Master-Sweep and took a Sliceum! spell to the kneecap.",
	"People are so afraid of He-Who-Must-Not-Be-Named-For-Legal-Reasons. Just call him by his name! It's Gary! Oh wait, no, it's Lord Moldywart.",
	"I bought the 'Whippy Switch' wand because it looked cool, but it drained my Juice so fast I passed out face-first into my soup in the Great Hall.",
	"I keep trying to hold my wand, but some Mintysnek jerk keeps casting Dropus! from a balcony and stealing my lunch money.",
	"Harmonica Ranger corrected my pronunciation of Floatus! so harshly I actually felt my maximum health decrease from sheer embarrassment."
)
/mob/living/simple_animal/wizard/New()
	..()
	clothing_colours = image("icon" = 'icons/mob/suit.dmi', "icon_state" = "magic_boy_robe_decoration")
	icon_state = "wizard_base[rand(1,7)]"
	icon_living = icon_state
	icon_dead = "[icon_state]_dead"
	speak = flavour_text
	spawn(5)
		if (faction != "Unknown")
			switch(faction)
				if ("Mintysnek")
					clothing_colours.color = "#007F00"
				if ("Mustardweasel")
					clothing_colours.color = "#cbb600"
				if ("Slatepie")
					clothing_colours.color = "#0000c8"
				if ("Rubywyrm")
					clothing_colours.color = "#7F0000"
			src.overlays += clothing_colours
	update_icons()

/mob/living/simple_animal/wizard/death()
	..()
	src.overlays -= clothing_colours
	update_icons()

/mob/living/simple_animal/wizard/attack_hand(mob/user)
	var/spoken_text = pick(flavour_text)
	src.say(spoken_text)

/mob/living/simple_animal/wizard/rubywyrm
	faction = "Rubywyrm"
	name = "Rubywyrm student"

/mob/living/simple_animal/wizard/mintysnek
	faction = "Mintysnek"
	name = "Mintysnek student"

/mob/living/simple_animal/wizard/slatepie
	faction = "Slatepie"
	name = "Slatepie student"

/mob/living/simple_animal/wizard/mustardweasel
	faction = "Mustardweasel"
	name = "Mustardweasel student"