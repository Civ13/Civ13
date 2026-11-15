/* none of these constants should be == 0, because change_weather(weather)
 breaks if weather == null */

/*
#define WEATHER_NONE 1
#define WEATHER_RAIN 2
#define WEATHER_SNOW 3
#define WEATHER_BLIZZARD 4
#define WEATHER_SANDSTORM 5
#define WEATHER_STORM 6
#define WEATHER_SMOG 7
*/
#define WEATHER_NONE 1
#define WEATHER_WET 2
#define WEATHER_EXTREME 3
#define WEATHER_SMOG 4

// Moving weather systems (code/modules/1713/weather_systems.dm).
#define WEATHER_SYSTEM_MAX 6
#define WEATHER_SYSTEM_STORM "storm"
#define WEATHER_SYSTEM_HEAT "heat"
// Strength under which a system is only cloud, and where its bands begin.
#define WEATHER_BAND_LIGHT 0.12
#define WEATHER_BAND_STEADY 0.4
#define WEATHER_BAND_HEAVY 0.7
// How far ahead of its edge a storm is seen coming, in tiles.
#define WEATHER_WARNING_RANGE 45
