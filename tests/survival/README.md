# Disease and medicine regressions

Run `run.py --byond-bin <516.1681 bin directory>` using a verified Python
interpreter. The runner compiles production sources with normal world startup
disabled, runs bounded assertions in temporary storage, and removes its unique
generated source/build files. No production saves or server restart is used.

The probe tests all four untreated terminal deadlines, appropriate oral
medicine, wrong medicine, interrupted and restarted courses, three oral herbs
with planting stock reserved, minimum herb harvest, renewable acetone and
penicillin recipes, immunity/disconnect/godmode exemptions and transmission.
It preserves disease-before-metabolism ordering from human Life and checks
one oral course through complete human Life. It also runs the real barrel
charcoal handler, grain-started fermentation callback, yeast withdrawal and
timed alcohol distillation. Fermentation waiting is accelerated in the fixture;
normal player research, crafting materials and crop access are source-reviewed.

`--negative-control` removes the herb treatment effect in a generated source
copy and requires the herb-course assertion to fail. CI runs both modes.

`--baseline` executes the historical disease block at commit e4967a4e0 for
twenty plague samples. The initial measurement crossed 100 toxin in 18/20
samples within 180 procedure calls, first crossing at 74 through 176 calls.
This is a damage threshold observation, not a measured full-game death time.
The repaired initialization adapter rerun also crossed in 18/20 samples,
with first crossings at 54 through 171 calls and no runtime diagnostics.

The fixture materializes global-controller variable names before their list
union. The original virtual `vars` list union logs BYOND 516.1681 Bad ref
diagnostics on both historical and patched sources. This adapter retains the
same name keys and subsequent production global initialization. Runtime errors
and engine BUG diagnostics invalidate results. Actor cleanup uses production
qdel; it does not prove that a normal game garbage queue was drained.

Logs and build artifacts remain in the reported temporary directory for
inspection. Tick counts assume the existing nominal one-second mob process;
the fixture calls complete human Life for an oral-course integration check,
but does not execute the complete mob scheduler or graphical client.
