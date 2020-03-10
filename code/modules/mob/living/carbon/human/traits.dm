/mob/living/carbon/human
	var/list/traits = list()
//name = cost, exclusions, description
var/global/list/trait_list = list(
	"Lactose Intolerance" = list(-1,list(),"You have the inability to digest dairy products and will get sick when you ingest them and you are not as strong as everyone else. (Get food poisoning from anytype of milk product and have a limit on strength)"),
	"Skilled Archer" = list(3,list(),"No description."),
	"Skilled Fighter" = list(3,list(),"No description."),
	"Partial Blindness" = list(-2,list(),"No description."),
	"Introverted" = list(-3,list("Extroverted"),"No description."),
	"Extroverted" = list(-1,list("Introverted"),"No description."),
	"Down Syndrome" = list(-5,list(),"No description."),
	"Sickle Celled Anemia" = list(-1,list(),"No description."),
	"Hemophilia" = list(-2,list(),"No description."),
	"Spinal Paralysis" = list(-3,list(),"No description."),
	"Schizophrenia" = list(-4,list(),"No description."),
	"Dwarfism" = list(3,list("Gigantism"),"No description."),
	"Hyperpigmentation" = list(5,list(),"No description."),
	"Gigantism" = list(5,list("Dwarfism"),"No description."),
	"Sixth Sense" = list(3,list(),"No description."),
	"Agile" = list(3,list("Slowness"),"No description."),
	"Weak Immune System" = list(-2,list(),"No description."),
	"Strong Immune System" = list(4,list(),"No description."),
	"Veganism" = list(-1,list("Carnivore"),"No description."),
	"Carnivorism" = list(-1,list("Vegan"),"No description."),
	"Slowness" = list(-2,list("Agile"),"No description."),
)
