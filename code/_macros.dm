//#define Clamp(value, low, high) 	(value <= low ? low : (value >= high ? high : value))
//#define CLAMP01(x) 		(Clamp(x, FALSE, TRUE))

#define isdatum(A) istype(A, /datum)

#define isimage(A) istype(A, /image)

#define isicon(A) istype(A, /icon)

#define isscreen(A) istype(A, /obj/screen)

#define ishud(A) istype(A, /obj/screen)

//MOB LEVEL

#define ismob(A) istype(A, /mob)

#define isobserver(A) istype(A, /mob/observer)

#define isghost(A) istype(A, /mob/observer/ghost)

#define isEye(A) istype(A, /mob/observer/eye)

#define isnewplayer(A) istype(A, /mob/new_player)
//++++++++++++++++++++++++++++++++++++++++++++++

#define isliving(A) istype(A, /mob/living)
//---------------------------------------------------

#define ishuman(A) istype(A, /mob/living/human)

#define isbrain(A) istype(A, /mob/living/human/brain)

//---------------------------------------------------

#define isanimal(A) istype(A, /mob/living/simple_animal)

#define iscorgi(A) istype(A, /mob/living/simple_animal/corgi)

#define ismouse(A) istype(A, /mob/living/simple_animal/mouse)
//---------------------------------------------------

//OBJECT LEVEL
#define isobj(A) istype(A, /obj)

#define isstructure(A) istype(A, /obj/structure)

#define isnonstructureobj(A) (isobj(A) && !isstructure(A))


#define isorgan(A) istype(A, /obj/item/organ/external)

#define isitem(A) istype(A, /obj/item)

#define iscloset(A) istype(A, /obj/structure/closet)

#define islist(A) istype(A, /list)

#define isatom(A) istype(A, /atom)
#define ismovable(A) istype(A, /atom/movable)

#define attack_animation(A) if (istype(A)) A.do_attack_animation(src)

//TURF LEVEL

#define iswall(X) istype(X, /turf/wall)

#define isfloor(X) istype(X, /turf/floor)

#define istrueflooring(X) (isfloor(X) && !istype(X, /turf/floor/plating))

// other
#define isclient(A) istype(A, /client)

// Tests if an datum has been deleted.
#define isDeleted(D) (!D || D:gcDestroyed)

#define forrange(x) for (var/v = 1 to x)

#define to_chat(target, message)							target << message
#define to_world(message)								   world << message
#define to_world_log(message)							   world.log << message
#define sound_to(target, sound)							 target << sound
#define show_browser(target, browser_content, browser_name) target << browse(browser_content, browser_name)
#define close_browser(target, browser_name)                 target << browse(null, browser_name)
#define show_image(target, image)                           target << (image)
#define send_rsc(target, rsc_content, rsc_name)             target << browse_rsc(rsc_content, rsc_name)

// Helper macros to aid in optimizing lazy instantiation of lists.
// All of these are null-safe, you can use them without knowing if the list var is initialized yet

//Picks from the list, with some safeties, and returns the "default" arg if it fails
#define DEFAULTPICK(L, default) ((istype(L, /list) && L:len) ? pick(L) : default)
// Ensures L is initailized after this point
#define LAZYINITLIST(L) if (!L) L = list()
// Sets a L back to null iff it is empty
#define UNSETEMPTY(L) if (L && !L.len) L = null
// Removes I from list L, and sets I to null if it is now empty
#define LAZYREMOVE(L, I) if(L) { L -= I; if(!length(L)) { L = null; } }
// Adds I to L, initalizing L if necessary
#define LAZYADD(L, I) if(!L) { L = list(); } L += I;
// Insert I into L at position X, initalizing L if necessary
#define LAZYINSERT(L, I, X) if(!L) { L = list(); } L.Insert(X, I);
// Adds I to L, initalizing L if necessary, if I is not already in L
#define LAZYDISTINCTADD(L, I) if(!L) { L = list(); } L |= I;
// Sets L[A] to I, initalizing L if necessary
#define LAZYSET(L, A, I) if(!L) { L = list(); } L[A] = I;
// Reads I from L safely - Works with both associative and traditional lists.
#define LAZYACCESS(L, I) (L ? (isnum(I) ? (I > 0 && I <= length(L) ? L[I] : null) : L[I]) : null)
// Reads the length of L, returning 0 if null
#define LAZYLEN(L) length(L)
// Safely checks if I is in L
#define LAZYISIN(L, I) (L ? (I in L) : FALSE)
// Null-safe L.Cut()
#define LAZYCLEARLIST(L) if(L) L.Cut()
// Reads L or an empty list if L is not a list.  Note: Does NOT assign, L may be an expression.
#define SANITIZE_LIST(L) ( islist(L) ? L : list() )

// Insert an object A into a sorted list using cmp_proc (/code/_helpers/cmp.dm) for comparison.
#define ADD_SORTED(list, A, cmp_proc) if(!list.len) {list.Add(A)} else {list.Insert(FindElementIndex(A, list, cmp_proc), A)}

#define OPPOSITE_DIR(D) turn(D, 180)
#define TURN_LEFT(D) turn(D, 90)
#define TURN_RIGHT(D) turn(D, -90)


#define SPAN(class, X) "<span class='[class]'>[X]</span>"
#define SPAN_NOTICE(X) SPAN("notice", X)
#define SPAN_WARNING(X) SPAN("warning", X)
#define SPAN_DANGER(X) SPAN("danger", X)
