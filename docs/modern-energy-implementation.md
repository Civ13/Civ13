# Modern energy implementation checkpoint

This branch is a source-only draft, not an available player feature. The new
source and process files are deliberately not included in the DME yet. No native
compiler, daemon, benchmark, screen control or restart has been run.

The first source contract registers at most 128 machines in one shared scheduler,
uses expiring one-second output, and retains the interval's charge debit across
toggles. Delayed processing does not backfill energy. Movement, deletion and reload
stop output. Runtime wiring, registration, epochs and prepaid output are explicitly
excluded from custom saves using parenthesized membership and inherited exclusions.

Solar output reads the native time-of-day label and local area's outdoors/weather
state. Night, unknown labels and indoor areas yield zero. The existing solar_screen
DMI state represents the controller, not a new panel sprite or gameplay capture.
The proposed 30-PU midday rating remains unverified balance pending native tests.

Next bounded source work: coordinate cable and battery charging integration, add
paid Modern recipes and research/skill gates, and implement abstract-fuel nuclear
machinery with finite coolant, controls, wear and maintenance. No global radiation
flag, radiation sweep or existing radioactive ore behavior may be assumed safe.
Local hazards require explicit distance, z-level, interior and cancellation tests.

Acceptance remains outstanding: pinned compilation; native grid/storage demand and
charge conservation; source expiry/disconnect/reconnect/toggle and duplicate-port
controls; solar day/weather/night cycles; durable fuel/coolant/wear with runtime
save exclusions; nuclear safe shutdown/cooling/maintenance/local hazard controls;
real DMI pixel audit/preview; reachable crafting routes and exact-head CI. Native
tests require the coordinator's exclusive grant. Player docs/wiki follow verified
available behavior, not this draft contract.
