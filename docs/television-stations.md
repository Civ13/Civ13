# Television stations (1969)

Television desks, receivers and cameras become available in 1969 (ordinal 7).
Telephones and local terminals remain 2013 equipment. Research Assembly Line,
and have 160 current crafting skill, before constructing television equipment.
On opted-in Persistence worlds, learn the Assembly Line manual too.

## Live programmes and teaching

Connect cable power to the desk and receivers, and place an antenna within one
tile of the desk. Tune the receiver and desk to the same frequency (150-300).
Receivers must be within 60 tiles on the same level. Choose **Present live** at
the desk and speak normally. Station names and faction tags are roleplay labels;
filtered live speech is recorded in the admin broadcast log. Radio and television
audiences stay separate. Television video does not cross regional radio relays.

Television has the same crafting, farming and medical skill courses as radio,
and the same five-minute recipe-node lessons on opted-in Persistence worlds.
The presenter must know the node and remain awake and active at the desk.
Listeners must stay awake and active within three tiles of the same powered,
tuned receiver for the whole lesson. Research and era ceilings still apply.
There are at most 32 listeners per broadcast, one node per station, and a
one-minute cooldown after each node lesson. Attendance is not saved.
See [radio node lessons](radio-node-lessons.md) and
[course schedules](radio-stations.md).

## Put a camera on air

1. Craft a studio, street or helmet television camera. Each costs four
   electronics and takes ten seconds; all require Assembly Line, 160 crafting,
   and 1969. The receiver costs three electronics and the desk costs ten.
2. Hold the camera and use it on the television desk to pair it physically.
   Pairing copies the station's private network identity and current frequency.
   Matching a frequency alone never grants access to another station's cameras.
3. For a fixed camera, use it in hand to switch power on and **Install** it.
   Drag a laid cable within one tile onto it. A wrench unfastens it for removal.
   Studio and street versions have identical capabilities and visible camera art.
4. For a helmet camera, recharge it using a power cell, switch it on in hand,
   and choose **Fit to helmet** while wearing headgear. It remains a real item
   clipped to the headgear. Examine the headgear to see the camera and red power
   light. **Remove Television Camera** removes it. Its 1,000-unit battery drains
   one unit per running-server second while fitted and switched on, whether or
   not anyone is watching. Cameras can be removed and smashed or shot.
5. Keep the camera within 60 tiles of its paired desk on the same level. Choose
   **Video feed** at that desk, then select one of its powered paired cameras.
   Only one camera airs at a time; **Stop video** ends the feed. Retuning the desk
   requires physically pairing cameras again to copy the new frequency.
6. Stand within one tile of a powered matching TV receiver, choose **Watch video**,
   and select the station. Move or click the receiver again to stop watching.
   Up to 32 viewers can watch one station, across all its receivers.

Fixed cameras draw 10 power, receivers 10, and TV desks 30. Video ends when the
camera, desk or receiver loses power or goes out of range, an antenna is lost,
frequencies or network pairing no longer match, or the viewer becomes unable to
watch. Moving a desk, receiver or fixed camera ends its current view session.
Helmet wearers can move within range; taking off the headgear, changing the
camera wearer or depleting its battery ends the feed. Viewers must stand still.

## Saving and older televisions

Camera items, battery charge, condition, frequency and paired network identity
save with the world. Desk network identity and ordinary equipment settings also
save. Camera selections, presenters, viewer references and lesson attendance do
not. After loading, start a fresh feed and choose to watch again.

New television recipes produce functional broadcast receivers. Existing legacy
televisions remain decorative and explicitly describe this limitation; their
saved type paths, dismantling behavior and unrelated grandfather clocks remain
compatible. No existing map is automatically activated or modified.

## Verification

The isolated `tests/television` fixture contains power/range/movement teardown,
live/course/node teaching and camera/save/session assertions against production
procedures. Its compile-only mode checks compilation, not native execution or
save/reload acceptance. The offline contract suite checks gates, pairing,
transient fields, recipes and bounded view ownership. Connected-client camera
rendering and human UI acceptance require a separate in-game check.
