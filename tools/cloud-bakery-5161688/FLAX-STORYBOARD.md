# Flax chapter A body — source-only integration notes

Body: flax-chapter-a-body.dm. Same pinned9683866 production handlers, no overrides. Main integrates the genuine guest-human subtype and existing fixed-camera/zero-verb safety path. Globals/helper names are flax_worker, filming_assert_flax_initial, filming_prepare_scene, filming_take.

Authored map change required: freshwater `/turf/floor/beach/water` at7,7 replaces fertile plot; source/witness seals must explicitly bind it. Raw flax2 at7,6; worker6,7. Final ordinary west step goes to5,7, still in the proposed view2/zoom3 frame. No second actor needed for this incomplete stage.

Timing nominal: initial20ds + tied bundle20ds + actual100ds first soak + at most one0.5ds observation/cancellation tick + final40ds = about180.5ds. Monitor deadline is take_start+150ds; native take must finish≤195ds. All elapsed waiting counts against existing165s work budget. No new recording/capture cadence.

Production afterattack transfers actual bundle to freshwater before entering soak. A spawn(0) observer executes only when the same production do_after yields; it checks same real actor/client and bundle/site. It polls unchanged production soak_stage; on first observed stage1 it ordinary-steps actor west out of reach. Production second do_after cancels because actor location changed, leaving actual stage1 intact. Body asserts exact actor coordinates/zero offsets, separate numeric movement return, stage1 not2, no rotten-flax output, soakingFALSE and no ongoing action before final hold. No directstageassignment, shortened wait, forceMove, directlocassignment, or manually invoked completion. Failure/timing/malformedstage stops fixture rather than producing a clip.

Scheduling is bounded rather than assumed: if spawn(0) runs before afterattack transfers the bundle, the observer permits only the original still-held stage0/notsoaking state at the exact worker start and yields0.5ds. Once the bundle is on water, it observes only stage0/1 until interruption. Unexpected location, changed identity or stage2 fails closed. If afterattack returns without doing the work, main immediately rejects missing interruption rather than waiting for false completion.

Visual/caption: raw flax and tied bundle share original flax art with tint; no progressbar is promised, and first stage completion has no dedicated sprite change. Final actor movement signals pause, not completed retting. Caption must say "Chapter1: binding and beginning retting. One genuine10-second stage completed; worker steps away, leaving1/3 complete. Later chapters use independent batches, not continuous footage." No claim of finished rotten flax or same-batch continuation.

No native execution, publication, production timer mutation or controller edits by this source-preparation task. Parent must review and integrate into its sealed controller and tests before activation.

## Delivery caption

Genuine Civ13 capture at approximately 4fps. Chapter 1: supplied two harvested flax portions, real binding and one full ten-second freshwater soaking stage. Ordinary worker movement pauses retting at one of three stages; not finished retted flax. Later chapters use independently produced batches with omitted waiting, not one continuous batch.

No native progress bar is promised: isolated worker preferences are absent; the unchanged production action may have no progress bar. Initial bundle and soaking retain original flax art/tint, with no dedicated stage-one sprite. Water placement and real worker movement are visible; numeric stage evidence is in receipts, not an invented animation.

## V47 presentation and acceptance plan

Chapter A is titled “Flax 1/3 — bind and begin retting”. It is not a finished retting tutorial by itself. Record the supplied two raw portions (0–2s), the genuinely paid bundle (2–4s), water placement, a 0.5-second visible hold, then normal hand interaction and one full 10-second stage (4.5–about14.5s), then ordinary worker movement and the paused unfinished bundle (about14.5–18.55s). Capture remains 20s/80 frames. No timing is assigned to production state, and no looped work animation is invented.

After actual footage exists and every frame passes review, use a separately reviewed captioned presentation with reading holds, preserving every source sample and actual timing. Candidate captions: “Start with two harvested flax portions”; “Tie them into a bundle”; “Soak the bundle in fresh water”; “One of three soaking stages complete”; “Paused here — not yet retted flax”. Stage-one completion is receipt-supported but uses the same art as the uncompleted bundle; captions must explain this rather than imply a visible sprite transformation. Do not claim a progress bar or animated work that this source does not render.

The three chapters use independent paid batches. Chapter B starts with genuinely completed 30-second retting from a separate batch, with this waiting explicitly disclosed. Chapter C similarly uses genuine preparatory stages and must label the omitted middle waiting. Across the set the initial/finished process endpoints and the actual same-item final handoff are shown; this is not uninterrupted same-batch footage. A later combined edit must preserve those labels and receive its own resource/provenance/full-playback review.

Same V43 HUD/viewport safety applies at pickup, binding, normal water placement, ordinary movement, beats and 0.5-second observations during the take. Typical52 / conservative55 rows through19.5s, within96-row/16000-byte limits. First-yield post-transfer evidence additionally rejects a bundle left in either hand or screen, wrong plane/layer or nonnull screen_loc. It never removes stale entries itself. The watcher ends at scene completion; remaining native samples retain capture and border checks. Native compile, asynchronous cancellation timing and visual legibility remain unproven for this new scene.

Acceptance: all80 source frames, exact production/movement/viewport receipts and owned cleanup; no black viewport/camera shift; captions tied to actual observed frame boundaries; readable mobile text and pauses; entire exported playback. No uncaptioned engineering clip is final delivery. No native action is authorized by this storyboard alone.

V47 correction: V46 successfully bound and placed the real bundle but automatic soaking did not begin. The next chapter explicitly says “Place the bundle in fresh water, then interact to start soaking.” It uses normal attack_hand on the actual placed bundle; no direct soak call or production return override. First-stage waiting is measured from that real interaction. Stage1 remains incomplete. The extra0.5s placement hold keeps nominal take18.55s within unchanged19.5s deadline.
