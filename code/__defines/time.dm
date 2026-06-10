#define SECOND *10
#define SECONDS *10

#define MINUTE SECONDS*60
#define MINUTES SECONDS*60

#define HOUR MINUTES*60
#define HOURS MINUTES*60

#define DAYS HOURS*24

#define TICKS *world.tick_lag

#define MILLISECONDS * 0.10

#define DS2TICKS(DS) ((DS)/world.tick_lag)

#define TICKS2DS(T) ((T) TICKS)
