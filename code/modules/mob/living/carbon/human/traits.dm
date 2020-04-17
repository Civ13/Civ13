/mob
	var/list/traits = list()
//name = cost, exclusions, description

/mob/proc/find_trait(var/tt = null)
	if (!tt)
		return FALSE
	if (tt in traits)
		return TRUE
var/global/list/trait_list = list(
//	"Lactose Intolerance" = list(-1,list(),"You have the inability to digest dairy products and will get sick when you ingest them. (Get food poisoning from anytype of milk product)"),
//	"Skilled Archer" = list(3,list("Skilled Fighter"),"You are better at fighting with ranged weapons and running away. (Start with better Dexterity, and bow skills)"),
//	"Skilled Fighter" = list(3,list("Skilled Archer"),"You are better at fighting with your fists and melee weapons. (Start with better Strength, and sword skills)"),
	"Blind" = list(-6,list(),"You can not see, you may require aid."),
//	"Partial Blindness" = list(-2,list(),"You can barely see, you may require aid or sometype of instrument"),
	"Introverted" = list(1,list("Extroverted"),"You are more confortable on your own - Your mood will improve when alone, and lower near others."),
	"Extroverted" = list(-1,list("Introverted"),"You prefer to be near people - Your mood will improve when near others, and lower when alone."),
//	"Down Syndrome" = list(-5,list(),"You are very backward in your mental and physical developement, you are no scolar. (Can't get Philo past 1.4, and has errors in speach and speach comes out slow)"),
//	"Sickle Celled Anemia" = list(-1,list(),"Your blood cells are not normal, and you have a higher chance of having Heart failure. (Random Heart attacks and pains in the chest and other parts in the body)"),
	"Hemophilia" = list(-2,list(),"Your blood does not clot normally. (You bleed out more than other people)"),
//	"Spinal Paralysis" = list(-3,list(),"Your spine has been damaged long ago and aches (Your back hurts a lot and you'll soon become unable to walk)"),
//	"Schizophrenia" = list(-4,list(),"Schizophrenia: You hear things and see horrible images in your head later in your life (PTSD and voices in your head)"),
	"Dwarfism" = list(0,list("Gigantism","Tall","Short"),"You are smaller and need less food, but also have lower strength (0.8x Size, strength modifier 0.7x, decreased food requirements)"),
	"Short" = list(-1,list("Gigantism","Tall","Dwarfism"),"You are a bit shorter and weaker than average. (0.9x Size, strength modifier 0.85x)"),
//	"Hyperpigmentation" = list(5,list(),"Your skin is covered in Darkened patches or spots on your skin. (You gain heat resistance a bit)"),
	"Tall" = list(1,list("Dwarfism","Short","Gigantism"),"You are taller than average. (1.1x Size, strength modifier 1.15x)"),
	"Gigantism" = list(3,list("Dwarfism","Short","Tall"),"You are larger, need more food, and you move slower, but have higher strength (1.3x Size, decreased speed, increased food requirements, strength modifier 1.5x)"),
//	"Sixth Sense" = list(3,list(),"You can hear voices of people who are not even near you."),
	"Agile" = list(3,list("Slowness"),"You can run faster than most people."),
	"Weak Immune System" = list(-3,list("Strong Immune System"),"You are more likely to get sick."),
//	"Strong Immune System" = list(3,list("Weak Immune System"),"You are less likely to get sick."),
	"Vegan" = list(-1,list("Carnivore","Cannibal"),"You can only eat plants."),
	"Carnivore" = list(-1,list("Vegan"),"You can only eat meat."),
	"Slowness" = list(-2,list("Agile"),"You move slower than most people."),
//	"Bubonic Immunity" = list(5,list("Weak Immune System"),"Your body can survive the bubonic plague, unlike most people."),
//	"Cannibal" = list(4,list("Vegan"),"You can only eat human meat."),
//	"Tough Liver" = list(5,list(),"You have a higher tolerance when drinking Alcohol or when Poisoned."),
	"Flat Footed" = list(-1,list(),"Your feet have flat bottoms, and you get tired from running short distances."),
//	"Diabetes"= list(-3,list(),"You cannot eat a lot of sugery things. (Possibly to lose a limb due to insulin levels)"),
	"Baldness"= list(-1,list(),"You cant grow hair at all."),
//	"Demi-God"= list(15,list(),"You are superior in many ways, but there are things still stronger than you. (Beyond max Strength, Dexterity or Philisophy, Crafting/ Speed Increase aswell"),
	"Empathetic" = list(1,list(),"You can notice what type of mood someone is in when you look at them."),
	"Deaf" = list(-3,list(),"You cannot hear at all."),
	"Mute" = list(-2,list("Stutter"),"You cannot speak at all."),
	"Heat Tolerance" = list(2,list("Heat Sensitivity"),"You can tolerate the heat better than most people."),
	"Heat Sensitivity" = list(-2,list("Heat Tolerance"),"Extreme heat affects you more than most people."),
	"Cold Tolerance" = list(2,list("Cold Sensitivity"),"You can tolerate the cold weather better than most people."),
	"Cold Sensitivity" = list(-2,list("Cold Tolerance"),"Extreme cold affects you more than most people."),
	"Stutter"= list(-1,list("Mute"),"You have a permanent stutter."),

)