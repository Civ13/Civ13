// Item inventory slot bitmasks.
#define SLOT_OCLOTHING  0x1
#define SLOT_ICLOTHING  0x2
#define SLOT_GLOVES	 0x4
#define SLOT_EYES	   0x8
#define SLOT_EARS	   0x10
#define SLOT_MASK	   0x20
#define SLOT_HEAD	   0x40
#define SLOT_FEET	   0x80
#define SLOT_ID		 0x100
#define SLOT_BELT	   0x200
#define SLOT_BACK	   0x400
#define SLOT_POCKET	 0x800  // This is to allow items with a w_class of 3 or 4 to fit in pockets.
#define SLOT_ACCESSORY  0x1000  // This is to  deny items with a w_class of 2 or 1 from fitting in pockets.
#define SLOT_TWOEARS	0x2000
#define SLOT_SHOULDER   0x4000
#define SLOT_HOLSTER	0x8000 //16th bit - higher than this will overflow

// Flags bitmasks.
#define PLASMAGUARD		0x20 // Does not get contaminated by plasma.
#define PROXMOVE		   0x80  // Does this object require proximity checking in Enter()?

//Flags for items (equipment)
#define FLEXIBLEMATERIAL	   0x20 // At the moment, masks with this flag will not prevent eating even if they are covering your face.



// Bitflags for the percentual amount of protection a piece of clothing which covers the body part offers.
// Used with human/proc/get_heat_protection() and human/proc/get_cold_protection().
// The values here should add up to 1, e.g., the head has 30% protection.

#define		 COAT_MIN_COLD_PROTECTION_TEMPERATURE 200 // For coats
