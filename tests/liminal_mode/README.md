# Liminal Facility escape round

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/liminal_mode/probe.dm
```

Production sources run in the shared resource-extraction fixture with ordinary
game startup disabled. Times are passed to the round explicitly. `probe.dm` checks:

- Configuration: holds outside 10-120 s, deadlines outside 10-30 min and teams over four are refused; READY needs an admitted era policy.
- Admission: the first body starts the clock, up to four join within 60 s, later or extra bodies are not participants.
- Progress: service before discovery, non-participants and unconscious bodies are refused; flags are shared, idempotent and recorded once.
- Timers: the hold needs 20 s of elapsed time and breaks when the zone empties; the round fails at 15 min or with no living participant; a hold completing on the deadline step escapes; a finished round never changes.
- Policy: only the 1990 kit is issued, an unlisted object on the map or a year outside 1990-1993 refuses the policy, and the liminal recipe list offers only utensils.
- Objects and metadata: the gate starts sealed and cannot be forced, the panel refuses before the marker, the marker grants discovery, the panel opens the gate, an unconscious participant does not hold the egress, escape finishes once and a deleted last body fails the round.

- Threat (slice 5): none before the round or during the 30 s grace, placed at most once, a map without a site or with threats off records NONE, any living human near the site or with a clear line to it (a non-participant, someone in a locker) defers it while a wall row does not, a world already holding the threat gets no second, then one echofiend appears at the landmark; sounds within 15 tiles send it to investigate, its own growl does not cancel that, and the sealed gate stops it until opened.
- Scene: the facility area is indoors with hallway reverb and no ambience, the round keeps one Night time of day, tubes and bulbs light without power and are the only lights on the prop list.

Changing the hold comparison to accept any elapsed time makes the 19.9 s check fail;
dropping the echofiend's own-tile check makes the growl check fail.
The probe does not boot the exported map or move players through it; the native
boot evidence is in tools/liminal_maps/README.md. Client-side light, audio,
attacks and group play are unverified.
