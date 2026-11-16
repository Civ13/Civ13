# Weighed money

Code: `code/modules/1713/weighed_money.dm`. Tests: `python3 tests/weighed_money/test_source.py`;
native probe `python3 tests/ecology_spawning/run_linux.py . tests/weighed_money/probe.dm`.

Step 2 of the bureaucracy and currency plan. Before anyone strikes coins, metal is money by
weight.

- `/obj/item/weighing_balance`, the **trading balance** (2 wood, economy & production, Basic
  Tools, so from 5000 BC). The art reuses the gem scale (`icons/obj/gem_science.dmi`,
  `gem_scale`).
- Use it on metal sheets or coins (or hold them in the other hand and use it in hand) to weigh
  them. One shekel is the weight of one coin, and a metal sheet weighs 10 shekels.
- Worth is shown in silver, using the scale research benches already use for coins (copper
  0.1, silver 1, gold 4 per shekel). Other metals: lead 0.05, tin and bronze 0.15, brass and
  iron 0.2.
- Using it on a barter mat weighs each trader's offer and counts anything it cannot price.
  This doesn't lay the balance on the mat as an offer.

The balance only measures. Players set their own prices, and nothing here buys, sells or
creates money.
