////////////////////////////////////////CHEMICAL ELEMENTS/////////////////////////////////////////////

/datum/reagent/hydrogen
	name = "Hydrogen"
	id = "hydrogen"
	description = "The lightest element in the periodic table. Hydrogen is the most abundant chemical substance in the Universe."
	taste_mult = FALSE
	reagent_state = GAS
	color = "#800080"
	atomic_nr = 1
	chemical_symbol = "H"

/datum/reagent/helium
	name = "Helium"
	id = "helium"
	description = "A noble gas obtained by small amounts from the gases produced by oil extraction."
	taste_mult = FALSE
	reagent_state = GAS
	color = "#AFAFAF"
	atomic_nr = 2
	chemical_symbol = "He"

/datum/reagent/lithium
	name = "Lithium"
	id = "lithium"
	description = "A soft, silvery-white alkali metal. Under standard conditions, it is the lightest metal and the lightest solid element."
	taste_description = "metal"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 3
	chemical_symbol = "Li"

/datum/reagent/beryllium
	name = "Beryllium"
	id = "beryllium"
	description = "A relatively rare element in the universe, usually occurring as a product of the spallation of larger atomic nuclei that have collided with cosmic rays."
	taste_description = "metal"
	reagent_state = SOLID
	color = "#E3E3E3"
	atomic_nr = 4
	chemical_symbol = "Be"

/datum/reagent/boron
	name = "Boron"
	id = "boron"
	description = "Elemental boron is a metalloid that is found in small amounts in meteoroids but chemically uncombined boron is not otherwise found naturally on Earth. "
	taste_description = "metal"
	reagent_state = SOLID
	color = "#301F0D"
	atomic_nr = 5
	chemical_symbol = "B"

/datum/reagent/carbon
	name = "Carbon"
	id = "carbon"
	description = "A chemical element, good for cooking and heating."
	taste_description = "sour chalk"
	taste_mult = 1.5
	reagent_state = SOLID
	color = "#1C1300"
	ingest_met = REM * 5
	atomic_nr = 6
	chemical_symbol = "C"

/datum/reagent/carbon/affect_ingest(var/mob/living/carbon/M, var/alien, var/removed)
	if (M.ingested && M.ingested.reagent_list.len > 1) // Need to have at least 2 reagents - cabon and something to remove
		var/effect = TRUE / (M.ingested.reagent_list.len - 1)
		for (var/datum/reagent/R in M.ingested.reagent_list)
			if (R == src)
				continue
			M.ingested.remove_reagent(R.id, removed * effect)

/datum/reagent/nitrogen
	name = "Nitrogen"
	id = "nitrogen"
	description = "Nitrogen forms about 78% of Earth's atmosphere, making it the most abundant uncombined element."
	taste_mult = FALSE
	reagent_state = GAS
	color = "#FFFFFF" // colourless so IDK
	atomic_nr = 7
	chemical_symbol = "N"

/datum/reagent/oxygen
	name = "Oxygen"
	id = "oxygen"
	description = "Oxygen is used in cellular respiration, and many major classes of organic molecules in living organisms contain oxygen."
	taste_mult = FALSE
	reagent_state = GAS
	color = "#BDD6E0"
	atomic_nr = 8
	chemical_symbol = "O"

/datum/reagent/fluorine
	name = "Fluorine"
	id = "fluorine"
	description = "A highly toxic pale yellow diatomic gas at standard conditions. As the most electronegative element, it is extremely reactive, as it reacts with almost all other elements, except for helium and neon."
	taste_description = "fluorine"
	reagent_state = GAS
	color = "#FFFFE0"
	atomic_nr = 9
	chemical_symbol = "F"

/datum/reagent/neon
	name = "Neon"
	id = "neon"
	description = "Neon is a colorless, odorless, inert monatomic gas under standard conditions, with about two-thirds the density of air."
	taste_mult = FALSE
	reagent_state = GAS
	color = "#FF4500"
	atomic_nr = 10
	chemical_symbol = "Ne"

/datum/reagent/sodium
	name = "Sodium"
	id = "sodium"
	description = "A soft, silvery-white, highly reactive alkali metal."
	taste_description = "salt"
	reagent_state = SOLID
	color = "#E6E6E6"
	atomic_nr = 11
	chemical_symbol = "Na"

