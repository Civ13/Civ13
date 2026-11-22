// ============================================================
// Rites (magic materials and enchanting plan, PR 9). Hidden mechanic: keep it
// out of changelog lines, the wiki and the public Crafting Atlas.
// ------------------------------------------------------------
// Each god writes up to 5 rites in Divine Patron (Set rites): an animal
// sacrifice, a food offering, a libation or an offering of art, each with what
// it asks for in a word or two. A magic user of that god leads a rite at one of
// its altars (Tend an Altar > Perform a rite), with no god's click when it is
// done as written. It feeds one of their tied repositories of that god a large
// amount at once, scaled by the altar's standing, through
// ward_refill(repo, amount, "rite") (400 a day at most per repository). Each
// rite kind counts once per repository per real day, and an artwork counts
// once ever. A rite done wrong simply finds no answer.
// ============================================================

#define ARCANE_RITES_MAX 5
#define ARCANE_RITES_FILE "data/divine_rites.json"
#define ARCANE_SACRIFICE_FRESH 6000   // deciseconds since the animal died
#define ARCANE_FOOD_DISHES 5

// Rite kind -> what the god and the magic user see it called.
var/global/list/arcane_rite_names = list(
	"animal" = "Animal sacrifice",
	"food" = "Food offering",
	"libation" = "Libation",
	"art" = "Art",
)

// Animals counted as livestock (60); other game 100; anything hostile 200.
var/global/list/arcane_livestock_words = list("cow", "ox", "bull", "goat", "sheep", "pig", "chicken", "hen", "horse", "camel", "llama", "duck", "turkey", "yak", "donkey", "goose")

// god key -> list of list("kind" = kind, "what" = word). Loaded on first use.
var/global/list/arcane_rites = null

/obj/item
	var/arcane_offered = FALSE      // saved: this artwork has been offered in a rite

/mob/living/simple_animal
	var/tmp/arcane_sacrificed = FALSE

/proc/arcane_rites_load()
	if (islist(arcane_rites))
		return arcane_rites
	arcane_rites = list()
	if (!fexists(ARCANE_RITES_FILE))
		return arcane_rites
	var/list/raw = null
	try
		raw = json_decode(file2text(ARCANE_RITES_FILE))
	catch
		raw = null
	if (!islist(raw))
		return arcane_rites
	for (var/god in raw)
		var/list/written = raw[god]
		if (!istext(god) || !islist(written))
			continue
		var/list/clean = list()
		for (var/list/R in written)
			if (islist(R) && arcane_rite_names[R["kind"]] && istext(R["what"]) && clean.len < ARCANE_RITES_MAX)
				clean += list(list("kind" = R["kind"], "what" = lowertext(copytext(R["what"], 1, 41))))
		if (clean.len)
			arcane_rites[god] = clean
	return arcane_rites

/proc/arcane_rites_save()
	var/list/L = arcane_rites_load()
	if (fexists(ARCANE_RITES_FILE))
		fdel(ARCANE_RITES_FILE)
	return text2file(json_encode(L), ARCANE_RITES_FILE)

/proc/arcane_rites_of(god)
	var/list/L = arcane_rites_load()
	var/list/R = L[god]
	return islist(R) ? R : list()

/proc/arcane_rite_label(list/R)
	return "[arcane_rite_names[R["kind"]]]: [R["what"]]"

/proc/arcane_word_in(word, text)
	return istext(word) && length(word) && istext(text) && findtext(lowertext(text), word)

// ---- What each rite asks for -------------------------------------------------

// What a rite would use and what it is worth, or null when it is not met:
// list("value" = charge before standing, "used" = things it uses up or marks).
/mob/living/human/proc/arcane_rite_check(obj/altar, list/R)
	var/turf/T = get_turf(altar)
	var/what = R["what"]
	switch (R["kind"])
		if ("animal")
			for (var/mob/living/simple_animal/A in range(1, T))
				if (A.stat == DEAD && !A.arcane_sacrificed && arcane_word_in(what, A.name) && A.timeofdeath && world.time - A.timeofdeath <= ARCANE_SACRIFICE_FRESH && world.time >= A.timeofdeath)
					var/value = 100
					if (istype(A, /mob/living/simple_animal/hostile))
						value = 200
					else
						for (var/word in arcane_livestock_words)
							if (arcane_word_in(word, A.name))
								value = 60
								break
					return list("value" = value, "used" = list(A))
		if ("food")
			var/list/dishes = list()
			for (var/obj/item/weapon/reagent_containers/food/snacks/F in T)
				if (dishes.len < ARCANE_FOOD_DISHES && arcane_word_in(what, F.name))
					dishes += F
			if (dishes.len)
				return list("value" = 30 * dishes.len, "used" = dishes)
		if ("libation")
			for (var/obj/item/weapon/reagent_containers/RG in list(get_active_hand(), get_inactive_hand()))
				if (!RG.reagents || RG.volume <= 0 || RG.reagents.total_volume < RG.volume * 0.9)
					continue
				var/datum/reagent/main = RG.reagents.get_master_reagent()
				if (main && (arcane_word_in(what, main.name) || arcane_word_in(what, main.id)))
					return list("value" = 40, "used" = list(RG))
		if ("art")
			for (var/obj/item/canvas/C in T)
				if (C.finished && C.author_ckey && !C.arcane_offered && (what == "any" || arcane_word_in(what, C.title) || arcane_word_in(what, C.name)))
					return list("value" = 100, "used" = list(C))
	return null

