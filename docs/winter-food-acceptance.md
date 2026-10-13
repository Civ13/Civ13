# Winter food audit and acceptance

Status: the narrow open-can regression passed isolated native storage and save/load checks at `9851c638742256ad46c657a6ede3d67a1d1aa416`. Broader winter-food and player acceptance remain pending.
Audit base: `1627730ecec53f385cbf1956b7a9e4385dffa675`.

## Actual clocks

The ordinary Nomads constructor and base season loop each schedule 18,000 ticks,
nominally 30 minutes at 10 ticks/second. Ice Age's custom loop schedules 9,000
summer ticks and 27,000 winter ticks. Mountain has a 18,000-tick custom wet/dry
loop. Fixed wet-season labels and disabled seasons require an elapsed-time
fallback for any transition-based food lifetime. No extended duration is confirmed.
Continental calls its Nomads parent constructor and also schedules seasons itself;
verify whether these inherited callbacks produce two recurring chains before
using nominal intervals as observed cadence.

Food currently uses a separate randomized 590-610 tick callback per decaying item.
Each callback adds 600 age on a floor, 300 in ordinary storage, 200 in an unpowered
fridge, 75 in a powered fridge, or 50 in a freezer. These are immediate-container
checks, not proof that nested bags benefit from refrigeration. Closed cans and
vending machines pause age. Open cans also avoid the final accumulation branch;
this is a candidate preservation exploit requiring production-path verification.
Food is not opted into the generic abandoned-item registry by its parent.

| Example | Current decay units | Nominal floor lifetime | Nominal ordinary-storage lifetime |
| --- | ---: | ---: | ---: |
| Tomato | 9,000 | 15 minutes | 30 minutes |
| Cabbage | 12,000 | 20 minutes | 40 minutes |
| Wheat | 3,000,000 | 5,000 minutes | 10,000 minutes |
| Potato | 420,000 | 700 minutes | 1,400 minutes |
| Rice stalk | 0 | No decay callback | No decay callback |

These are source arithmetic, not measured lifetimes or nutrition availability.
Floor potatoes also have a random green-potato conversion and early deletion.
Rot-capable foods become rotten at half their decay limit. Crop classes therefore
cannot share one undifferentiated fresh-food lifetime.

## Acquisition and preservation leads

Default global recipes offer a three-plank fishing pole and four-rope net through
Basic Tools. Fish schools accept poles or a sharpened branch; successful attempts
consume their counter. Empty schools schedule one replenishment after 3,000-3,600
ticks. Concurrent attempts and save/reload recovery require tests before claiming
bounded renewable supply. Continental additionally spawns fish schools at runtime;
placed-map counts alone cannot establish access from a player spawn.

Fishing cages cost twelve planks and have mode/research thresholds to validate.
Their catches wait 18,000-24,000 ticks and require water at completion. Ice/water
conversion, construction access, species products and saved pending work require
separate checks. Hunting must reuse existing species-bounded animal harvesting.

A dehydrator costs five raw wood in the global catalog but is mapped to
`resource_processing`; legacy thresholds and faction gates must be checked before
calling this an early-era preservation route. Its nominal drying work is 1,200
ticks, advanced by 150-tick callbacks. It constructs the dried product and deletes
the input. Food age, nutrition conservation, interruption and native reload must
be tested across that transformation; a new output must not provide repeatable
age-reset or yield amplification.

## Required implementation and acceptance

Choose explicit food categories and finite transition budgets that bridge the
intended lean season while retaining a benefit for preservation. Keep a documented
elapsed fallback for maps without real seasonal transitions. Avoid per-item
sleeping chains and runtime fields in durable saves. Preserve paid food quantities,
partial consumption, existing rot effects and irreversible accumulated age across
storage moves, season changes and reloads. Do not extend generic debris cleanup to
stored food.

Map/biome seed compatibility, actual resource paths, authorised research, winter
fish access, hunting depletion, preservation and edible consumption must be checked
on supported Nomads maps. Broader native tests and actual gameplay are pending a fresh shared native queue grant. Do not update public player guidance from these hypotheses.

Sources: `code/modules/reagents/reagent_containers/food.dm`,
`food/grown.dm`, `food/snacks/meat.dm`, `code/game/objects/map_metadata/nomads`,
`code/game/mob/living/simple_animal/friendly/static.dm`,
`code/game/objects/structures/sea.dm`, `code/modules/1713/production.dm`,
`config/crafting/material_recipes_global.txt`, and
`code/modules/research_tree/research_node.dm`.

## Prepared open-can regression

