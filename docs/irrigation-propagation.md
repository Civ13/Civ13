# Irrigation propagation

Cardinally connected irrigation channels share flooding and salt contamination.
Fresh natural water and flooded trenches can fill a neighboring channel. Salt
from any channel or adjacent natural source contaminates the whole connected
network, including channels that were already wet. Keep saltwater away from crop
irrigation: fresh water does not remove existing salt contamination.

Ordinary floors and filled-in channels do not supply water, even if old flooding
flags remain on the floor. Removing a source does not drain water already held by
remaining channels. The existing system models wetness and salinity, not finite
water volume, consumption or drainage. This patch does not add those mechanics.

Propagation uses a local visited set and queue instead of recursively revisiting
channels. Overlay refreshes leave the turf's layer unchanged. There is no new
persistent registry, timer, saved field or global cache.

The isolated production-procedure regression covers fresh and salty networks,
cycles, removal, filled-in flags, disconnected channels and bounded repeated
refreshes. Full-game compilation checks the production types and signatures.
Construction/research access, map reachability, seasonal survival and save/load
acceptance remain separate work. No gameplay capture is claimed for this fixture.