/proc/arcane_rite_consume(list/R, list/used)
	for (var/atom/A in used)
		switch (R["kind"])
			if ("animal")
				var/mob/living/simple_animal/S = A
				S.arcane_sacrificed = TRUE // the meat and hide stay to be butchered
			if ("food")
				qdel(A)
			if ("libation")
				var/obj/item/weapon/reagent_containers/RG = A
				RG.reagents.clear_reagents()
				RG.update_icon()
			if ("art")
				var/obj/item/I = A
				I.arcane_offered = TRUE // it stays as part of the shrine

// Called from Tend an Altar (arcane_altars.dm).
/mob/living/human/proc/arcane_rite_at(obj/O)
	var/god = O.arcane_altar_live()
	var/list/written = arcane_rites_of(god)
	if (!written.len)
		to_chat(src, SPAN_WARNING("Your god has asked for no rites."))
		return FALSE
	var/list/choices = list()
	for (var/list/R in written)
		choices[arcane_rite_label(R)] = R
	var/list/R = choices[player_input(src, "Which rite do you lead?", "Rite", null, "anything", choices, TRUE)]
	if (!R)
		return FALSE
	var/list/repos = list()
	for (var/obj/repo in magic_registered_repositories())
		if (repo.magic_repo_deity == god)
			repos["[repo.name] ([repo.magic_repo_id])"] = repo
	if (!repos.len)
		to_chat(src, SPAN_WARNING("You are tied to nothing it could reach."))
		return FALSE
	var/obj/target = repos.len == 1 ? repos[repos[1]] : repos[player_input(src, "For which?", "Rite", null, "anything", repos, TRUE)]
	if (!target || QDELETED(O) || !O.Adjacent(src) || O.arcane_altar_live() != god || !arcane_magic_user())
		return FALSE
	var/list/met = arcane_rite_check(O, R)
	if (!met)
		to_chat(src, SPAN_NOTICE("You go through the rite. <i>Nothing answers.</i>"))
		return FALSE
	target.magic_repo_roll_day()
	var/slot = "rite_[R["kind"]]"
	if (target.magic_repo_today[slot])
		to_chat(src, SPAN_NOTICE("You go through the rite. <i>It has had that today.</i>"))
		return FALSE
	visible_message("<span class='notice'>[src] performs a rite at [O].</span>", "<span class='notice'>You perform the rite at [O].</span>")
	if (!do_after(src, 100, O))
		return FALSE
	met = arcane_rite_check(O, R)
	if (!met || QDELETED(target) || target.magic_repo_today[slot] || O.arcane_altar_live() != god)
		to_chat(src, SPAN_NOTICE("<i>Nothing answers.</i>"))
		return FALSE
	var/amount = round(met["value"] * O.arcane_altar_percent() / 100)
	var/added = ward_refill(target, amount, "rite", src)
	if (!added)
		to_chat(src, SPAN_NOTICE("<i>Nothing more is taken today.</i>"))
		return FALSE
	target.magic_repo_today[slot] = 1
	var/list/names = list()
	for (var/atom/A in met["used"])
		names += "[A] ([A.type])"
	arcane_rite_consume(R, met["used"])
	O.arcane_altar_worship(src)
	log_game("[key_name(src)] led the rite [arcane_rite_label(R)] at an altar of [god] with [english_list(names)]: [added] charge to [target.magic_repo_id].")
	to_chat(src, SPAN_NOTICE("<i>The rite is accepted.</i>"))
	return TRUE

// Divine Patron > Set rites.
/client/proc/arcane_edit_rites(claim)
	var/list/current = list()
	for (var/list/R in arcane_rites_of(claim))
		current += list(R.Copy())
	while (TRUE)
		var/list/menu = list()
		for (var/i in 1 to current.len)
			menu["Remove: [arcane_rite_label(current[i])]"] = i
		if (current.len < ARCANE_RITES_MAX)
			menu["Add a rite"] = "add"
		menu["Done"] = "done"
		var/pick = player_input(src, "Rites of [divine_label_for(claim)] ([current.len] of [ARCANE_RITES_MAX]).", "Rites", null, "anything", menu, TRUE)
		var/choice = menu[pick]
		if (!choice || choice == "done")
			break
		if (isnum(choice))
			current.Cut(choice, choice + 1)
			continue
		var/list/kinds = list()
		for (var/kind in arcane_rite_names)
			kinds[arcane_rite_names[kind]] = kind
		var/kind = kinds[player_input(src, "What kind of rite?", "Rites", null, "anything", kinds, TRUE)]
		if (!kind)
			continue
		var/hint = list("animal" = "Which animal? A word from its name, such as goat or bear.", "food" = "Which dish? A word from its name, such as bread or cake.", "libation" = "Which drink? A word from its name, such as wine or milk.", "art" = "Which artwork? A word from its title, or any.")[kind]
		var/raw = player_input(src, hint, "Rites", null, "text", null, TRUE)
		var/what = raw ? lowertext(trim(sanitize(raw, 40))) : null
		if (what)
			current += list(list("kind" = kind, "what" = what))
	if (!check_rights(R_ADMIN) || divine_claim_of(src) != claim)
		return
	var/list/L = arcane_rites_load()
	if (current.len)
		L[claim] = current
	else
		L -= claim
	arcane_rites_save()
	var/list/labels = list()
	for (var/list/R in current)
		labels += arcane_rite_label(R)
	to_chat(src, SPAN_NOTICE("Rites saved."))
	log_admin("[key_name(src)] as [claim] set rites: [labels.len ? english_list(labels) : "none"].")

#undef ARCANE_RITES_MAX
#undef ARCANE_RITES_FILE
#undef ARCANE_SACRIFICE_FRESH
#undef ARCANE_FOOD_DISHES
