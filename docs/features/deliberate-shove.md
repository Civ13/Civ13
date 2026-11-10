# Deliberate shove (draft)

With an empty active hand and Disarm intent, target **chest** or **random** to
shove a human away. Aim elsewhere to use the existing targeted disarm. Custom
martial arts still own their disarm action; Grab intent and self-grab escape
are unchanged. Breaking a target's held grips/pull consumes the action rather
than also moving or disarming them.

Initial tuning: 10 stamina per attempt, 2 seconds of shared action recovery,
up to 32 pixels of cardinal separation, and 0.4 seconds of action stagger only
when the target actually moved. Targets have 3 seconds of shove immunity
shared across attackers. They can move away immediately. No damage, knockdown,
weapon drop, wall slam, chain-pushing or area-of-effect attack is added.

This first draft handles **standing humans with smooth movement enabled**.
It does not change animal disarm/retaliation or martial arts. A target larger
than the attacker, restrained movement links, vehicle/mount/buckle state,
hanging, pinned, prone/dead, or persistence hold blocks displacement. An
explicitly disabled smooth-movement preference is respected: the pixel sweep
is not used, because a partial shove could strand that actor between tiles.
No preference is changed. A blocked attempt still costs stamina/cooldown.

## Movement and acceptance

Movement uses bounded 2px native Move pulses through the existing ownership
and collision gateway. It preserves centre-filed offsets, checks map/grace
barriers and persistence admission, stops at trench level changes, and
suppresses delayed Bump pushing and consent-swapping. The previous walking
transaction is cancelled with completion/visual cleanup, not teleported.
A wall can stop the sweep short of one tile without granting wall damage or
knockdown. No world/server save, restart or deployment is part of this change.

Offline source contracts and full-game compilation are **not** native runtime
acceptance. Before taking this PR out of draft, run an authorized isolated
fixture/client test for:

- All four directions from aligned and positive/negative offset positions;
  open space moves 32px, collision stops without overlap or teleport.
- Walls, doors, windows, another standing body, diagonal corners, trench edges,
  map/grace restrictions and persistence holds. No delayed Bump side effect.
- Shoving during a held walking transaction; cancellation executes movement
  completion once, preserves offset ownership and lets the victim move again.
- Stamina below/exactly 10, repeated clicks, shared melee cooldown, multi-attacker
  immunity, blocked attempts, and no item drop/knockdown/damage.
- Shields and martial arts, targeted arm/hand Disarm, grab breaking, self-choke
  escape, missing/unusable hands, out-of-range and cross-z attempts.
- Hanging, buckled, riding, driving, restrained/pulled/grabbed, prone/dead,
  larger targets, disabled smooth movement, and unchanged animal behavior.

No live-server or in-game result is claimed by this draft.
