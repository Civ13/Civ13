# CPR cycle credit

`test_credit_order.py` checks that a completed CPR round pauses the revival
clock before the post-wait eligibility recheck, and that an interrupted round
gets no credit (#6383). The native check is in `tests/resuscitation/probe.dm`.
Run with `python3 -B -m unittest tests.cpr_cycle_credit.test_credit_order`.
