/**
 * Cooldown system based on storing world.time on a variable, plus the cooldown time.
 * Better performance over timer cooldowns, lower control. Same functionality.
 */

//Returns true if the cooldown has run its course, false otherwise
#define TIMER_COOLDOWN_END(cd_source, cd_index) LAZYREMOVE(cd_source.cooldowns, cd_index)
