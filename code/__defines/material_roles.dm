// Material properties and part roles (docs/material-roles.md).
//
// A material says how it can be shaped (SHAPE_* in /material/var/shaping);
// a part role (ROLE_* ids, /datum/part_role) turns a material's properties
// into how well it does one job. Ask part_rating(ROLE_X, "bronze") instead
// of naming one material in code.
#define SHAPE_KNAPPED  (1<<0) // struck to shape: flint, obsidian
#define SHAPE_CARVED   (1<<1) // cut by hand: wood, bone, stone
#define SHAPE_FIRED    (1<<2) // shaped wet and fired: clay
#define SHAPE_CAST     (1<<3) // poured into a mould
#define SHAPE_FORGED   (1<<4) // hammered hot at an anvil
#define SHAPE_MACHINED (1<<5) // cut on a lathe
#define SHAPE_MOULDED  (1<<6) // pressed or injected: plastic
#define SHAPE_SEWN     (1<<7) // cut and sewn: leather, cloth

#define ROLE_EDGE      "edge"      // knife, axe, saw, chisel, pick
#define ROLE_WORK_HEAD "work_head" // pick, axe or shovel head: driven hard into things
#define ROLE_STRIKER   "striker"   // hammer, mallet
#define ROLE_HANDLE    "handle"    // handle, lever
#define ROLE_GEAR      "gear"
#define ROLE_BEARING   "bearing"
#define ROLE_SPRING    "spring"    // coil or leaf spring in a mechanism
#define ROLE_LIMB      "limb"      // bow or crossbow limb
#define ROLE_PIPE      "pipe"
#define ROLE_VESSEL    "vessel"    // boiler, pot, tank
#define ROLE_CONDUCTOR "conductor" // wire, cable
#define ROLE_WHEEL     "wheel"
#define ROLE_FRAME     "frame"     // rated by the vehicle materials work
#define ROLE_PLATE     "plate"     // rated by the vehicle materials work

// Bounds on a rating: a poor material is slow, never useless; a good one is
// never a must-have.
#define PART_PERFORMANCE_MIN 0.25
#define PART_PERFORMANCE_MAX 1.25
#define PART_LIFETIME_MIN 0.05
#define PART_LIFETIME_MAX 2
// Below this toughness a material cracks in a role that takes shocks.
#define PART_FRAGILE_TOUGHNESS 10
// Below this firmness a material smears or strips as a gear, bearing or wheel.
#define PART_SOFT_FIRMNESS 18
