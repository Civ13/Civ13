// Combat stances (code/game/mob/combat_stance.dm): the attacker's stance picks
// the body part a melee attack goes for. Manual keeps the zone doll's choice.
#define COMBAT_STANCE_MANUAL "manual"
#define COMBAT_STANCE_MEASURED "measured"
#define COMBAT_STANCE_AGGRESSIVE "aggressive"
#define COMBAT_STANCE_DISARMING "disarming"
#define COMBAT_STANCE_LOW "low"
#define COMBAT_STANCE_GUARDED "guarded"

// What kind of attack is choosing a zone.
#define COMBAT_ATTACK_WEAPON 1
#define COMBAT_ATTACK_PUNCH 2
#define COMBAT_ATTACK_KICK 3
#define COMBAT_ATTACK_GRAB 4
#define COMBAT_ATTACK_SHOVE 5

// How long an opponent's last attack on you can still be read (deciseconds).
#define COMBAT_READ_WINDOW 50
// How long the zone doll shows an automatic pick (deciseconds).
#define COMBAT_DOLL_FLASH_TIME 8