/datum/reagent/magnesium
	name = "Magnesium"
	id = "magnesium"
	description = "A common element with many uses, known for its bitter taste."
	taste_description = "bitterness"
	reagent_state = SOLID
	color = "#CDCDCD"
	atomic_nr = 12
	chemical_symbol = "Mg"

/datum/reagent/aluminum
	name = "Aluminum"
	id = "aluminum"
	taste_description = "metal"
	taste_mult = 1.1
	description = "A silvery white and ductile member of the boron group of chemical elements."
	reagent_state = SOLID
	color = "#A8A8A8"
	atomic_nr = 13
	chemical_symbol = "Al"

/datum/reagent/silicon
	name = "Silicon"
	id = "silicon"
	description = "Widely distributed in dusts, sands, planetoids, and planets as various forms of silicon dioxide (silica) or silicates. More than 90% of the Earth's crust is composed of silicate minerals."
	taste_description = "vinegar"
	reagent_state = SOLID
	color = "#A2ADBC"
	atomic_nr = 14
	chemical_symbol = "Si"

/datum/reagent/phosphorus
	name = "Phosphorus"
	id = "phosphorus"
	description = "A chemical element, the backbone of biological energy carriers."
	taste_description = "vinegar"
	reagent_state = SOLID
	color = "#832828"
	atomic_nr = 15
	chemical_symbol = "P"

/datum/reagent/sulfur
	name = "Sulfur"
	id = "sulfur"
	description = "A chemical element with a pungent smell."
	taste_description = "old eggs"
	reagent_state = SOLID
	color = "#BF8C00"
	atomic_nr = 16
	chemical_symbol = "S"

/datum/reagent/chlorine
	name = "Chlorine"
	id = "chlorine"
	description = "The most common compound of chlorine, sodium chloride (common salt), has been known since ancient times."
	taste_description = "chlorine"
	reagent_state = GAS
	color = "#FFD700"
	atomic_nr = 17
	chemical_symbol = "Cl"

/datum/reagent/argon
	name = "Argon"
	id = "argon"
	description = "Argon is the third-most abundant gas in the Earth's atmosphere. Has a violet glow."
	taste_mult = FALSE
	reagent_state = GAS
	color = "#C8A2C8"
	atomic_nr = 18
	chemical_symbol = "Ar"

/datum/reagent/potassium
	name = "Potassium"
	id = "potassium"
	description = "A soft, low-melting solid that can easily be cut with a knife. Reacts violently with water."
	taste_description = "sweetness" //potassium is bitter in higher doses but sweet in lower ones.
	reagent_state = SOLID
	color = "#A0A0A0"
	atomic_nr = 19
	chemical_symbol = "K"

/datum/reagent/calcium
	name = "Calcium"
	id = "calcium"
	description = "An alkaline earth metal, calcium is a reactive metal that forms a dark oxide-nitride layer when exposed to air."
	taste_description = "bone ash"
	reagent_state = SOLID
	color = "#F1F1EE"
	atomic_nr = 20
	chemical_symbol = "Ca"

/datum/reagent/scandium
	name = "Scandium"
	id = "scandium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 21
	chemical_symbol = "Sc"

/datum/reagent/titanium
	name = "Titanium"
	id = "titanium"
	description = "Titanium is a lustrous transition metal with a silver color, low density, and high strength. Titanium is resistant to corrosion in sea water, aqua regia, and chlorine."
	taste_description = "metal"
	reagent_state = SOLID
	color = "#CDCDCD"
	atomic_nr = 22
	chemical_symbol = "Ti"

/datum/reagent/vanadium
	name = "Vanadium"
	id = "vanadium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 23
	chemical_symbol = "V"

/datum/reagent/chromium
	name = "Chromium"
	id = "chromium"
	description = "A steely-grey, lustrous, hard and brittle transition metal. Chromium is also the main additive in stainless steel."
	taste_description = "metal"
	reagent_state = SOLID
	color = "#D0D0D0"
	atomic_nr = 24
	chemical_symbol = "Cr"

