# Anvil skill refusal feedback

Run `py -3 -B -m unittest discover -s tests/anvil_feedback -p "test_*.py" -v`.

The anvil samples the acting human's existing getStatCoeff("crafting") once for
the initial eligibility comparison and refusal message. The gate remains <1.7;
no trait/mood calculation, job/map exception, species restriction, resource path
or wrench behavior changes. Job refusal now identifies the separate job/map
restriction rather than claiming the Crafting skill is insufficient.

The refusal names required effective Crafting 1.70x, current effective coefficient,
and the existing IC > Skill Progress verb. That menu displays trained/current
raw progress; the message explains mood/trait effects on the effective value.
Nine significant digits are requested from num2text so a failing float adjacent
to 1.7 does not display 1.7/1.70. The official DM reference documents single-precision
32-bit numbers and num2text's significant-digit parameter:
https://www.byond.com/docs/ref/info.html
No threshold rounding, clamping or comparison change is introduced.

Tests execute every statement of the selected production skill/job admission
prefix through the existing unchanged source projector, with lexical conversion
of the one numeric message interpolation. The old prefix is frozen from master
e6de92f424d2655e5dbd202a0667814151ebe190, not fetched from Git history during tests.
The prefix excludes initial wrench effects and subsequent species/material/action
branches; wiring checks verify the wrench ordering and species guard remains.
The complete original/new admission outcomes agree over 390 combinations of five
skill values, thirteen job titles and six map/civilization settings.

Boundary cases use binary32 immediately below/exactly at/immediately above the
unchanged 1.7 literal. A further 32 adjacent failing floats exercise high precision;
a default six-digit example reproduces the misleading 1.7 display. Counterfactual
callbacks prove one coefficient sample is shared by gate and message. Refusal
messages are delivered only to the actor; another synthetic player is untouched.

Engine getStatCoeff, num2text, chat and numeric representation are modeled
boundaries. Formatting uses Python .9g under the documented DM contract; actual
native formatting/chat, full attackby gameplay and client UI are unverified.
No engine/world, live file, configuration, reload, restart or deployment is used.
Source/tests stop at Main review before requested regular-PR publication.