The draft changes only the final ordinary-storage aging branch so opened cans
accumulate age; sealed cans still return before that branch. Run the existing
`tests/food_progression/run.py --probe storage --byond-bin <516.1681-bin>`.
The prepared fixture checks sealed/opened cans, faster floor aging, and actual
native entry restoration followed by continued aging. `--can-negative-control`
restores the old opened-can exclusion only in generated source and must fail
`opened can accumulates food age`. Only the recurring wait is accelerated.
Both modes passed at `9851c638742256ad46c657a6ede3d67a1d1aa416` with BYOND 516.1681, zero compile errors/warnings and no runtime errors. The negative control detected the historical opened-can exclusion. This narrow correction does not replace per-food callbacks
or establish preserved-food conservation, lean-season lifetimes or player access.

## Isolated drying conservation evidence

At `a73c30e9f9058375977d2d224f4b8ef42751e6ca`, the production octopus drying probe passed with BYOND 516.1681, zero compiler errors/warnings and no runtime errors. The fixture removes nutrition to represent a partially consumed paid input, exercises production rack insertion and `before_save` cleanup, and restores its partial nutrition, accumulated age and encoded drying progress from a native disk entry before finishing production drying. Output nutrient caps and accumulated age assertions passed. Independent generated-source omissions of the nutrition cap and age carry each failed their corresponding assertion.

The recurring drying wait alone is accelerated. This is a synthetic 6x3 fixture with normal startup disabled and temporary storage; it does not prove player consumption, every drying recipe, a full-world rack save round trip, multi-season food availability, or winter map access. The Windows guarded batch used 41 seconds, remained below 218 MB owned private memory and above 13 GB free physical memory, and cleaned its owned processes and generated temporary files. Candidate production changes and their CI remain separate from the previously tested opened-can correction in #3110. No public player or wiki availability claim follows from this fixture.

## Rack graph diagnostic and pending transfer contract

The current source correction checks actual wrapper contents before the empty
slot path or any drop. It refuses more than twelve wrapper children, any slot
item outside the wrapper, and every wrapper child absent from the unique paid
handles. This prevents omitted food during legacy restoration before queued
refill, or when only some wrapper children have slots. Prepared fixtures cover
empty and partial slots with orphan paid inputs, and stale slots pointing to
foreign custody. They require specific refusal diagnostics and unchanged
custody, encoded progress, nutrition and callback ownership. These checks are
native unrun.

The prepared `--rack-control coverage` omission removes only the production
wrapper-child membership refusal in generated source. It must fail
`wrapper coverage refusal mode 0 reaches ownership check`; another failure or a
compile error does not validate that control. The twelve-child cap and declared
slot ownership checks remain present. This control is native unrun.

The single diagnostic run at `aac7d1d51f6c56f5390b4eef93007d9288598018`
compiled with BYOND 516.1681 with zero errors and warnings. It logged zero
paid-input pins, an empty input reference and empty direct-turf membership,
despite the input reaching the turf; the turf contained one saved child
reference. The original paid-input graph assertion failed. Import, refill and
conversion assertions were not reached. Runtime-field exclusion and stale-wait
assertions passed before this failure; omission controls remain unrun.

The guard completed in 37.828 seconds including cleanup, with peak owned
private memory 223,088,640 bytes and minimum host-free memory 9,095,430,144
bytes. Checked termination succeeded, with no remaining owned processes,
deferred files or cleanup errors. Independent inspection confirmed generated
files absent and the existing Gaia process, three tracked file hashes and
listening ports unchanged. The local runtime slot was explicitly released.
Evidence is retained under
`D:/GitHub/Civ13/.codex-remote-attachments/rack-save-aac7d1d51-positive-native`.

The source candidate uses a serializer-owned active parent context and
bounded rack relocation reporting. Before dropping anything, the rack must
capture at most twelve unique actual slot items, validate wrapper ownership,
and obtain an active, unfinished owning-turf export frame. It then validates
each captured identity reached that same turf before declaring the transfer.
The serializer must attach declared identities exactly once, including hints
discovered during saved-variable recursion, before finalizing the parent's
content graph. Variable-first rack discovery without an active parent is
refused before mutation. Invalid ownership, replaced parents, unsupported
destinations or excess hints invalidate save completion. Failure cleanup and
retention of a prior complete save generation belong to the shared serializer
contract. The rack hook is prepared against the owner's `before_save_context`,
`prepare_save_transfer` and `commit_save_transfer` APIs. Shared commit
`9f335f1091f0900eb63c6a0a18d72037363e1318` is integrated into this branch. This is native
unrun source and does not change PR #3105's separate snapshot/yield contract.

If drop or commit throws, the rack sets its runtime process owner to
`SAVE_REPAIR_REQUIRED`, remains
quiescent and throws an explicit repair error. It does not schedule delayed
refill: ownership could change during that wait, allowing stale slot references
to reclaim another owner's item. Cleanup performs no food conversion, nutrition
change or reconstruction of runtime slots. Paid items retain their actual
locations and encoded progress for explicit recovery.
Pending reinitialization callbacks check this repair marker after waking and
return without refilling or restarting drying. The fixture injects a commit
failure while a real reinitialization wait is pending and checks that the paid
input stays on its turf with unchanged nutrition and progress.

