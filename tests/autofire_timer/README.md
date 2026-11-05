# Autofire on SStimer

`python3 tests/autofire_timer/run.py --byond-bin <BYOND bin>` compiles the
production game with normal startup disabled, starts the MC timer loop the way
`world/New` does, and drives `/datum/autofire` (`code/_onclick/click.dm`) with a
fake client. It checks that:

- an `addtimer` callback fires, a cancelled one does not, and `world.fps` is unchanged;
- the first shot fires on mouse down and a held button fires once per `burst_delay`;
- releasing the button, leaving full auto and dying each end the hold;
- a release and re-press while a click sleeps keeps a single fire chain.

`--negative-control no-timer-loop` skips `Master.start_timer_loop()` and must
fail. That was master before this runner: the MC never started, so no timer
callback ever ran. The run takes about 30 seconds after compilation.
