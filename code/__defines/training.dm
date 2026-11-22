// Continuous training (Val, 2026-11-22): practice tools, lifting weights, the
// skipping rope and floor exercises keep going once started, draining the
// stamina pool, until the player stops, moves, swaps the item or runs out.
// TRAINING_STAMINA_DRAIN is the share of maximum stamina spent per second of
// training. Natural recovery pauses during a session (human_life.dm), so a
// rested character trains for roughly four minutes before getting winded.
#define TRAINING_STAMINA_DRAIN 0.004
// Share of maximum stamina needed to start a session, so a tired character
// does not stutter through one tick at a time.
#define TRAINING_STAMINA_START 0.2
