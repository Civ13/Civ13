# Making laid rope

This optional route distinguishes preparing bast fibres, spinning yarn, twisting
strands and laying those strands together. Existing quick raw-hemp/raw-flax rope,
flax-tow twine, sinew cord and weak grass twine remain available. No map or spawn
loadout changes are required, and the output is ordinary rope for existing uses.
The farm's existing generic hemp harvest is labeled **plant bundles**, including
stalks and leafy tops, rather than leaves alone: bast fibre comes from the stalk.
Its harvest quantities and existing recipe costs are unchanged.

## Player route

1. Hold two hemp and choose **Tie Hemp Bundle**. Use the bundle on adjacent
   non-irradiated fresh water and complete its 30-second attended retting action.
   A cancelled action leaves the paid bundle. Click it in water to resume.
   To recover it, right-click the submerged bundle and choose **Recover Hemp
   Bundle** with a free, usable hand. This cancels in-flight retting and keeps
   the paid bundle and completed preparation, even if the water has become salty
   or irradiated. Recovery also invalidates the old wait if the bundle is
   returned to the same water before that wait finishes.
2. Load the retted bundle into an empty **hemp dressing bench**. Use the bench
   four times, ten seconds each: dry, break the woody stems, scutch away shives,
   then comb the fibres. The two raw portions become two dressed fibre portions.
   Drag the bench onto yourself to recover an unfinished bundle. Completed stages
   survive removal; destroying the bench also releases its paid bundle.
3. Hold a **hand spindle** and dressed hemp in opposite hands. Use the spindle
   on the fibre: one portion becomes one bundle of hemp rope yarn in five seconds.
   Existing **flax tow** can instead become distinct flax rope yarn by the same
   interaction. Obtain it through the existing flax bundling/retting/comb route.
   Using tow in hand still offers the existing quick twine action.
4. Combine four matching hemp yarn or flax yarn bundles into **one held stack**
   by applying matching yarn stacks to each other. Use that stack on an empty
   **hand ropewalk**; four separate stacks cannot be loaded individually.
   Mixed materials are rejected. Each bundle represents an equal group of yarns
   making one strand, rather than a single thread.
5. Use the ropewalk once for ten seconds to twist four strands under tension.
   Use again for ten seconds to lay them together in the opposite direction.
   The final action produces four ordinary rope coils. Drag the frame onto
   yourself to recover unfinished work; completed twisting survives removal.

Softwood construction costs are one plank for the spindle (Basic Tools), eight
for the dressing bench and twelve for the ropewalk (Resource Processing).
Construction uses the existing recipe system, including actual faction research,
map availability and floor/occupancy rules. Processing adds no separate era gate.
The stations currently reuse the drying-rack sprite; the spindle reuses the
wood-sheet symbol. These are recognizable placeholders, not historical depictions.

## Historical basis and deliberate abstractions

The [user's Guédelon video, 18:36 onward](https://youtu.be/7P4eCopYK_Q?t=1116)
starts with already-made hemp yarn. Its transcript describes assembling four
strands (18:54), twisting under tension with shortening at a moving traveller
(19:20-19:44), then laying in the opposite direction (20:23-20:57). This is laid
rope, not braiding. The video frames could not be verified during research;
apparatus geometry, finishing knots and exact hand motions are not claimed.
Caption counts/lengths are inconsistent and are not used as measurements.

[Guédelon's official press material](https://www.guedelon.fr/presse/) describes
flax/linen and hemp ropes in its thirteenth-century reconstruction. The
[Corderie Royale exhibit](https://www.corderie-royale.com/la-corderie-royale/visite-permanente-la-corderie-une-vie-d-ateliers/)
corroborates scutching, combing, spinning and yarn-to-strand-to-rope production
with a fixed crank head and movable sled. Its 1666 site corroborates mechanics,
not the medieval date of a particular machine. [Cotswold Archaeology's scutching
knife](https://cotswoldarchaeology.co.uk/museum/scutching-knife/) describes retting
followed by mechanical fibre cleaning. These sources support the new upstream
preparation stages; those stages are not demonstrated in the linked segment.

Four strands follows this demonstration, not a universal rule. Hemp is not
presented as universal across eras or cultures: the [Viking Ship Museum](https://www.vikingeskibsmuseet.dk/en/professions/boatyard/experimental-archaeological-research/maritime-crafts/ropemaker)
also documents lime bast, hide and hair/wool, with hemp becoming dominant later.
Those materials and recipes are outside this first batch.

All costs, yields, seconds, batch sizes, clean-water restrictions and the one-tile
station footprint are gameplay choices. Retting and drying are drastically
compressed, attended steps; this does not simulate biological retting times,
humidity, rope length, twist angle, measured shrinkage, strength or material
failure. There is no requirement for tar, chemicals, a loom or powered machinery.
The existing flax comb's straw/tow/lint stages remain a separate game abstraction.

## Ownership, persistence and verification

Inputs are consumed with `stack.use` without a human discount argument. Held
tool/fibre identity is rechecked after spindle work. One station lock protects
each wait; completion rechecks location, anchored state, the exact contained
batch and its old stage before publishing output. No progress depends on a
retained actor pointer or recurring processing worker. Completed stages and
actual contained paid batches are durable; all four temporary action locks are
explicitly excluded by the custom saver, as is the runtime retting epoch used
to invalidate recovered waits. Invalid imported stages and abstract
batch types cannot produce output.

Every interaction refuses active save/load admission. A waiting action also
captures and rechecks `persistence_admission_identity`, so a save/load that starts
and finishes during the wait still cancels completion without consuming inputs.
The route does not change the serializer's global admission or security policy.

`tests/rope_making/run.py --compile-only --byond-bin <bin> --output <fresh-dir>`
compiles the isolated native fixture without launching DreamDaemon. The normal
runner uses the existing isolated startup pattern and trusted engine, with a
closed port, refused reopen, temporary storage and pinned Linux archive/member
verification. Local native execution retains the repository's separate maintainer
authorization boundary. Hosted CI runs the positive probe and payment, replay,
admission and lock-exclusion controls for the introduced suite.

The probe exercises production actions, research registration, cancellation,
overlap, inventory loss, homogeneous batches, invalid state, persistence admission,
actual nested entry disk round trips and recovery. It uses shortened/injected wait
and inventory/HUD adapters; it does not prove connected-client visuals, ordinary
player acquisition, full-world save/load or live-server behavior. Offline Python
checks validate catalog/Help indexing and frozen existing cordage contracts.
