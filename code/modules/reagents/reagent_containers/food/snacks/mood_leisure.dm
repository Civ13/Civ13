// Small pleasures that lift mood: a book worth reading and a meal at a table.
// Included after book_reader.dm and snacks.dm, whose procs these wrap. The
// lift itself is /mob/living/human/proc/mood_leisure() in mood_living.dm.

#define LEISURE_READ 5        // mood from reading a written book
#define LEISURE_READ_GAP 12000 // at most once in twenty minutes
#define LEISURE_READ_LENGTH 200 // characters that make a book worth reading
#define LEISURE_TABLE 3       // mood from a meal eaten at a table
#define LEISURE_TABLE_GAP 6000 // at most once in ten minutes

// Reading a book with something written in it is a pleasure.
/obj/item/weapon/book/present_book_reader(mob/reader, legacy_snapshot, visible_snapshot, title_snapshot, name_snapshot)
	. = ..()
	var/mob/living/human/H = reader
	if (. && istype(H) && length(visible_snapshot) >= LEISURE_READ_LENGTH)
		H.mood_leisure("a good read", LEISURE_READ, LEISURE_READ_GAP)

// So is a meal eaten at a table rather than on the move.
/obj/item/weapon/reagent_containers/food/snacks/On_Consume(mob/M)
	. = ..()
	var/mob/living/human/H = M
	if (istype(H) && satisfaction > 0 && (locate(/obj/structure/table) in range(1, H)))
		H.mood_leisure("a meal at a table", LEISURE_TABLE, LEISURE_TABLE_GAP)

#undef LEISURE_READ
#undef LEISURE_READ_GAP
#undef LEISURE_READ_LENGTH
#undef LEISURE_TABLE
#undef LEISURE_TABLE_GAP
