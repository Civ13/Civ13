# Integrated Circuits

An **integrated circuit** is a small programmable board. Inside it you place components such as adders, comparisons and text tools, and wire them together in a node editor. The **compact remote** is a handheld button that holds one integrated circuit. Pressing it sends a signal through whatever you have wired up.

## Getting one

- Research **Digital Computing** on your faction's [tech tree](Guide_to_Research.md).
- Craft an **integrated circuit** from 4 electronics, or a **compact remote** or **mechanism port** from 5 electronics each. Both are in the electronics section of the crafting menu. Electronic circuits are made from copper; see [Crafting](Guide_to_Crafting.md).

## The editor

Use an integrated circuit in your hand to open its editor. For a circuit inside a compact remote, Alt-click the remote. You must be holding it, or standing next to it while it lies on the ground.

- **Add a component:** open the component menu and drag a component onto the board. Components are made in the editor and cost nothing extra. A circuit holds up to 64 of them.
- **Wire it up:** drag from an output (on the right of a component) to an input (on the left of another). An input takes one wire, while an output can feed many inputs. Right-click a port to remove its wires.
- **Set a value:** type into an input that has no wire. Inputs with a fixed set of choices, such as an arithmetic operation, show a dropdown instead.
- **Fire by hand:** click a signal input to send it a signal straight away.
- **Mark a person or object:** click an entity input to mark the item in your other hand, or yourself if that hand is empty. Marking the same thing again clears the input.
- **Read about a component:** the (i) button on a component explains what it does and lists its ports.
- **Variables:** the variable menu makes named values of a chosen type (up to 32 per circuit). Getter nodes read a variable and setter nodes write it.
- **Rename:** you can give the circuit a display name.

Port types are colour-coded: numbers green, text orange, true/false red, signals teal, lists white, entities (people and objects) purple, choices violet and "any" blue. A wire only joins ports whose types fit. An entity wired into a text input becomes its name.

## Components

| Category | Component | What it does |
| --- | --- | --- |
| Math | Arithmetic | Add, subtract, multiply, divide, modulo, power, minimum or maximum of A and B. |
| Math | Comparison | Equal, not equal, greater or less than (or equal). Outputs true or false. |
| Math | Logic | AND, OR or XOR of two values. |
| Math | Not | The opposite of a true/false value. |
| Math | Random | A random whole number between two bounds. |
| Math | Length | The length of a piece of text or a list. |
| String | String Concat | Joins two pieces of text. |
| String | String Contains | Whether one piece of text contains another. |
| String | String Replace | Replaces every match in a piece of text. |
| String | String Split | Splits text at a separator (a comma by default) into a list. |
| String | String Case | Converts text to upper or lower case. |
| String | String to Number | Reads a number out of text. |
| List | List Add | Adds a value to the end of a list. |
| List | List Remove | Removes a value from a list. |
| List | List Concat | Joins two lists. |
| List | List Index | The value at a position in a list, counting from 1. |
| Entity | Direction | The compass direction and distance in tiles to a marked person or object up to 7 tiles away on the same level. |
| Utility | Delay | Waits 1 to 600 seconds after its trigger, then sends a signal. A new trigger restarts the wait. |

Most components work out their output as soon as an input changes.

## The compact remote

A new compact remote is empty. Use an integrated circuit on it to put the circuit inside, and the remote adds its button component to that circuit. Use a screwdriver on the remote to take the circuit out again. The button stays with the remote and goes into the next circuit you insert.

Use the remote in your hand to press it. Its button component has two outputs:

- **Signal**, sent each time it is pressed.
- **User**, whoever pressed it. Wire it into a text input to get their visible name, or into Direction to find where they are.

For example, you can wire User into a String Concat and Signal into a Delay to build a message about who pressed the button.

## The mechanism port

A mechanism port (5 electronics) is a circuit holder that works the [cord mechanisms](Guide_to_Levers_and_Mechanisms.md). Insert a circuit and Alt-click it to edit, just as with the remote. Set it on the floor and use rope on it to tie cords to doors, gates, bells and the like within seven tiles. Its component has:

- **Pull**, an input. A signal here pulls every cord tied to the port, at most once every two seconds.
- **Mode**, an input. *toggle* works the cords like a pull cord, *throw* like a lever thrown over and *throw back* like a lever thrown back.
- **Pulled**, an output. It sends a signal when the cord of a lever or pressure plate tied to the port is pulled.
- **Thrown**, an output. It is true, or false when that cord came from a lever thrown back.

## Limits

- Text on a wire is cut off at 5,000 characters, and lists hold up to 500 entries.
- A circuit that feeds back into itself, for example two components triggering each other forever, **overloads**. It goes quiet for about five seconds and warns whoever is holding it.
- A wire carries a person or object only as a mark. If the thing is destroyed, the mark clears. Lists hold only numbers and text.
- Circuits are not kept when the world is saved. Note down any design you want to keep.
