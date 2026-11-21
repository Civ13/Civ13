"""The Mediterranean: the inner sea between Europe and Africa, with its shores.

Drawn from the Europe design (europe.py), whose outlines, ranges, rivers and
climates already cover the inner sea and its southern shore; only the frame,
size, seed and starting places differ. Gibraltar, the Bosporus and the Suez
isthmus all lie inside the map, so the only way in by sea from the ocean is
the west edge, past Gibraltar (docs/world-links.md). Longitudes count east.
"""
from europe import EUROPE

MEDITERRANEAN = dict(EUROPE)
MEDITERRANEAN.update({
    'path': 'maps/nomads/nomads_earth_mediterranean.dmm',
    # A playable region (docs/earth-continents.md).
    'metadata': '/obj/map_metadata/nomads/earth_mediterranean',
    'heights': 'maps/heights/nomads_earth_mediterranean',
    'seed': 1453,
    # About 4.2 km a tile: the straits are a few tiles wide, narrow enough to
    # hold, and the rivers keep Europe's widths in tiles.
    'size': (1280, 396),
    'design_width': 880,
    'lon': (-10.0, 52.0),
    'lat': (46.0, 31.0),
    'ice': (90.0, -90.0),
    'starts': [
        (-4, 40), (-6, 33.5), (3, 36.3), (10, 35.5), (12.5, 42), (22, 39.5), (25, 44.2), (32, 39.5),
        (36, 37.5), (44.5, 33.5), (31, 31.3), (35.5, 33.5), (4.5, 44), (16, 41), (44, 41.5),
    ],
})
