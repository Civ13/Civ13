// Fuels that burn-anything engines (hot bulb, turbine) take. A list literal, so
// type var defaults can use it. Gasoline engines also take "enginefuel" (see
// /obj/structure/engine/internal/New()). heat_source_liquid_fuels() keeps the
// same list spelled out because tests/water_treatment reads it from source.
#define ANY_ENGINE_FUELS list("petroleum", "gasoline", "diesel", "pethanol", "biodiesel", "olive_oil", "fat_oil")
