// Modular computers (code/modules/1713/computers/modular/).
// Module slots a chassis offers.
#define COMPUTER_SLOT_CPU "cpu"
#define COMPUTER_SLOT_DRIVE "drive"
#define COMPUTER_SLOT_MEDIA "media"
#define COMPUTER_SLOT_EXPANSION "expansion"

// Capabilities modules grant; programs list the ones they need.
#define COMPUTER_CAP_CPU "cpu"
#define COMPUTER_CAP_STORAGE "storage"
#define COMPUTER_CAP_MEDIA "media"
#define COMPUTER_CAP_PRINT "print"

// Saved file caps: characters per file body and name, files per medium.
// One KB of capacity holds 1,000 characters of names and text.
#define COMPUTER_FILE_MAX_CHARS 2500
#define COMPUTER_FILE_NAME_MAX 24
#define COMPUTER_FILES_PER_MEDIUM 40
#define COMPUTER_CHARS_PER_KB 1000
#define COMPUTER_PRINTER_MAX_PAPER 20