/datum/reagent/manganese
	name = "Manganese"
	id = "manganese"
	description = "Manganese is a transition metal, similar to iron, but both hard and fragile at the same time. Refracting an easily corroded."
	taste_description = "metal"
	reagent_state = SOLID
	color = "#d3d3d3"
	atomic_nr = 25
	chemical_symbol = "Mn"

/datum/reagent/iron
	name = "Iron"
	id = "iron"
	description = "Pure iron is a metal."
	taste_description = "metal"
	reagent_state = SOLID
	color = "#353535"
	atomic_nr = 26
	chemical_symbol = "Fe"

/datum/reagent/iron/affect_ingest(var/mob/living/carbon/M, var/alien, var/removed)
	M.add_chemical_effect(CE_BLOODRESTORE, 8 * removed)

/datum/reagent/cobalt
	name = "Cobalt"
	id = "cobalt"
	description = "Cobalt is a metal with magnetic capabilities, it's usually found with niquel and is found in big quantities on meteorites"
	taste_description = "magnets"
	reagent_state = SOLID
	color = "#c0c0c0"
	atomic_nr = 27
	chemical_symbol = "Co"

/datum/reagent/nickel
	name = "Nickel"
	id = "nickel"
	description = "Nickel is a silver-white metal with a slight golden tinge that takes a high polish. It's one of the few elements that are magnetic at room temperature."
	taste_description = "magnets"
	reagent_state = SOLID
	color = "#e6e6e6"
	atomic_nr = 28
	chemical_symbol = "Ni"

/datum/reagent/copper
	name = "Copper"
	id = "copper"
	description = "A highly ductile metal."
	taste_description = "copper"
	color = "#6E3B08"
	reagent_state = SOLID
	atomic_nr = 29
	chemical_symbol = "Cu"

/datum/reagent/zinc
	name = "Zinc"
	id = "zinc"
	description = "Zinc is a blue-ish white metal that burns in the air in a blue-green fire."
	taste_description = "metal"
	reagent_state = SOLID
	color = "#f0f2f3"
	atomic_nr = 30
	chemical_symbol = "Zn"

/datum/reagent/gallium
	name = "Gallium"
	id = "gallium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 31
	chemical_symbol = "Ga"

/datum/reagent/germanium
	name = "Germanium"
	id = "germanium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 32
	chemical_symbol = "Ge"

/datum/reagent/arsenic
	name = "Arsenic"
	id = "arsenic"
	description = "The primary use of arsenic is in alloys of lead (for example, in car batteries and ammunition). Arsenic is a common n-type dopant in semiconductor electronic devices, and the optoelectronic compound gallium arsenide is the second most commonly used semiconductor after doped silicon. Warning: highly toxic."
	taste_mult = FALSE
	reagent_state = SOLID
	color = "#80b692"
	atomic_nr = 33
	chemical_symbol = "As"

/datum/reagent/selenium
	name = "Selenium"
	id = "selenium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 34
	chemical_symbol = "Se"

/datum/reagent/bromine
	name = "Bromine"
	id = "bromine"
	description = "Bromine is very reactive and thus does not occur free in nature, but in colourless soluble crystalline mineral halide salts, analogous to table salt. While it is rather rare in the Earth's crust, the high solubility of the bromide ion (Br-) has caused its accumulation in the oceans. It can irritate eyes, lungs and throat."
	taste_description = "irritation"
	reagent_state = SOLID
	color = "#9cd3db"
	atomic_nr = 35
	chemical_symbol = "Br"

/datum/reagent/krypton
	name = "Krypton"
	id = "krypton"
	description = "A core element."
	taste_description = "weird"
	reagent_state = GAS
	color = "#FFFFFF"
	atomic_nr = 36
	chemical_symbol = "Kr"

/datum/reagent/rubidium
	name = "Rubidium"
	id = "rubidium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 37
	chemical_symbol = "Rb"

/datum/reagent/strontium
	name = "Strontium"
	id = "strontium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 38
	chemical_symbol = "Sr"

/datum/reagent/yttrium
	name = "Yttrium"
	id = "yttrium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 39
	chemical_symbol = "Y"

/datum/reagent/zirconium
	name = "Zirconium"
	id = "zirconium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 40
	chemical_symbol = "Zr"

/datum/reagent/niobium
	name = "Niobium"
	id = "niobium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 41
	chemical_symbol = "Nb"

