// When you want to qdel something after some time.
#define QDEL_IN(item, time) addtimer(CALLBACK(GLOBAL_PROC, .proc/qdel, item), time, TIMER_STOPPABLE)

// When you want to qdel something after some time but based on how clients see time, not how the server sees time.
#define QDEL_IN_CLIENT_TIME(item, time) addtimer(CALLBACK(GLOBAL_PROC, .proc/qdel, item), time, TIMER_STOPPABLE | TIMER_CLIENT_TIME)

// When you want to qdel something and then null the reference.
#define QDEL_NULL(item) qdel(item); item = null

// When you want to qdel everything in a list.
#define QDEL_LIST(L) if(L) { for(var/I in L) qdel(I); L.Cut(); }

// Combination of QDEL_IN and QDEL_LIST_ASSOC
#define QDEL_LIST_IN(L, time) addtimer(CALLBACK(GLOBAL_PROC, .proc/______qdel_list_wrapper, L), time, TIMER_STOPPABLE)

// QDEL_LIST but it deletes everything on both sides of the list.
#define QDEL_LIST_ASSOC(L) if(L) { for(var/I in L) { qdel(L[I]); qdel(I); } L.Cut(); }

// QDEL_LIST_ASSOC but it deletes everything on the value side of the list.
#define QDEL_LIST_ASSOC_VAL(L) if(L) { for(var/I in L) qdel(L[I]); L.Cut(); }

/proc/______qdel_list_wrapper(list/L) // The underscores are to encourage people not to use this directly. Should never be directly used.
	QDEL_LIST(L)
