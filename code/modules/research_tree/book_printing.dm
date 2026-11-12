// ============================================================
// Research Tree - printing whole books (Persistence redesign, Val 2026-11-10)
// ------------------------------------------------------------
// A printing press copies an ordinary book whole: its written pages, its
// title and author, and every finished research chapter. The copy is
// printed into a blank book loaded as the press's copy, and each chapter
// uses one sheet of printing paper (paper or parchment) loaded into the
// press. Unfinished research stays with the original; it is still being
// written, not printed.
// ============================================================

#define PRESS_PRINT_TIME 250
#define PRESS_SHEET_MAX 100

/obj/structure/printingpress
	var/printing_sheets = 0 // blank sheets loaded for printing chapters

/obj/structure/printingpress/examine(mob/user, distance = -1)
	. = ..()
	if (printing_sheets > 0)
		to_chat(user, SPAN_NOTICE("It is loaded with [printing_sheets] sheet\s of printing paper."))

/obj/structure/printingpress/Destroy()
	var/turf/place = get_turf(src)
	if (place)
		for (var/i = 1, i <= printing_sheets, i++)
			new /obj/item/weapon/paper(place)
	printing_sheets = 0
	return ..()

// Ordinary writable books print whole. Holy books, legacy skill scrolls,
// language books and recipe manuals keep their own press handling.
/proc/press_prints_whole_book(obj/item/weapon/book/B)
	return istype(B) && !B.unique && !istype(B, /obj/item/weapon/book/holybook) && !istype(B, /obj/item/weapon/book/research) && !istype(B, /obj/item/weapon/book/language_book) && !istype(B, /obj/item/weapon/book/node_book) && !istype(B, /obj/item/weapon/book/node_compendium)

/obj/structure/printingpress/proc/load_printing_sheet(obj/item/weapon/paper/P, mob/living/user)
	if (!blank_writing_sheet(P) || P.loc != user || copying)
		return FALSE
	if (printing_sheets >= PRESS_SHEET_MAX)
		to_chat(user, SPAN_WARNING("[src] can't hold any more printing paper."))
		return FALSE
	var/sheet_name = P.name
	user.remove_from_mob(P)
	qdel(P)
	printing_sheets++
	to_chat(user, SPAN_NOTICE("You load the [sheet_name] into [src] as printing paper ([printing_sheets] loaded)."))
	return TRUE

// Empties a paper bin's blank sheets into the press.
/obj/structure/printingpress/proc/load_paper_bin(obj/item/weapon/paper_bin/bin, mob/living/user)
	if (!istype(bin) || copying)
		return FALSE
	var/loaded = 0
	for (var/obj/item/weapon/paper/P in bin.papers.Copy())
		if (printing_sheets >= PRESS_SHEET_MAX)
			break
		if (!blank_writing_sheet(P))
			continue
		bin.papers -= P
		bin.amount--
		qdel(P)
		printing_sheets++
		loaded++
	var/fresh = max(0, bin.amount - bin.papers.len)
	var/take = min(fresh, PRESS_SHEET_MAX - printing_sheets)
	if (take > 0)
		bin.amount -= take
		printing_sheets += take
		loaded += take
	bin.update_icon()
	if (!loaded)
		to_chat(user, SPAN_WARNING("[bin] has no blank sheets [src] can use."))
		return FALSE
	to_chat(user, SPAN_NOTICE("You load [loaded] sheet\s from [bin] into [src] ([printing_sheets] loaded)."))
	return TRUE

// Loads a bundle's blank sheets into the press; written pages stay clipped.
/obj/structure/printingpress/proc/load_paper_bundle(obj/item/weapon/paper_bundle/B, mob/living/user)
	if (!istype(B) || copying)
		return FALSE
	var/loaded = 0
	var/bundle_name = B.name
	for (var/obj/item/weapon/paper/P in bundle_blank_sheets(B))
		if (printing_sheets >= PRESS_SHEET_MAX)
			break
		if (!bundle_release_sheet(B, P))
			continue
		qdel(P)
		printing_sheets++
		loaded++
	if (!loaded)
		to_chat(user, SPAN_WARNING(printing_sheets >= PRESS_SHEET_MAX ? "[src] can't hold any more printing paper." : "The [bundle_name] has no blank sheets [src] can use."))
		return FALSE
	to_chat(user, SPAN_NOTICE("You load [loaded] sheet\s from the [bundle_name] into [src] ([printing_sheets] loaded)."))
	return TRUE

// Returns a reason the original can't be printed into stock, or null.
/obj/structure/printingpress/proc/whole_book_print_problem(obj/item/weapon/book/original, obj/item/weapon/book/stock)
	if (!press_prints_whole_book(original) || !istype(stock) || original == stock)
		return "Both documents must be ordinary books."
	if (!stock.monk_copy_blank())
		return "The copy must be a blank book."
	if (!original.dat && !length(original.page_list()) && !length(original.research_chapter_list()))
		return "There is nothing written in [original] to print."
	var/needed = length(original.research_chapter_list())
	if (printing_sheets < needed)
		return "Printing [original] needs [needed] sheet\s of printing paper, one per chapter; [src] has [printing_sheets]. Load blank paper or parchment first."
	return null

/obj/structure/printingpress/proc/print_whole_book(mob/living/human/H)
	if (copying || !istype(H) || !Adjacent(H) || H.incapacitated() || !islist(base) || !islist(copy) || base.len != 1 || copy.len != 1)
		return FALSE
	var/obj/item/weapon/book/original = base[1]
	var/obj/item/weapon/book/stock = copy[1]
	var/problem = whole_book_print_problem(original, stock)
	if (problem)
		to_chat(H, SPAN_WARNING(problem))
		return FALSE
	copying = TRUE
	icon_state = "printingpress1"
	visible_message("Printing \the [original]...")
	var/done = do_after(H, PRESS_PRINT_TIME, src)
	if (!src || gcDestroyed)
		return FALSE
	copying = FALSE
	icon_state = "printingpress0"
	if (!done || !Adjacent(H) || base.len != 1 || copy.len != 1 || base[1] != original || copy[1] != stock)
		return FALSE
	return finish_whole_book_print(H)

// Prints base into copy once the press has run. Rechecks everything, since
// chapters or paper may have changed while it ran.
/obj/structure/printingpress/proc/finish_whole_book_print(mob/user)
	if (!islist(base) || !islist(copy) || base.len != 1 || copy.len != 1)
		return FALSE
	var/obj/item/weapon/book/original = base[1]
	var/obj/item/weapon/book/stock = copy[1]
	var/problem = whole_book_print_problem(original, stock)
	if (problem)
		if (user)
			to_chat(user, SPAN_WARNING(problem))
		return FALSE
	var/list/chapters = original.research_chapter_list()
	var/turf/place = get_turf(src)
	var/obj/item/weapon/book/printed = new /obj/item/weapon/book(place)
	printed.title = original.title
	printed.author = original.author
	printed.due_date = original.due_date
	if (original.title)
		printed.name = original.name
	var/list/pages = original.page_list()
	printed.written_pages = pages.Copy()
	printed.rebuild_dat()
	for (var/node_id in chapters)
		printed.add_research_chapter(node_id)
	printed.copy_cipher_from(original)
	printing_sheets -= chapters.len
	base -= original
	copy -= stock
	original.loc = place
	qdel(stock)
	visible_message("The printing press finishes printing \the [original][chapters.len ? ", using [chapters.len] sheet\s of paper" : ""].")
	return printed

#undef PRESS_PRINT_TIME
#undef PRESS_SHEET_MAX
