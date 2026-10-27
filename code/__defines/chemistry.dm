#define DEFAULT_HUNGER_FACTOR 0.05 // Factor of how fast mob nutrition decreases

#define REM 0.2 // Means 'Reagent Effect Multiplier'. This is how many units of reagent are consumed per tick

#define CHEM_TOUCH 1
#define CHEM_INGEST 2
#define CHEM_BLOOD 3

#define MINIMUM_CHEMICAL_VOLUME 0.01

#define SOLID 1
#define LIQUID 2
#define GAS 3

#define REAGENTS_OVERDOSE 30

#define CHEM_SYNTH_ENERGY 500 // How much energy does it take to synthesize 1 unit of chemical, in Joules.

#define CE_STABLE "stable" // I.E 'inaprovaline', if we had it.
#define CE_ANTIBIOTIC "antibiotic" // I.E; increasing/decreasing immunity system[?].
#define CE_BLOODRESTORE "bloodrestore" // Gives off an iron/nutriment blood restoration effect.
#define CE_PAINKILLER "painkiller"
#define CE_ALCOHOL "alcohol" // Used for filtering by the liver; can be checked and incremented until value 'x' is toxic.
#define CE_ALCOHOL_TOXIC "alcotoxic" // Used for dealing damage to the liver; when 'x' is a checked value, E.G; if(filter_effect < 3) CE_ALCOHOL... else take_damage(user.chem_effects[CE_ALCOHOL_TOXIC])
#define CE_SPEEDBOOST "gofast" // I.E; Pervitin, Hyperzine.
#define CE_PULSE	  "xcardic" // Manages heart-rate (increase/decrease)
#define CE_NOPULSE	"heartstop" // Registers no pulse for the heartbeat.
