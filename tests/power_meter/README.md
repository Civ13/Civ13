# Power meter and power units

```
python3 tests/power_meter/run.py --byond-bin <pinned bin> --output <empty directory>
```

Builds the full game source without maps or startup, adds `probe.dm` and runs
it headless on an 8 x 8 world. It checks the player-facing unit text (one PU
shown as one kW, 3600 PU s as one kWh, with W/MW and Wh/MWh scaling), that a
secured meter placed while map autolink is held joins its cable on release,
that samples copy the grid's published supply and demand and keep the last
sixty, that the page shows supply, load and two chart lines (written to
`meter.html` in the output directory for a rendered review), and that
unfastening or destroying the meter stops sampling.

Not covered: a connected client keeping the window open while the process
samples once a second, and closing the window.
