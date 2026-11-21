// Combat stances (code/game/mob/combat_stance.dm): the attacker's stance picks
// the body part a melee attack goes for. Manual keeps the zone doll's choice.
#define COMBAT_STANCE_MANUAL "manual"
#define COMBAT_STANCE_MEASURED "measured"
#define COMBAT_STANCE_AGGRESSIVE "aggressive"
#define COMBAT_STANCE_DISARMING "disarming"
#define COMBAT_STANCE_LOW "low"
#define COMBAT_STANCE_GUARDED "guarded"
#define COMBAT_STANCE_RESTRAIN "restrain"

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

// Reaction triggers (code/game/mob/combat_reactions.dm).
#define COMBAT_TRIGGER_INCOMING "incoming"
#define COMBAT_TRIGGER_GRAB_REACH "grab reach"
#define COMBAT_TRIGGER_AFTER_PARRY "after parry"
#define COMBAT_TRIGGER_AFTER_HIT "after hit"
// Stance reactions: skill needed (getStatCoeff, 1 = average), cooldown, stamina.
#define COMBAT_REACTION_SKILL 1.2
#define COMBAT_REACTION_COOLDOWN 40
#define COMBAT_REACTION_STAMINA 5
// Martial reflexes (martial arts plan): idle time, cooldown, stamina.
#define MARTIAL_REFLEX_IDLE 20
#define MARTIAL_REFLEX_COOLDOWN 20
#define MARTIAL_REFLEX_STAMINA 4
// Restrain stance (code/game/mob/combat_restrain.dm): time to bind the legs,
// gag or blindfold.
#define COMBAT_RESTRAIN_TIE_TIME 20
