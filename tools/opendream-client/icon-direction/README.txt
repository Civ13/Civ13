The icon-direction.patch is a separate runtime fix against the same pinned engine
as movement.patch. A single SOUTH direction is the normalized result of
icon(source,dir=D). Reinsert must use that frame even when D is NORTH/EAST/WEST,
while preserving D in the destination. Multi-direction icons with missing
requested directions still yield no frame. This does not modify human limbs.

Native BYOND516.1681 probe.dm produced red/green/blue/yellow for SOUTH/NORTH/EAST/
WEST constructor-plus-Insert. Production DMIParser compiled in the focused C#
fixture passed 15 assertions; unpatched source failed the reinsertion assertion.
Full OpenDream server build: 0 errors, 141 existing/dependency warnings.
This is runtime/server icon generation; graphical acceptance remains required.
The real OpenDream Content.Tests ConstructorDirection regression also passed
(1 selected test, no failures), exercising constructor and Insert through the
DM runtime. Existing movement source remains in the same candidate build.
