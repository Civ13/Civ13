//#define Clamp(value, low, high) 	(value <= low ? low : (value >= high ? high : value))
//#define CLAMP01(x) 		(Clamp(x, FALSE, TRUE))

/*
 Get the turf that `A` resides in, regardless of any containers.
 
 Use in favor of `A.loc` or `src.loc` so that things work correctly when
 stored inside an inventory, locker, or other container.
 */

#define get_turf(A) get_step(A,0)

/*
Get the ultimate area of `A`, similarly to [get_turf].

 Use instead of `A.loc.loc`.
 */

#define get_area(A) (isarea(A) ? A : get_step(A, 0)?.loc)

#define isdatum(A) istype(A, /datum)

#define isicon(A) istype(A, /icon)

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

//---------------------------------------------------

#define isanimal(A) istype(A, /mob/living/simple_animal)

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

#define isfloor(X) istype(X, /turf/floor)

// other
#define isclient(A) istype(A, /client)

// Tests if an datum has been deleted.
#define isDeleted(D) (!D || D:gcDestroyed)

#define to_chat(target, message)						to_chat_wrapper(target, message)
#define to_world(message)								to_chat_wrapper(world, message)
#define to_world_log(message)							world.log << message
#define sound_to(target, sound)							 target << sound
#define show_browser(target, browser_content, browser_name) target << browse(browser_content, browser_name)
#define send_rsc(target, rsc_content, rsc_name)			 target << browse_rsc(rsc_content, rsc_name)

#define CanInteract(user, state) (CanUseTopic(user, state) == STATUS_INTERACTIVE)

#define CanInteractWith(user, target, state) (target.CanUseTopic(user, state) == STATUS_INTERACTIVE)

#define CanPhysicallyInteract(user) CanInteract(user, GLOB.physical_state)

#define QDEL_NULL_LIST(x) if(x) { for(var/y in x) { qdel(y) } ; x = null }

#define ARGS_DEBUG log_debug("[__FILE__] - [__LINE__]") ; for(var/arg in args) { log_debug("\t[log_info_line(arg)]") }

// Helper macros to aid in optimizing lazy instantiation of lists.
// All of these are null-safe, you can use them without knowing if the list var is initialized yet

// Ensures L is initailized after this point
#define LAZYINITLIST(L) if (!L) L = list()
// Sets a L back to null iff it is empty
#define UNSETEMPTY(L) if (L && !L.len) L = null
// Removes I from list L, and sets I to null if it is now empty
#define LAZYREMOVE(L, I) if(L) { L -= I; if(!length(L)) { L = null; } }
// Adds I to L, initalizing L if necessary
#define LAZYADD(L, I) if(!L) { L = list(); } L += I;
// Adds I to L, initalizing L if necessary, if I is not already in L
#define LAZYDISTINCTADD(L, I) if(!L) { L = list(); } L |= I;
// Sets L[A] to I, initalizing L if necessary
#define LAZYSET(L, A, I) if(!L) { L = list(); } L[A] = I;
// Reads I from L safely - Works with both associative and traditional lists.
#define LAZYACCESS(L, I) (L ? (isnum(I) ? (I > 0 && I <= length(L) ? L[I] : null) : L[I]) : null)
// Reads the length of L, returning 0 if null
#define LAZYLEN(L) length(L)
// Null-safe L.Cut()
#define LAZYCLEARLIST(L) if(L) L.Cut()

#define OPPOSITE_DIR(D) turn(D, 180)
#define TURN_LEFT(D) turn(D, 90)
#define TURN_RIGHT(D) turn(D, -90)


#define SPAN(class, X) "<span class='[class]'>[X]</span>"
#define SPAN_NOTICE(X) SPAN("notice", X)
#define SPAN_WARNING(X) SPAN("warning", X)
#define SPAN_DANGER(X) SPAN("danger", X)
#define SPAN_RED(X) SPAN("red", X)
#define SPAN_BLUE(X) SPAN("blue", X)
#define SPAN_GREEN(X) SPAN("green", X)
#define SPAN_GREEN_BOLD(X) SPAN("green_bold", X)
#define SPAN_INFO(X) SPAN("info", X)
