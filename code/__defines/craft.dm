// The craft core (code/modules/craft/, docs/craft-core.md): one shared idea of
// "a thing that carries people from place to place" for ships, spacecraft and,
// later, trains, pods and airships.

// Who a berth welcomes.
#define BERTH_WELCOME_OWNERS "owners"
#define BERTH_WELCOME_GUESTS "guests"
#define BERTH_WELCOME_EVERYONE "everyone"

// How a register takes new crew.
#define CRAFT_JOIN_OPEN "open"
#define CRAFT_JOIN_ASK "ask"
#define CRAFT_JOIN_CLOSED "closed"

// Crew roles on a register, most senior first.
#define CRAFT_ROLE_CAPTAIN "captain"
#define CRAFT_ROLE_HELMSMAN "helmsman"
#define CRAFT_ROLE_ENGINEER "engineer"
#define CRAFT_ROLE_GUNNER "gunner"
#define CRAFT_ROLE_HAND "hand"

// Chart modes: tokens follow the real positions of their crafts, or crafts
// follow the tokens a helm steers.
#define CHART_MODE_MIRROR "mirror"
#define CHART_MODE_STEERED "steered"

// Tiles a chart token sees and is seen at, unless its craft says otherwise.
#define CHART_SENSOR_RANGE 40

// Whether a mob may take a craft's helm (craft.helm_access()): freely, by
// force while an owner is about, or not at all.
#define CRAFT_HELM_FREE 0
#define CRAFT_HELM_FORCE 1
#define CRAFT_HELM_CHAINED 2
