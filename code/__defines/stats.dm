#define STAT_VERY_HIGH 140
#define STAT_HIGH 120
#define STAT_MEDIUM_HIGH 110
#define STAT_NORMAL 100
#define STAT_MEDIUM_LOW 90
#define STAT_LOW 80
#define STAT_VERY_LOW 70
#define STAT_VERY_VERY_LOW 50
// STAT_VERY_VERY_LOW is only used to prevent doctor-soldiers and is not included in this list
#define ALL_STATS list(STAT_VERY_LOW, STAT_LOW, STAT_MEDIUM_LOW, STAT_NORMAL, STAT_MEDIUM_HIGH, STAT_HIGH, STAT_VERY_HIGH)

#define GET_STAT_COEFF(constant) constant/100
#define GET_MIN_STAT_COEFF(constant) (constant-5)/100