/datum/reagent/molybdenum
	name = "Molybdenum"
	id = "molybdenum"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 42
	chemical_symbol = "Mo"

/datum/reagent/technetium
	name = "Technetium"
	id = "technetium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 43
	chemical_symbol = "Tc"
	radioactive = TRUE

/datum/reagent/ruthenium
	name = "Ruthenium"
	id = "ruthenium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 44
	chemical_symbol = "Ru"

/datum/reagent/rhodium
	name = "Rhodium"
	id = "rhodium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 45
	chemical_symbol = "Rh"

/datum/reagent/palladium
	name = "Palladium"
	id = "palladium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 46
	chemical_symbol = "Pd"

/datum/reagent/silver
	name = "Silver"
	id = "silver"
	description = "A soft, white, lustrous transition metal, it has the highest electrical conductivity of any element and the highest thermal conductivity of any metal."
	taste_description = "expensive yet reasonable metal"
	reagent_state = SOLID
	color = "#D0D0D0"
	atomic_nr = 47
	chemical_symbol = "ag"

/datum/reagent/cadmium
	name = "Cadmium"
	id = "cadmium"
	description = "A soft, silvery-white metal is chemically similar to the two other stable metals in group 12, zinc and mercury."
	taste_description = "metal"
	reagent_state = SOLID
	color = "#9FABB7"
	atomic_nr = 48
	chemical_symbol = "Cd"

/datum/reagent/indium
	name = "Indium"
	id = "indium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 49
	chemical_symbol = "In"

/datum/reagent/tin
	name = "Tin"
	id = "tin"
	description = "Tin is a silvery metal that characteristicly has a faint yellow hue. Tin, like indium, is soft enough to be cut without much force."
	taste_description = "metal"
	reagent_state = SOLID
	color = "#d3d4d5"
	atomic_nr = 50
	chemical_symbol = "Sn"

/datum/reagent/antimony
	name = "Antimony"
	id = "antimony"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 51
	chemical_symbol = "Sb"

/datum/reagent/tellurium
	name = "Tellurium"
	id = "tellurium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 52
	chemical_symbol = "Te"

/datum/reagent/iodine
    name = "Iodine"
    id = "iodine"
    description = " Iodine is a dark grey or purple solid. It can sublimate into a purple-pink gas that has an irritating odor. The solid iodine is a dark, almost black, grey or purple color."
    taste_description = "raw fish"
    reagent_state = SOLID
    color = "#AF9600"
    atomic_nr = 53
    chemical_symbol = "I"

/datum/reagent/iodine/affect_ingest(var/mob/living/carbon/M, var/alien, var/removed)
	M.apply_effect(max(M.radiation - 2 * removed, 0), IRRADIATE, blocked = 0)

/datum/reagent/xenon
	name = "Xenon"
	id = "xenon"
	description = "A core element."
	taste_description = "weird"
	reagent_state = GAS
	color = "#FFFFFF"
	atomic_nr = 54
	chemical_symbol = "Xe"

/datum/reagent/cesium
	name = "Cesium"
	id = "cesium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 55
	chemical_symbol = "Cs"

/datum/reagent/barium
	name = "Barium"
	id = "barium"
	description = "Insoluble in water. The name barium originates from the alchemical derivative Baryta."
	taste_description = "chalk"
	reagent_state = SOLID
	color = "#da8a67"
	atomic_nr = 56
	chemical_symbol = "Ba"

/datum/reagent/lanthanum
	name = "Lanthanum"
	id = "lanthanum"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 57
	chemical_symbol = "La"

/datum/reagent/cerium
	name = "Cerium"
	id = "cerium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 58
	chemical_symbol = "Ce"

/datum/reagent/praseodymium
	name = "Praseodymium"
	id = "praseodymium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 59
	chemical_symbol = "Pr"

/datum/reagent/neodymium
	name = "Neodymium"
	id = "neodymium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 60
	chemical_symbol = "Nd"

/datum/reagent/promethium
	name = "Promethium"
	id = "promethium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 61
	chemical_symbol = "Pm"
	radioactive = TRUE

/datum/reagent/samarium
	name = "Samarium"
	id = "samarium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 62
	chemical_symbol = "Sm"

