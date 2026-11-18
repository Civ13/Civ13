// Integrated circuit (Wiremod) constants, shared by every file in
// code/modules/wiremod. Port type names match tgstation's so the imported
// editor recognises them.
#define PORT_TYPE_ANY "any"
#define PORT_TYPE_STRING "string"
#define PORT_TYPE_NUMBER "number"
#define PORT_TYPE_SIGNAL "signal"
#define PORT_TYPE_BOOLEAN "boolean"
#define PORT_TYPE_LIST "list"
// Editor-only name for a string port restricted to a fixed set of choices.
#define PORT_TYPE_OPTION "option"

// Longest text a port holds, in bytes.
#define PORT_MAX_STRING_LENGTH 5000
// Most entries a list on a port holds.
#define CIRCUIT_MAX_LIST_LENGTH 500
// Component calls one propagation may queue before the circuit overloads.
#define CIRCUIT_MAX_EXECUTIONS 1000
#define CIRCUIT_MAX_COMPONENTS 64
#define CIRCUIT_MAX_VARIABLES 32
// Deciseconds an overloaded circuit ignores its inputs.
#define CIRCUIT_OVERLOAD_COOLDOWN 50
// Delay component bounds, in seconds.
#define CIRCUIT_DELAY_MIN 1
#define CIRCUIT_DELAY_MAX 600
// Largest magnitude the Random component accepts for a bound.
#define CIRCUIT_RANDOM_LIMIT 1000000

#define COMPONENT_DEFAULT_NAME "component"
#define COMPONENT_DEFAULT_CATEGORY "General"
#define COMPONENT_SIGNAL (world.time / 10)
