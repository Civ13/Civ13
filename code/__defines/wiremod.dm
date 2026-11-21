// Integrated circuit (Wiremod) constants, shared by every file in
// code/modules/wiremod. Port type names match tgstation's so the imported
// editor recognises them.
#define PORT_TYPE_ANY "any"
#define PORT_TYPE_STRING "string"
#define PORT_TYPE_NUMBER "number"
#define PORT_TYPE_SIGNAL "signal"
#define PORT_TYPE_BOOLEAN "boolean"
#define PORT_TYPE_LIST "list"
// A text port restricted to a fixed set of choices; the editor shows a dropdown.
#define PORT_TYPE_OPTION "option"
// A thing in the world (a person or an object), held as a weak reference.
#define PORT_TYPE_ENTITY "entity"
// Text keys to plain values, held as a bounded copy. A separate type from list.
#define PORT_TYPE_ASSOC_LIST "assoc_list"

// The datatypes a player may type a value for, in the order the editor lists them.
#define CIRCUIT_USER_TYPES list(PORT_TYPE_NUMBER, PORT_TYPE_BOOLEAN, PORT_TYPE_STRING, PORT_TYPE_ANY)
// The datatypes a player may give a circuit variable.
#define CIRCUIT_VARIABLE_TYPES list(PORT_TYPE_NUMBER, PORT_TYPE_BOOLEAN, PORT_TYPE_STRING, PORT_TYPE_ANY, PORT_TYPE_ENTITY)

// Longest text a port holds, in bytes.
#define PORT_MAX_STRING_LENGTH 5000
// Most entries a list on a port holds.
#define CIRCUIT_MAX_LIST_LENGTH 500
// Most keyed entries an associative list on a port holds.
#define CIRCUIT_MAX_ASSOC_ENTRIES 100
// Most inputs the Concatenation component may be given.
#define CIRCUIT_MAX_CONCAT_INPUTS 10
// Most entries a list literal component may be given.
#define CIRCUIT_MAX_LITERAL_ENTRIES 10
// Component calls one propagation may queue before the circuit overloads.
#define CIRCUIT_MAX_EXECUTIONS 1000
// Most steps a list loop (For Each, Filter List) may take in one run.
#define CIRCUIT_MAX_LOOP_STEPS 100
#define CIRCUIT_MAX_COMPONENTS 64
#define CIRCUIT_MAX_VARIABLES 32
// The last number a circuit gives a component. Whole numbers stay exact well
// past this, so the count can never stall and hand out the same number twice.
#define CIRCUIT_MAX_COMPONENT_ID 10000000
// Deciseconds an overloaded circuit ignores its inputs.
#define CIRCUIT_OVERLOAD_COOLDOWN 50
// Deciseconds between the editor refreshes a running circuit sends to an open window.
#define CIRCUIT_UI_REFRESH_INTERVAL 3
// Delay component bounds, in seconds.
#define CIRCUIT_DELAY_MIN 0.1
#define CIRCUIT_DELAY_MAX 600
// Largest magnitude the Random component accepts for a bound.
#define CIRCUIT_RANDOM_LIMIT 1000000
// Furthest, in tiles, a world component looks from its shell.
#define CIRCUIT_DIRECTION_RANGE 7
// Most entities a View Sensor reports at once.
#define CIRCUIT_MAX_VIEW_ENTITIES 64
// Most steps a Pathfinder search may take for one request.
#define CIRCUIT_MAX_PATH_STEPS 64
// Most tiles a Pathfinder search may examine for one request.
#define CIRCUIT_MAX_PATH_NODES 256
// Deciseconds between two sounds or two spoken lines from one component.
#define CIRCUIT_SOUND_COOLDOWN 10
#define CIRCUIT_SPEECH_COOLDOWN 10
// A circuit light's reach and brightness, in tiles.
#define CIRCUIT_LIGHT_RANGE 4
#define CIRCUIT_LIGHT_POWER 2
// Bits in a number the Binary Conversion component reads or writes.
#define CIRCUIT_BINARY_BITS 8

#define COMPONENT_DEFAULT_NAME "component"
#define COMPONENT_DEFAULT_CATEGORY "General"
#define COMPONENT_SIGNAL (world.time / 10)

// Clocked VM. Guest capacity is not a measurement of the DM heap.
#define CIRCUIT_CPU_RAM_BYTES 524288
#define CIRCUIT_CPU_PAGE_BYTES 256
#define CIRCUIT_CPU_PAGE_WORDS 86
#define CIRCUIT_CPU_WORD_MAX 16777215
#define CIRCUIT_CPU_PROGRAM_MAX 256
#define CIRCUIT_CPU_SLICE 16
#define CIRCUIT_CPU_BOARD_OPS 64
#define CIRCUIT_CPU_WORLD_OPS 512
// Do not let arbitrarily many shells each fill a private 512 KiB allocation.
#define CIRCUIT_CPU_WORLD_RAM_BYTES 8388608
