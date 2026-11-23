// Railways: what more than one file needs (docs/trains.md).

#define WOODEN_RAIL_COLOR "#b9824a" // the tint of timber rails, laid and loose (train_early.dm)

// Walkable platform cars (1713/train_platforms.dm, train_draught.dm).
#define TRAIN_CAR_LENGTH 4 // the four-wheel stock and the heavy locomotives
#define TRAIN_LONG_CAR_LENGTH 8 // bogie stock
#define TRAIN_LEFT -1
#define TRAIN_RIGHT 1

// Driving (1713/trains.dm): tiles per second gained each second by a train
// with just enough pull; one with pull to spare gains up to twice this.
#define TRAIN_ACCEL 0.25