The prepared fixture now also counts the exact input identity in pinned entries
and its exact direct-parent reference occurrences. It also requires rack-first
export without an active parent to refuse before changing paid input, progress,
nutrition or callback ownership. These additions are native unrun. Another
compile, runtime, control or live save requires a fresh grant.

## Prepared recipe conversion correction

Source review at `b828d4c3bd579af19c605e6d0682d06b247a7318` found that separate reagent caps could remove all nutrition from dried fish, salmon and raw cutlets: these inputs provide protein while their outputs construct nutriment. Both inherit `nutriment_factor = 30` from `/datum/reagent/nutriment`; its ingestion procedure adds that factor times the ingested volume to hunger nutrition. The existing snack `nutriments_value()` sums those factors, including nutritional drink reagents.

The revised drying cap uses that production hunger-value helper and proportionally reduces the output's nutritional reagents only when the constructed output exceeds the paid input's remaining value. It retains relative accumulated decay age. This conserves hunger value, not chemical identity or every nutritional/medical effect, and does not increase an output whose recipe already supplies less nutrition.

At `c006660f2d2acbf760421d9c9a4f61878485f809`, the revised positive fixture passed with BYOND 516.1681, zero errors/warnings and no runtime errors. It covers fish fillets, salmon fillets, squid, raw cutlets and octopus at full, half and zero remaining nutrition, checking expected products, paid-input retirement, retained hunger value and relative decay age. Hunger values remained 30/15/0 for fish, salmon and raw cutlets, 120/60/0 for squid, and 180/90/0 for octopus. The octopus disk-entry restoration check also passed.

The following nutrition omission control failed to compile its generated mutation because an extra comment indentation tab remained before the next statement. The batch stopped; age and conversion controls did not run. The mutation generator was repaired to require and replace complete line boundaries. That first batch took 31.3 seconds, peaked at 217,325,568 bytes owned private memory, stayed above 12,792,057,856 bytes free physical memory, and cleaned its processes/generated outputs without guard errors. Evidence is retained under `.codex-remote-attachments/preservation-c006660f2-positive` and `preservation-c006660f2-nutrition`.

At `22e35b8d7c0dd13652768bdbde2340a809e728e2`, a separately authorized remaining-controls batch passed all three controls. Nutrition omission failed `drying does not replenish consumed nutrition`; age omission failed `drying does not erase accumulated age`; restoring separate reagent caps failed `drying retains available nutrition across reagent conversion`. These were expected assertion failures, each compiled with BYOND 516.1681 at zero errors/warnings and without runtime errors. The production executable statements and fixture are unchanged from the positive `c006660f2` run; the positive was not rerun. Guards totaled 39.1 seconds, peaked at 217,546,752 bytes owned private memory, stayed above 12,494,761,984 bytes free physical memory, and cleaned owned processes/generated outputs without errors. Evidence is retained under `.codex-remote-attachments/preservation-22e35b8d7-{nutrition,age,conversion}`. Full-world saves, actual player ingestion, map access and multi-season availability remain unverified.

## Prepared rack graph acceptance

Compilation CI `38379059217` passed at `8aade36751102073d87fdf35a04f4bd69a74bf48` with BYOND 516.1681 and zero errors/warnings. Extensive suites were skipped. The immutable rack baseline and source manifests remain preserved at `769ae49118953ef2de5cc000528b6699b5705207`.

The memory owner executed the one authorized baseline at that exact head on 2026-10-13, 10:23:20-10:23:33 UTC. BYOND 516.1681 compiled it with zero errors/warnings; it then failed the first export assertion: `RACK_EXPORT runtime_field=slots saved=1` / `FAIL: rack export excludes runtime fields`. There were no DM runtime-error lines. Storage restoration, nutrition, age and conversion assertions were not reached, and controls were not run. The guard took 12.515 seconds including cleanup, peaked at 217,886,720 bytes owned private memory, and stayed above 11,642,798,080 bytes free physical memory. Checked termination succeeded, the owned inventory was empty, no generated files were deferred, and no cleanup error or deadline overrun occurred. The owner's independent exit inventory confirmed removal of all ten generated files and unchanged Gaia identity/files. Evidence remains in `data/startup-diagnostics/rack-save-769ae4911-baseline-native`; this is a failed baseline, not rack acceptance.

