// factional train controllers

/datum/train_controller/german_train_controller

/datum/train_controller/german_train_controller/New()
	..(GERMAN)

/datum/train_controller/german_supplytrain_controller
	var/supply_points = 200
	var/here = TRUE

/datum/train_controller/german_supplytrain_controller/New()
	..("GERMAN-SUPPLY")
	direction = "BACKWARDS"

/datum/train_controller/russian_train_controller/New()
	..(SOVIET)
