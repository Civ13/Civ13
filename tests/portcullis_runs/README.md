# Wide portcullises

`python3 tests/portcullis_runs/run.py --byond-bin <BYOND bin>` compiles the
committed game sources with normal startup disabled and, on a 16x16 world,
checks `code/modules/1713/siege/portcullis_runs.dm` and the winch in
`siege_engines.dm`:

- portcullis sections in a row show west end, middle and east end states,
  sections stacked in a column show north end, middle and south end states,
  and a lone section keeps the single-tile state;
- a winch within reach of one section works every section in its run;
- winding a five-section run takes longer than one section, a free-handed
  helper next to the winch halves it, and dropping stays quick;
- raising and dropping change every section in the run and leave other runs
  alone;
- losing a middle section re-ends the sections on either side;
- no runtime errors.

It needs the pinned compiler (`bash scripts/cloud_byond_setup.sh`).