The food owner executed one positive candidate at `9e1598263ce31a42c464afa98fc2c7a378bae41c` on 2026-10-13, 10:40:14-10:40:41 UTC. BYOND 516.1681 compiled it with zero errors/warnings and no DM runtime-error lines. The stale-wait and runtime-field exclusion assertions passed, but `native turf graph saves exactly one paid input` failed; storage restoration and later conversion assertions were not reached. The result did not log the actual count. Guard elapsed time was 27.031 seconds, peak owned private memory 218,054,656 bytes, and minimum host free memory 10,239,758,336 bytes. Checked termination, empty owned inventory, generated-file cleanup and unchanged Gaia identity/three hashes/ports were independently confirmed; the slot was released and no controls or repeat ran. Evidence remains in `.codex-remote-attachments/rack-save-9e1598263-positive-native` with its adjacent native preflight/cleanup receipts.

The fixture uses the same `BuildVarDirectory(turf, 1)` entry point as `Save_World`. Source review suggests that a rack's nested `before_save` moves input onto the turf after its parent contents enumeration has started. Manually dropping the input before exporting would hide this production path. The next source-only diagnostic logs paid-input pins, the input's saved reference and its reachability from the owning turf's saved contents, while preserving the failing assertion. This is a suspected traversal defect, pending exact diagnostic evidence and saver-owner review; no shared saver change has been applied.

`rack_save.dm` prepares a 6x3 isolated native disk round trip of the owning turf and production rack with a partial octopus input. It checks `before_save` dropping the input, one saved input in the graph, exclusion of `slots`, `storage` and `current_process_id`, import rejection of an obsolete process field, one newly constructed rack/input, restored nutrition/age/progress, live storage ownership after production callbacks, and one paid conversion. It follows the production loaded-object `after_load`/reagent-owner pass. Native constructor, refill and 150-tick drying waits are unchanged. Normal game startup remains disabled; this is a rack/turf graph check, not complete world or player acceptance.

The candidate adds a parent-preserving `persistence_runtime_var` override for `slots`, `storage` and `current_process_id`. The loader removes constructor-created contents before restoring a contents record, so `after_load` rebuilds the internal wrapper immediately and refill callbacks also ensure it is still owned by the rack. A legacy restored wrapper can be rebound instead of duplicated. Paid inputs are still dropped to the owning turf by `before_save`; the empty runtime wrapper opts out of the contents graph. The fixture now checks parent exclusion delegation, wrapper omission, immediate rebuild, idempotence, legacy wrapper adoption and a single live wrapper. These new checks and the production fix are **native unrun**.

Source review also found that an obsolete drying callback checked its process ID before sleeping, but could mutate current storage once after waking. The candidate checks process identity, turf location and internal storage attachment/owner again before mutation. The fixture schedules a production 150-tick wait with input one increment from completion, replaces the process ID, then verifies that the obsolete callback leaves progress and paid input untouched and creates no product or nutrition change. The rack daemon timeout is 45 seconds to accommodate this additional unchanged wait; the enclosing guard still has the same total 180-second budget. This timing/control behavior is native unrun.

Prepared controls omit the production runtime exclusion, storage rebuild or wake-time ownership guard, insert a duplicate restored paid input, or omit production nutrition conservation. They must reach their specific expected assertion; an earlier failure or compilation error invalidates the control result. Storage omission must fail `restored rack rebuilds runtime storage before refill`; runtime omission must fail `rack export excludes runtime fields`; stale-wait omission must fail `stale drying wait does not advance or consume paid input`. The runner explicitly dispatches all five expected failures. No native repeat or controls are authorized yet.

Generate inspectable source without launching BYOND using `preservation_run.py --probe rack-save --prepare-only --byond-bin <516.1681-bin> --output <unique-directory>`; add `--rack-control runtime`, `storage`, `stale-wait`, `duplicate` or `conversion` for each prepared control. The metadata records exact source/helper SHA-256 hashes and the patch. For a newly authorized Windows candidate lease, use `preservation_guard.py --probe rack-save --byond-bin <516.1681-bin> --directory <unique-directory> --timeout 180`. It retains the 2 GiB owned-job cap and 6 GiB host-free floor. Its total wall budget reserves 12 seconds for cleanup and a final receipt; termination return values are checked and exit inventory has both time and iteration bounds. Evidence stays in the output directory, avoiding a tree copy during cleanup. Only ten known generated files are considered for deletion, with failures or deadline deferrals recorded; file cleanup failures cannot suppress the final receipt attempt. Blocking native/filesystem calls can still overrun the budget, which is reported as failure. Offline injected-effect tests cover successful cleanup, termination failure, surviving descendants, root wait timeout, inventory failure, handle-close failure, locked files and cleanup deadline exhaustion. The native baseline exercised successful cleanup; offline controls do not establish native failure-path behavior. A fresh process/memory preflight and exclusive lease are required for any further native execution. Candidate and all control modes are **unrun**.
