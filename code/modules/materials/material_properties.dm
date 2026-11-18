// Physical properties of every material (docs/material-roles.md).
//
// Steel is 100 on every scale except heat_limit, so a value reads as
// "percent of steel". These are separate from the older hardness, weight and
// integrity, which stay the weapon and structure balance numbers they were.
// The values live on the material singletons: an item or machine never
// stores them.
/material
	var/density = 11       // mass of a part of a given size
	var/firmness = 5       // keeps an edge, resists denting
	var/toughness = 40     // resists snapping under shock
	var/wear = 20          // life as a rubbing or rolling part
	var/heat_limit = 200   // deg C before it chars, softens or melts
	var/corrosion = 40     // how fast water ruins it, 0 = never
	var/conductivity = 0   // copper = 100
	var/spring = 10        // returns after bending
	var/flammable = TRUE
	var/magnetic = FALSE   // sets off magnetic pistols, sticks to magnets
	var/sparks = FALSE     // can strike a spark
	var/toxic = FALSE      // poisons what it holds or carries
	var/shaping = SHAPE_SEWN // SHAPE_* ways it can be worked

// The base values above describe hides, pelts, cloth and fibre. Everything
// else is set here, one block per family; subtypes inherit.

/material/leather
	density = 11
	firmness = 5
	toughness = 45
	wear = 25
	spring = 15

/material/wood
	density = 9
	firmness = 25
	toughness = 40
	wear = 20
	heat_limit = 280
	corrosion = 25
	spring = 40
	shaping = SHAPE_CARVED

// Sawn planks: lighter and a little weaker than the log they came from.
/material/wood/soft
	density = 6
	firmness = 20
	toughness = 30
	wear = 12
	heat_limit = 250
	corrosion = 35
	spring = 30

/material/wood/straw
	density = 2
	firmness = 2
	toughness = 8
	wear = 3
	spring = 5

/material/bamboo
	density = 5
	firmness = 22
	toughness = 30
	wear = 10
	heat_limit = 250
	corrosion = 30
	spring = 55
	shaping = SHAPE_CARVED

/material/bone
	density = 20
	firmness = 30
	toughness = 25
	wear = 15
	heat_limit = 300
	corrosion = 10
	spring = 20
	flammable = FALSE
	shaping = SHAPE_CARVED

/material/chitin
	density = 14
	firmness = 28
	toughness = 30
	wear = 15
	heat_limit = 300
	corrosion = 10
	spring = 20
	flammable = FALSE
	shaping = SHAPE_CARVED

/material/flint
	density = 33
	firmness = 85
	toughness = 6
	wear = 30
	heat_limit = 1100
	corrosion = 0
	spring = 0
	flammable = FALSE
	sparks = TRUE
	shaping = SHAPE_KNAPPED

/material/obsidian
	density = 31
	firmness = 80
	toughness = 4
	wear = 25
	heat_limit = 900
	corrosion = 0
	spring = 0
	flammable = FALSE
	shaping = SHAPE_KNAPPED

/material/glass
	density = 32
	firmness = 70
	toughness = 3
	wear = 25
	heat_limit = 600
	corrosion = 0
	spring = 0
	flammable = FALSE
	shaping = SHAPE_FIRED|SHAPE_KNAPPED

/material/diamond
	density = 45
	firmness = 150
	toughness = 20
	wear = 150
	heat_limit = 700
	corrosion = 0
	spring = 0
	flammable = FALSE
	shaping = SHAPE_MACHINED

/material/crystal
	density = 34
	firmness = 75
	toughness = 5
	wear = 40
	heat_limit = 1000
	corrosion = 0
	spring = 0
	flammable = FALSE
	shaping = SHAPE_KNAPPED

/material/stone
	density = 33
	firmness = 60
	toughness = 15
	wear = 35
	heat_limit = 1100
	corrosion = 0
	spring = 0
	flammable = FALSE
	shaping = SHAPE_CARVED

/material/sandstone
	density = 29
	firmness = 40
	toughness = 10
	wear = 20
	heat_limit = 1100
	corrosion = 5
	spring = 0
	flammable = FALSE
	shaping = SHAPE_CARVED

/material/marble
	density = 34
	firmness = 50
	toughness = 12
	wear = 30
	heat_limit = 800
	corrosion = 5
	spring = 0
	flammable = FALSE
	shaping = SHAPE_CARVED

/material/stonebrick
	density = 33
	firmness = 60
	toughness = 15
	wear = 35
	heat_limit = 1100
	corrosion = 0
	spring = 0
	flammable = FALSE
	shaping = SHAPE_CARVED

/material/concrete
	density = 30
	firmness = 55
	toughness = 12
	wear = 30
	heat_limit = 1000
	corrosion = 5
	spring = 0
	flammable = FALSE
	shaping = SHAPE_MOULDED

/material/brick
	density = 25
	firmness = 50
	toughness = 5
	wear = 20
	heat_limit = 1400
	corrosion = 0
	spring = 0
	flammable = FALSE
	shaping = SHAPE_FIRED

/material/clay
	density = 25
	firmness = 50
	toughness = 5
	wear = 20
	heat_limit = 1400
	corrosion = 0
	spring = 0
	flammable = FALSE
	shaping = SHAPE_FIRED

