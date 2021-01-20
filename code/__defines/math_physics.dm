// Math constants.
#define M_E	 2.71828183
#define M_PI	3.14159265
#define M_SQRT2 1.41421356

#define R_IDEAL_GAS_EQUATION	   8.31	// kPa*L/(K*mol).
#define ONE_ATMOSPHERE			 101.325 // kPa.
#define IDEAL_GAS_ENTROPY_CONSTANT 1164	// (mol^3 * s^3) / (kg^3 * L).

// Radiation constants.
#define STEFAN_BOLTZMANN_CONSTANT	5.6704e-8 // W/(m^2*K^4).
#define COSMIC_RADIATION_TEMPERATURE 3.15	  // K.
#define AVERAGE_SOLAR_RADIATION	  200	   // W/m^2. Kind of arbitrary. Really this should depend on the sun position much like solars.
#define RADIATOR_OPTIMUM_PRESSURE	3771	  // kPa at 20 C. This should be higher as gases aren't great conductors until they are dense. Used the critical pressure for air.
#define GAS_CRITICAL_TEMPERATURE	 132.65	// K. The critical point temperature for air.

#define RADIATOR_EXPOSED_SURFACE_AREA_RATIO 0.04 // (3 cm + 100 cm * sin(3deg))/(2*(3+100 cm)). Unitless ratio.
#define HUMAN_EXPOSED_SURFACE_AREA		  5.2 //m^2, surface area of 1.7m (H) x 0.46m (D) cylinder

#define Clamp(x, y, z) 	(x <= y ? y : (x >= z ? z : x))
#define CLAMP01(x) max(0, min(1, x))
#define CLAMP0100(x) max(0, min(100, x))

#define QUANTIZE(variable) (round(variable,0.0001))

#define TICKS_IN_DAY 		24*60*60*10
#define TICKS_IN_SECOND 	10

#define SIMPLE_SIGN(X) ((X) < 0 ? -1 : 1)
#define SIGN(X)		((X) ? SIMPLE_SIGN(X) : 0)

#define ROOT2_FAST 1.41421

#define RAND_F(LOW, HIGH) (rand()*(HIGH-LOW) + LOW)

#define Floor(x) (round(x)) // this has to be capital because of objects with "floor" in their path
#define ceil(x) (-round(-(x)))
#define Default(a, b) (a ? a : b)

// Trigonometric functions.
#define Tan(x) (sin(x) / cos(x))
#define Csc(x) (1 / sin(x))
#define Sec(x) (1 / cos(x))
#define Cot(x) (1 / Tan(x))

// Least Common Multiple. The formula is a consequence of: a*b = LCM*GCD.
#define Lcm(a, b) (abs(a) * abs(b) / Gcd(a, b))

// Useful in the cases when x is a large expression, e.g. x = 3a/2 + b^2 + Function(c)
#define Square(x) (x**2)

// Returns true if val is from min to max, inclusive.
#define IsInRange(val, min, max) ((val >= min) && (val <= max))

#define IsInteger(x) (Floor(x) == x)

#define IsMultiple(x, y) (x % y == 0)

#define IsEven(x) (!(x & 0x1))

#define IsOdd(x) (!IsEven(x))

// Performs a linear interpolation between a and b.
// Note: weight=0 returns a, weight=1 returns b, and weight=0.5 returns the mean of a and b.
#define Interpolate(a, b, weight) (a + (b - a) * weight)) // Equivalent to: a*(1 - weight) + b*weight

// Returns the nth root of x.
#define Root(n, x) (x ** (1 / n))

// 180 / Pi ~ 57.2957795
#define ToDegrees(radians) (radians * 57.2957795)

// Pi / 180 ~ 0.0174532925
#define ToRadians(degrees) (degrees * 0.0174532925)

// Vector algebra.
#define squaredNorm(x, y) (x*x + y*y)

#define norm(x, y) (sqrt(squaredNorm(x, y)))

#define IsPowerOfTwo(val) ((val & (val-1)) == 0)

#define RoundUpToPowerOfTwo(val) (2 ** -round(-log(2,val)))