/datum/reagent/europium
	name = "Europium"
	id = "europium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 63
	chemical_symbol = "Eu"

/datum/reagent/gadolinium
	name = "Gadolinium"
	id = "gadolinium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 64
	chemical_symbol = "Gd"

/datum/reagent/terbium
	name = "Terbium"
	id = "terbium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 65
	chemical_symbol = "Tb"

/datum/reagent/dysprosium
	name = "Dysprosium"
	id = "dysprosium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 66
	chemical_symbol = "Dy"

/datum/reagent/holmium
	name = "Holmium"
	id = "holmium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 67
	chemical_symbol = "Ho"

/datum/reagent/erbium
	name = "Erbium"
	id = "erbium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 68
	chemical_symbol = "Er"

/datum/reagent/thulium
	name = "Thulium"
	id = "thulium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 69
	chemical_symbol = "Tm"

/datum/reagent/ytterbium
	name = "Ytterbium"
	id = "ytterbium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 70
	chemical_symbol = "Yb"

/datum/reagent/lutetium
	name = "Lutetium"
	id = "lutetium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 71
	chemical_symbol = "Lu"

/datum/reagent/hafnium
	name = "Hafnium"
	id = "hafnium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 72
	chemical_symbol = "Hf"

/datum/reagent/tantalum
	name = "Tantalum"
	id = "tantalum"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 73
	chemical_symbol = "Ta"

/datum/reagent/tungsten
	name = "Tungsten"
	id = "tungsten"
	description = "ungsten is a heavy metal that can be from grey to white. Tungsten in its pure form is soft enough to cut with a hacksaw. Tungsten carbide is extremely hard and it is very difficult to cut."
	taste_description = "metal"
	reagent_state = SOLID
	color = "#767980"
	atomic_nr = 74
	chemical_symbol = "W"

/datum/reagent/rhenium
	name = "Rhenium"
	id = "rhenium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 75
	chemical_symbol = "Re"

/datum/reagent/osmium
	name = "Osmium"
	id = "osmium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 76
	chemical_symbol = "Os"

/datum/reagent/iridium
	name = "Iridium"
	id = "iridium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 77
	chemical_symbol = "Ir"

/datum/reagent/platinum
	name = "Platinum"
	id = "platinum"
	description = "Platinum is a precious metal; soft, silvery-white, and dense with a beautiful lustrous sheen."
	taste_description = "metal"
	reagent_state = SOLID
	color = "#e5e4e2"
	atomic_nr = 78
	chemical_symbol = "Pt"

/datum/reagent/gold
	name = "Gold"
	id = "gold"
	description = "Gold is a dense, soft, shiny metal and the most malleable and ductile metal known."
	taste_description = "expensive metal"
	reagent_state = SOLID
	color = "#F7C430"
	atomic_nr = 79
	chemical_symbol = "au"

/datum/reagent/mercury
	name = "Mercury"
	id = "mercury"
	description = "Mercury is the only metallic element that is liquid at standard conditions for temperature and pressure."
	taste_mult = FALSE //mercury apparently is tasteless. IDK
	reagent_state = LIQUID
	color = "#484848"
	atomic_nr = 80
	chemical_symbol = "Hg"

/datum/reagent/mercury/affect_blood(var/mob/living/carbon/M, var/alien, var/removed)
	if (prob(5))
		M.emote(pick("twitch", "drool", "moan"))
	M.adjustBrainLoss(0.1)

/datum/reagent/thallium
	name = "Thallium"
	id = "thallium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 81
	chemical_symbol = "Tl"

/datum/reagent/lead
	name = "Lead"
	id = "lead"
	description = "Lead is a heavy metal that is denser than most common materials. Lead is soft and malleable, and also has a relatively low melting point. When freshly cut, lead is silvery with a hint of blue; it tarnishes to a dull gray color when exposed to air."
	taste_description = "metal"
	reagent_state = SOLID
	color = "#444f53"
	atomic_nr = 82
	chemical_symbol = "Pb"

/datum/reagent/mercury/affect_blood(var/mob/living/carbon/M, var/alien, var/removed)
	if (prob(5))
		M.emote(pick("twitch", "drool", "moan"))
	M.adjustBrainLoss(0.3)

