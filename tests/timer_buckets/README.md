# Timer buckets

```bash
python3 tests/ecology_spawning/run_linux.py . tests/timer_buckets/probe.dm
```

Runs `code/controllers/subsystem/timer.dm` in the shared constructor fixture.
The probe builds timed events by hand and moves `SStimer.head_offset` the way
a bucket lap does, with the float error a long-running world accumulates.

Before the fix, `bucketEject()` recomputed the bucket from `timeToRun` and the
drifted `head_offset`. `floor()` then named the neighbouring bucket, so the
event stayed at the head of the bucket the fire loop was emptying. A looping
timer (the tutorial's 2-second tick) was invoked about 45,000 times a second,
and any other event caught this way wedged the timer subsystem at 91% CPU.
Events now remember the bucket they joined (`bucket_pos`).

The probe checks that an event joins bucket 42 even though the drifted head
recomputes 43, that ejecting the head hands the bucket to the next event and
then empties it, that a re-joined looping event leaves the bucket being
fired, and that a distant event enters and leaves the long-run queue. Four of
the seven checks fail on the old ejection code.

Headless Gaia reproduction (2-second `TIMER_LOOP`, 25 fps): the storm began
at the third bucket lap (about 220 s after start).
