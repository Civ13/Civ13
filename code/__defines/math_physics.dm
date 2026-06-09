// Math constants.
#define M_PI	3.14159265

#define R_IDEAL_GAS_EQUATION	   8.31	// kPa*L/(K*mol).
#define ONE_ATMOSPHERE			 101.325 // kPa.
#define IDEAL_GAS_ENTROPY_CONSTANT 1164	// (mol^3 * s^3) / (kg^3 * L).

#define TICK_DELTA_TO_MS(percent_of_tick_used) ((percent_of_tick_used) * world.tick_lag)

// The highest number supported is a signed 32-bit floating point number.
// Integers beyond the 24 bit range are represented as single-precision floating points, and thus will lose accuracy beyond the range of +/- 16777216
#define SHORT_REAL_LIMIT 16777216

#define CEILING(x, y) ( -round(-(x) / (y)) * (y) )

#define Clamp(x, y, z) 	(x <= y ? y : (x >= z ? z : x)) // Ensures that a value (x) is within a specified range (y to z). If x is less than y, it returns y; if x is greater than z, it returns z; otherwise, it returns x. This effectively clamps the value of x within the range specified by y and z.
#define CLAMP01(x) max(0, min(1, x))
#define CLAMP0100(x) max(0, min(100, x))

#define QUANTIZE(variable) (round(variable,0.0001))

#define TICKS_IN_DAY 		24*60*60*10
#define TICKS_IN_SECOND 	10

#define ROOT2_FAST 1.41421

#define Floor(x) (round(x)) // this has to be capital because of objects with "floor" in their path
#define ceil(x) (-round(-(x)))

// Trigonometric functions.
#define Tan(x) (sin(x) / cos(x))
#define Cot(x) (1 / Tan(x))

// Useful in the cases when x is a large expression, e.g. x = 3a/2 + b^2 + Function(c)
#define Square(x) (x**2)

// Returns true if val is from min to max, inclusive.
#define IsInteger(x) (Floor(x) == x)

// 180 / Pi ~ 57.2957795
#define ToDegrees(radians) (radians * 57.2957795)