/datum/reagent/bismuth
	name = "Bismuth"
	id = "bismuth"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 83
	chemical_symbol = "Bi"

/datum/reagent/polonium
	name = "Polonium"
	id = "polonium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 84
	chemical_symbol = "Po"
	radioactive = TRUE

/datum/reagent/astatine
	name = "Astatine"
	id = "astatine"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 85
	chemical_symbol = "At"
	radioactive = TRUE

/datum/reagent/radon
	name = "Radon"
	id = "radon"
	description = "A core element."
	taste_description = "weird"
	reagent_state = GAS
	color = "#FFFFFF"
	atomic_nr = 86
	chemical_symbol = "Rn"
	radioactive = TRUE

/datum/reagent/francium
	name = "Francium"
	id = "francium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 87
	chemical_symbol = "Fr"
	radioactive = TRUE

/datum/reagent/radium
	name = "Radium"
	id = "radium"
	description = "Radium is an alkaline earth metal. It is extremely radioactive."
	taste_description = "the color blue, and regret"
	reagent_state = SOLID
	color = "#C7C7C7"
	atomic_nr = 88
	chemical_symbol = "ra"
	radioactive = TRUE

/datum/reagent/radium/affect_blood(var/mob/living/carbon/M, var/alien, var/removed)
	M.apply_effect(10 * removed, IRRADIATE, blocked = 0) // Radium may increase your chances to cure a disease

/datum/reagent/radium/touch_turf(var/turf/T)
	if(volume >= 5)
		var/obj/effect/decal/cleanable/greenglow/glow = locate(/obj/effect/decal/cleanable/greenglow, T)
		if(!glow)
			new /obj/effect/decal/cleanable/greenglow(T)
		return

/datum/reagent/actinium
	name = "Actinium"
	id = "actinium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 89
	chemical_symbol = "Ac"
	radioactive = TRUE

/datum/reagent/thorium
	name = "Thorium"
	id = "thorium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 90
	chemical_symbol = "Th"
	radioactive = TRUE

/datum/reagent/protactinium
	name = "Protactinium"
	id = "protactinium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 91
	chemical_symbol = "Pa"
	radioactive = TRUE

/datum/reagent/uranium
	name ="Uranium"
	id = "uranium"
	description = "A silvery-white metallic chemical element in the actinide series, weakly radioactive."
	taste_description = "the inside of a reactor"
	reagent_state = SOLID
	color = "#B8B8C0"
	atomic_nr = 92
	chemical_symbol = "U"
	radioactive = TRUE

/datum/reagent/uranium/affect_touch(var/mob/living/carbon/M, var/alien, var/removed)
	affect_ingest(M, alien, removed)

/datum/reagent/uranium/affect_blood(var/mob/living/carbon/M, var/alien, var/removed)
	M.apply_effect(5 * removed, IRRADIATE, blocked = 0)

/datum/reagent/uranium/touch_turf(var/turf/T)
	if(volume >= 10)
		var/obj/effect/decal/cleanable/greenglow/glow = locate(/obj/effect/decal/cleanable/greenglow, T)
		if(!glow)
			new /obj/effect/decal/cleanable/greenglow(T)
		return

/datum/reagent/neptunium
	name = "Neptunium"
	id = "neptunium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 93
	chemical_symbol = "Np"
	radioactive = TRUE

/datum/reagent/plutonium
	name = "Plutonium"
	id = "plutonium"
	description = "Plutonium reacts with carbon, halogens, nitrogen, silicon, and hydrogen. When exposed to moist air, it forms oxides and hydrides that can expand the sample up to 70% in volume, which in turn flake off as a powder that is pyrophoric. It is radioactive and can accumulate in bones, which makes the handling of plutonium dangerous."
	taste_description = "radioactive bitterness"
	reagent_state = SOLID
	color = "#ff6bd9"
	atomic_nr = 94
	chemical_symbol = "Pu"
	radioactive = TRUE

/datum/reagent/plutonium/affect_touch(var/mob/living/carbon/M, var/alien, var/removed)
	affect_ingest(M, alien, removed)

/datum/reagent/plutonium/affect_blood(var/mob/living/carbon/M, var/alien, var/removed)
	M.apply_effect(15 * removed, IRRADIATE, blocked = 0)

