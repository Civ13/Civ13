# Boxing bets probe

Native regression probe for #4241, #4242 and #4243. It exercises the production
processor with a controlled match start, actual scheduled rescans, multiple boxes
and a reversed result with no winning stakes. The world disables normal startup,
network ports and map loading. It does not test connected clients or gameplay.

Run on Linux with the pinned BYOND compiler and daemon:

    python3 tests/ecology_spawning/run_linux.py . tests/boxing_bets/probe.dm

The probe expects no failed checks and no runtime errors. It covers same-colour
rejection, exactly one resumed scan loop, finished-pair exclusion, admission of
a new pair, order-independent pool settlement, multiple winning boxes, preserved
unclaimed payouts and an empty winning pool.
