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

// The datatypes a player may type a value for, in the order the editor lists them.
#define CIRCUIT_USER_TYPES list(PORT_TYPE_NUMBER, PORT_TYPE_BOOLEAN, PORT_TYPE_STRING, PORT_TYPE_ANY)
// The datatypes a player may give a circuit variable.
#define CIRCUIT_VARIABLE_TYPES list(PORT_TYPE_NUMBER, PORT_TYPE_BOOLEAN, PORT_TYPE_STRING, PORT_TYPE_ANY, PORT_TYPE_ENTITY)

// Longest text a port holds, in bytes.
#define PORT_MAX_STRING_LENGTH 5000
// Most entries a list on a port holds.
#define CIRCUIT_MAX_LIST_LENGTH 500
// Component calls one propagation may queue before the circuit overloads.
#define CIRCUIT_MAX_EXECUTIONS 1000
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
#define CIRCUIT_DELAY_MIN 1
#define CIRCUIT_DELAY_MAX 600
// Largest magnitude the Random component accepts for a bound.
#define CIRCUIT_RANDOM_LIMIT 1000000
// Furthest, in tiles, the Direction component finds its target.
#define CIRCUIT_DIRECTION_RANGE 7

#define COMPONENT_DEFAULT_NAME "component"
#define COMPONENT_DEFAULT_CATEGORY "General"
#define COMPONENT_SIGNAL (world.time / 10)