/datum/reagent/plutonium/touch_turf(var/turf/T)
	if(volume >= 3)
		var/obj/effect/decal/cleanable/greenglow/glow = locate(/obj/effect/decal/cleanable/greenglow, T)
		if(!glow)
			new /obj/effect/decal/cleanable/greenglow(T)
		return

/datum/reagent/americium
	name = "Americium"
	id = "americium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 95
	chemical_symbol = "Am"
	radioactive = TRUE

/datum/reagent/curium
	name = "Curium"
	id = "curium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 96
	chemical_symbol = "Cm"
	radioactive = TRUE

/datum/reagent/berkelium
	name = "Berkelium"
	id = "berkelium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 97
	chemical_symbol = "Bk"
	radioactive = TRUE

/datum/reagent/californium
	name = "Californium"
	id = "californium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 98
	chemical_symbol = "Cf"
	radioactive = TRUE

/datum/reagent/einsteinium
	name = "Einsteinium"
	id = "einsteinium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 99
	chemical_symbol = "Es"
	radioactive = TRUE

/datum/reagent/fermium
	name = "Fermium"
	id = "fermium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 100
	chemical_symbol = "Fm"
	radioactive = TRUE

/datum/reagent/mendelevium
	name = "Mendelevium"
	id = "mendelevium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 101
	chemical_symbol = "Md"
	radioactive = TRUE

/datum/reagent/nobelium
	name = "Nobelium"
	id = "nobelium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 102
	chemical_symbol = "No"
	radioactive = TRUE

/datum/reagent/lawrencium
	name = "Lawrencium"
	id = "lawrencium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 103
	chemical_symbol = "Lr"
	radioactive = TRUE

/datum/reagent/rutherfordium
	name = "Rutherfordium"
	id = "rutherfordium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 104
	chemical_symbol = "Rf"
	radioactive = TRUE

/datum/reagent/dubnium
	name = "Dubnium"
	id = "dubnium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 105
	chemical_symbol = "Db"
	radioactive = TRUE

/datum/reagent/seaborgium
	name = "Seaborgium"
	id = "seaborgium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 106
	chemical_symbol = "Sg"
	radioactive = TRUE

/datum/reagent/bohrium
	name = "Bohrium"
	id = "bohrium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 107
	chemical_symbol = "Bh"
	radioactive = TRUE

/datum/reagent/hassium
	name = "Hassium"
	id = "hassium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 108
	chemical_symbol = "Hs"
	radioactive = TRUE

/datum/reagent/meitnerium
	name = "Meitnerium"
	id = "meitnerium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 109
	chemical_symbol = "Mt"
	radioactive = TRUE

/datum/reagent/darmstadtium
	name = "Darmstadtium"
	id = "darmstadtium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 110
	chemical_symbol = "Ds"
	radioactive = TRUE

/datum/reagent/roentgenium
	name = "Roentgenium"
	id = "roentgenium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 111
	chemical_symbol = "Rg"
	radioactive = TRUE

/datum/reagent/ununbium
	name = "Ununbium"
	id = "ununbium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 112
	chemical_symbol = "Uub"
	radioactive = TRUE

/datum/reagent/ununtrium
	name = "Ununtrium"
	id = "ununtrium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 113
	chemical_symbol = "Uut"
	radioactive = TRUE

/datum/reagent/ununquadium
	name = "Ununquadium"
	id = "ununquadium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 114
	chemical_symbol = "Uuq"
	radioactive = TRUE

/datum/reagent/ununpentium
	name = "Ununpentium"
	id = "ununpentium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 115
	chemical_symbol = "Uup"
	radioactive = TRUE

/datum/reagent/ununhexium
	name = "Ununhexium"
	id = "ununhexium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 116
	chemical_symbol = "Uuh"
	radioactive = TRUE

/datum/reagent/ununseptium
	name = "Ununseptium"
	id = "ununseptium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 117
	chemical_symbol = "Uus"
	radioactive = TRUE

/datum/reagent/ununoctium
	name = "Ununoctium"
	id = "ununoctium"
	description = "A core element."
	taste_description = "weird"
	reagent_state = SOLID
	color = "#FFFFFF"
	atomic_nr = 118
	chemical_symbol = "Uuo"
	radioactive = TRUE

