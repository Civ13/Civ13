//ranged
#define DAMAGE_LOW 48
#define DAMAGE_MEDIUM 55
#define DAMAGE_MEDIUM_HIGH 60
#define DAMAGE_HIGH 80
#define DAMAGE_VERY_HIGH 100
#define DAMAGE_OH_GOD 200
//melee
#define WEAPON_FORCE_HARMLESS	3
#define WEAPON_FORCE_WEAK		7
#define WEAPON_FORCE_NORMAL	  10
#define WEAPON_FORCE_PAINFUL	15
#define WEAPON_FORCE_DANGEROUS   20
#define WEAPON_FORCE_ROBUST	  26
#define WEAPON_FORCE_LETHAL	  51

// Kinds of melee hit (code/game/objects/hit_kinds.dm). Armor resists each
// kind with the same-named armor key, or its "melee" value when it has none.
#define HIT_CUT "cut"
#define HIT_PIERCE "pierce"
#define HIT_BLUNT "blunt"

var/global_damage_modifier = 1