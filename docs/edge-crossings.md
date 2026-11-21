# Walking between connected lands

Where one land mass is split over two regions, players walk off the shared map
edge and come out on the facing edge of the neighbouring region. Nothing stands
on the map: `code/modules/persistence/region_edge.dm` asks the walker once and
sends them as an ordinary region traveller. Mounts, one led animal, a pulled
hand cart, a bicycle and a carriage go with them (see
[americas-regions.md](americas-regions.md)).

## The links

Only land links are walked; seas are crossed by ship or plane
(`continent_layout`, [world-links.md](world-links.md)).

| From | Edge | To | Edge |
| --- | --- | --- | --- |
| northamerica | south (isthmus) | southamerica | north |
| europe | east | asia | west, northern 55% |
| africa | east, northern 32% (Sinai) | asia | west, southern 45% |

Gaia is an island and has no walking link. The Bering Strait is sea, and the
North America map has no land on its west edge, so Asia and North America are
linked by sea and air only.

## Where the links live

The links are in the world links table, `tools/world_links/world_links.json`
([world-links.md](world-links.md)), keyed by region id. The surface level walked
is still the map's `edge_crossing_z` (default 1). A fixture outside the earth
group can set the same shape on its map metadata:

```dm
edge_crossings = list("east" = "asia")                      // the whole edge
edge_crossings = list("west" = list("africa" = list(0, 0.45), "europe" = list(0.45, 1)))
```

A side names one region for the whole edge, or a list of region id =
`list(from, to)`: the stretch of the edge leading there, as fractions of its
length counted west to east or south to north. A walker on dry ground of the
stretch, or wading up to four tiles beside it, is asked. Where they come out is
matched by the share of the stretch's dry tiles they were along, so a walker on
land arrives on land even when the two edges have different coastlines; the
nearest free dry tile three or more tiles in is used.

Every link must be answered on the facing edge of the other map.
`tests/edge_crossings/test_edge_crossings.py` checks that, that both stretches
have dry ground, and that the walked level is the map's surface.

Both regions must be in the same shard group (the earth group's ids:
`europe`, `asia`, `africa`, `northamerica`, `southamerica`). The
far region must be up or asleep, as for any region travel.
