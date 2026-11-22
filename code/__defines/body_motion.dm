// Whole-body motion (code/game/mob/living/carbon/human/body_motion.dm).
// Character sprites stay static; short animate() motions on the mob's
// transform tilt, shift and settle the whole body, overlays included.

// Server-wide level, set by the BODY_MOTION config line.
#define BODY_MOTION_OFF 0
#define BODY_MOTION_REDUCED 1 // only motions that carry gameplay information
#define BODY_MOTION_FULL 2

// A running motion is replaced only by one of equal or higher priority.
#define BODY_MOTION_PRIORITY_STRIDE 0 // step motions: the heavy-haul heave and the sneaking crouch
#define BODY_MOTION_PRIORITY_LOW 1 // emotes, work
#define BODY_MOTION_PRIORITY_COMBAT 2 // swings, recoil
#define BODY_MOTION_PRIORITY_POSTURE 3 // falling and standing up

// Fewest deciseconds between two motion starts on one body, posture excepted.
// A higher priority motion than the last one is never held back by it.
#define BODY_MOTION_MIN_GAP 2
// A body is animated only when a player is this close on its level.
#define BODY_MOTION_WATCH_RANGE 12
// Every body motion runs as this named parallel sequence, so a new motion
// replaces the running one while lunges and glides keep their own sequences.
#define BODY_MOTION_TAG "body_motion"
