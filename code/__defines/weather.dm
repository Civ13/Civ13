/* none of these constants should be == 0, because change_weather(weather)
 breaks if weather == null */

#define WEATHER_NONE 1
#define WEATHER_RAIN 2
#define WEATHER_SNOW 3
#define WEATHER_CONST2TEXT(constant) (constant == WEATHER_NONE ? "NONE" : constant == WEATHER_RAIN ? "RAIN" : constant == WEATHER_SNOW ? "SNOW" : "NONE")