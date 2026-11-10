# Physical train codec checks

`python3 -m unittest discover -s tests/train_transfer_codec` checks bounded
source contracts only. It does not execute DM or establish lossless world
transport. The implementation reuses the existing character travel codec and
freight item codec; neither these checks nor healthy-character checks establish
complete character-state preservation. NPCs, corpses, animals, occupied seats,
unsupported furniture and damaged/restrained riders are refused.

Native acceptance still requires capture/build on real consists, all supported
lengths/layouts, deep item comparisons, character-state comparisons and failure
injection, including constructor/runtime failures during staged build. Do not
enable physical departures based on these source checks alone.

Journey-scoped source contracts also require a distinct persisted trip tag for
removal, and both trip tag and manifest digest for idempotent restoration.
Existing account-owned destination bodies cause preflight refusal before any
constructor runs, avoiding the legacy character builder's ownership-clearing
side effect. These checks do not establish atomicity against constructor sleeps,
runtime exceptions, saved partial builds or concurrent account arrivals.
