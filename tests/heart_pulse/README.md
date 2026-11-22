# Heart pulse probe

Native probe for #6228 and #6229, run on Linux with the pinned compiler:

    python3 tests/ecology_spawning/run_linux.py . tests/heart_pulse/probe.dm

- A heart-stopping drug with no pulse-adjusting drug leaves no pulse; a
  pulse-adjusting drug can still restart it.
- Losing half the blood (a percentage, not raw units) gives a thready pulse
  unless a pulse-adjusting drug moves it.
- Healthy pulses and stimulants behave as before.

The stopped-heart and thready checks fail on the unfixed source.
`test_sources.py` is the offline contract for the same rules.
