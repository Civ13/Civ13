/* none of these constants should be == 0, because change_weather(weather)
 breaks if weather == null */

#define WEATHER_NONE 1
#define WEATHER_RAIN 2
#define WEATHER_SNOW 3
#define WEATHER_BLIZZARD 4
#define WEATHER_SANDSTORM 5
#define WEATHER_STORM 6
#define WEATHER_SMOG 7
#define WEATHER_CONST2TEXT(constant) (constant == WEATHER_NONE ? "NONE" : constant == WEATHER_RAIN ? "RAIN" : constant == WEATHER_SNOW ? "SNOW" : constant == WEATHER_BLIZZARD ? "BLIZZARD" : constant == WEATHER_SANDSTORM ? "SANDSTORM" : constant == WEATHER_STORM ? "STORM" : constant == WEATHER_SMOG ? "SMOG" : "NONE")