
var/list/dreams = list(
	"a mountain", "Home", "Homeland", "a vast sea", "a black sky", "decaying flesh", "Full Moon", "Crescent Moon", "a calm river", "a dying friend", "a burning flame", "a strange people", "a bright glow", "a forest", "a valley", "a ravine", "famine", "death", "conflict", "falling", "a pale man", "a great horned beast", "a burning man", "an entity", "a Curse", "a great white fish", "a pond", "a city", "a tribe", "a council", "a lake", "a skull", "a cross", "a green land", "a dead land", "a cold land", "a source of wealth", "life", "a fallen kingdom", "a god of", "suffering", "agriculture", "fish", "demon", "bird", "spirit", "commerce", "a clear sky", "an invader", "a murder", "hate", "desire for", "power", "a giant bird", "a pile of gold", "a chilling wind", "a foreigner", "a defeated foe", "a wound", "conquest", "freedom", "a disgrace", "a schism", "a bond", "an ancestor", "a descendant", "a narrow stream", "a white cloud", "a group of grey clouds", "a distant scream", "a rotten skull on a stick", "blood", "resources", "a tall pale beast of hunger", "a lost child", "a meadow", "a wetland", "a tree", "a fallen tree", "a strange plant", "a feeling of helplessness", "a feeling of harmony", "a black liquid", "a large lizard", "a bright light"
	)

/mob/living/human/proc/dream()
	dreaming = TRUE

	spawn(0)
		for (var/i = rand(1,4),i > 0, i--)
			src << "<span class = 'notice'><i>... [pick(dreams)] ...</i></span>"
			sleep(rand(40,70))
			if (paralysis <= 0)
				dreaming = FALSE
				return FALSE
		dreaming = FALSE
		return TRUE

/mob/living/human/proc/handle_dreams()
	if (client && !dreaming && prob(5))
		dream()

/mob/living/human/var/dreaming = FALSE