/material/copper
	density = 114
	firmness = 35
	toughness = 60
	wear = 40
	heat_limit = 1000
	corrosion = 10
	conductivity = 100
	spring = 10
	flammable = FALSE
	shaping = SHAPE_CAST|SHAPE_FORGED

/material/tin
	density = 93
	firmness = 10
	toughness = 30
	wear = 10
	heat_limit = 230
	corrosion = 5
	conductivity = 15
	spring = 0
	flammable = FALSE
	shaping = SHAPE_CAST

/material/zinc
	density = 91
	firmness = 25
	toughness = 25
	wear = 20
	heat_limit = 400
	corrosion = 10
	conductivity = 28
	spring = 5
	flammable = FALSE
	shaping = SHAPE_CAST

/material/bronze
	density = 112
	firmness = 60
	toughness = 75
	wear = 85
	heat_limit = 900
	corrosion = 5
	conductivity = 12
	spring = 45
	flammable = FALSE
	shaping = SHAPE_CAST

/material/brass
	density = 108
	firmness = 55
	toughness = 65
	wear = 80
	heat_limit = 900
	corrosion = 8
	conductivity = 28
	spring = 40
	flammable = FALSE
	shaping = SHAPE_CAST|SHAPE_MACHINED

/material/lead
	density = 144
	firmness = 8
	toughness = 20
	wear = 5
	heat_limit = 300
	corrosion = 3
	conductivity = 8
	spring = 0
	flammable = FALSE
	toxic = TRUE
	shaping = SHAPE_CAST

/material/gold
	density = 246
	firmness = 12
	toughness = 40
	wear = 10
	heat_limit = 1000
	corrosion = 0
	conductivity = 70
	spring = 0
	flammable = FALSE
	shaping = SHAPE_CAST|SHAPE_FORGED

/material/silver
	density = 134
	firmness = 15
	toughness = 45
	wear = 15
	heat_limit = 900
	corrosion = 5
	conductivity = 105
	spring = 5
	flammable = FALSE
	shaping = SHAPE_CAST|SHAPE_FORGED

/material/iron
	density = 100
	firmness = 80
	toughness = 80
	wear = 70
	heat_limit = 1200
	corrosion = 60
	conductivity = 17
	spring = 30
	flammable = FALSE
	magnetic = TRUE
	sparks = TRUE
	shaping = SHAPE_CAST|SHAPE_FORGED

/material/steel
	density = 100
	firmness = 100
	toughness = 100
	wear = 100
	heat_limit = 1300
	corrosion = 40
	conductivity = 10
	spring = 100
	flammable = FALSE
	magnetic = TRUE
	sparks = TRUE
	shaping = SHAPE_FORGED|SHAPE_MACHINED

// Aluminium (aluminium.dm): a third of steel's weight, soft and tough, does
// not rust or strike sparks, conducts well.
/material/aluminium
	density = 35
	firmness = 35
	toughness = 60
	wear = 30
	heat_limit = 600
	corrosion = 5
	conductivity = 61
	spring = 40
	flammable = FALSE
	shaping = SHAPE_CAST|SHAPE_FORGED|SHAPE_MACHINED

/material/barbedwire
	density = 100
	firmness = 80
	toughness = 60
	wear = 50
	heat_limit = 1200
	corrosion = 60
	conductivity = 17
	spring = 30
	flammable = FALSE
	magnetic = TRUE
	sparks = TRUE
	shaping = SHAPE_FORGED

/material/plastic
	density = 12
	firmness = 18
	toughness = 30
	wear = 45
	heat_limit = 150
	corrosion = 0
	spring = 30
	shaping = SHAPE_MOULDED

/material/rubber
	density = 10
	firmness = 5
	toughness = 25
	wear = 35
	heat_limit = 120
	corrosion = 0
	spring = 30
	shaping = SHAPE_MOULDED

/material/kevlar
	density = 18
	firmness = 10
	toughness = 90
	wear = 40
	heat_limit = 400
	corrosion = 5
	spring = 20
	flammable = FALSE

/material/electronics
	density = 30
	firmness = 20
	toughness = 15
	wear = 20
	heat_limit = 150
	corrosion = 30
	spring = 0
	flammable = FALSE
	shaping = SHAPE_MACHINED

// The value a part role reads for one property name. "rustproof" is the
// part of corrosion a lifetime can be scaled by.
/material/proc/role_property(property)
	switch (property)
		if ("density") return density
		if ("firmness") return firmness
		if ("toughness") return toughness
		if ("wear") return wear
		if ("heat_limit") return heat_limit
		if ("conductivity") return conductivity
		if ("spring") return spring
		if ("rustproof") return max(1, 100 - corrosion)
	return 0

// A few plain words on what the material is like, for examine text.
/material/proc/property_summary()
	var/list/words = list()
	if (firmness >= 80)
		words += "hard"
	else if (firmness <= 15)
		words += "soft"
	if (toughness >= 75)
		words += "tough"
	else if (toughness < PART_FRAGILE_TOUGHNESS)
		words += "fragile"
	if (density >= 90)
		words += "heavy"
	else if (density <= 15)
		words += "light"
	if (spring >= 45)
		words += "springy"
	if (conductivity >= 50)
		words += "a good conductor"
	if (magnetic && corrosion >= 40)
		words += "rusts"
	if (flammable)
		words += "burns"
	if (sparks)
		words += "can strike sparks"
	if (toxic)
		words += "poisonous"
	return english_list(words, "unremarkable")
