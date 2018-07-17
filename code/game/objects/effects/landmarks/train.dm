/obj/effect/landmark/train
	name = "train"
	icon = 'icons/mob/screen1.dmi'
	icon_state = "x"
	anchored = 1.0
	invisibility = 101

/obj/effect/landmark/train/german_train_start

/obj/effect/landmark/train/german_train_limit

// warning: don't make one train landmark type inherit from another
// or bad things happen, namely a train tries to stretch out between
// the wrong landmarks. This was previously german_train_start/supplytrain,
// and that happened

/obj/effect/landmark/train/german_supplytrain_start

/obj/effect/landmark/train/german_supplytrain_limit