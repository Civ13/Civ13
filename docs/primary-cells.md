# Primary electrochemical cells milestone

Depends on wire-power-accounting (#3031). Capacity is power, never stored energy.

First scope: Baghdad-style jar (speculative gameplay reconstruction, Industrial research 25 in the game's Bronze band) and an iron-copper voltaic-style pile (research 95 in the Napoleonic band). Zinc is not an existing sheet material, so the latter is explicitly a gameplay substitute rather than an accurate replica of Volta's zinc-copper pile.

Both are primary cells, not electrically rechargeable. Empty copper assemblies require a fired clay vase (jar only), iron electrode sheets, and grape juice electrolyte. Replacing electrodes and electrolyte renews their chemical energy. Recipes do not grant energy. Cable access remains at research 105; earlier cells are experimental devices and do not unlock modern consumers or advance cable research.

Use abstract power units (PU), consistent with existing powerneeded/maxpower, and energy in PU seconds. Jar: 1 PU, 600 PU seconds; pile: 5 PU, 3000 PU seconds. Both last ten minutes at rated output. A closed circuit consumes at rated output, including unused output; open circuit preserves remaining chemical energy. One second output is prepaid before publishing capacity, ensuring repeated supply rebuilds cannot create energy. Turning off or disconnecting may waste the already prepaid interval, never refund it. No offline elapsed-time discharge.

Rechargeable lead-acid storage is a follow-up after authoritative demand settlement exists. #3031 fixes instantaneous supply and disconnection; currentflow remains time-gated additive demand, which is unsuitable as a conserved charging budget. Do not silently add recharge using currentflow.

Sources:
- Smithsonian, Volta's continuous-current battery introduced in 1800: https://library.si.edu/exhibition/fantastic-worlds/body-electric
- Science Museum, zinc/copper discs and salt-soaked separators: https://collection.sciencemuseumgroup.org.uk/objects/co7214/voltaic-pile-given-to-faraday-1813-1827-replica-simple-batteries-voltaic-piles
- Royal Swedish Academy of Sciences, primary pile and rechargeable lead-acid, 1859-60: https://www.kva.se/app/uploads/2019/10/scibackkeen19.pdf
- William Hafford's archaeological assessment, reported by HISTORY: https://www.history.com/articles/baghdad-battery

Graphical acceptance requires real screenshots and reproduction steps at the tested head. Timing evidence also requires video. Runtime fixtures establish isolated contracts only. No production deployment or restart is part of this milestone.
