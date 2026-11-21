"""Design data for the draft lands of the rest of the Earth (see generate.py).

The two Americas regions are drawn in tests/americas_maps/continents.py with
longitudes counted west. The lands here lie east of Greenwich, so each one is
written with longitudes counted EAST (west of Greenwich is negative) and
turned into the Americas form by `americas_form` below. Antarctica is drawn
looking down on the pole: a point is (longitude east, latitude) and lands
(90 + latitude) degrees from the centre of the map, Greenwich at the top.

A land whose design names 'metadata' is a playable region (Europe, the
Mediterranean, Africa and the rest;
docs/earth-continents.md); the rest are drafts: no map metadata, no region
id, not in any region group.
"""
import math

from europe import EUROPE
from mediterranean import MEDITERRANEAN
from africa import AFRICA
from asia import ASIA
from oceania import OCEANIA
from antarctica import ANTARCTICA
from greenland import GREENLAND


def _polar(point):
    lon, lat = point
    r = 90.0 + lat
    return (r * math.sin(math.radians(lon)), r * math.cos(math.radians(lon)))


def americas_form(spec):
    """One land in the form tests/americas_maps/build.py reads."""
    polar = spec.get('polar', False)

    def pt(point):
        x, y = _polar(point) if polar else point
        return (-x, y)

    def line(points):
        return [pt(p) for p in points]

    out = dict(spec)
    out['lon'] = (-spec['lon'][0], -spec['lon'][1])
    out['land'] = [line(poly) for poly in spec['land']]
    out['islands'] = [(line(poly), factor) for poly, factor in spec.get('islands', [])]
    for key in ('land_strokes', 'sea_strokes', 'mountains', 'passes'):
        out[key] = [(line(points), width) for points, width in spec.get(key, [])]
    out['massifs'] = [line(poly) for poly in spec.get('massifs', [])]
    out['volcanoes'] = [pt((lon, lat)) + (r,) for lon, lat, r in spec.get('volcanoes', [])]
    out['rivers'] = [(line(points), w0, w1) for points, w0, w1 in spec.get('rivers', [])]
    out['lakes'] = [pt((lon, lat)) + (rx, ry) for lon, lat, rx, ry in spec.get('lakes', [])]
    out['biomes'] = [(kind,) + pt((lon, lat)) + (rx, ry) for kind, lon, lat, rx, ry in spec['biomes']]
    out['starts'] = [pt(p) for p in spec.get('starts', [])]
    out['trails'] = []
    out['metadata'] = spec.get('metadata')  # None on a draft
    return out


DRAFTS = {'europe': EUROPE, 'mediterranean': MEDITERRANEAN, 'africa': AFRICA, 'asia': ASIA, 'oceania': OCEANIA, 'antarctica': ANTARCTICA,
          'greenland': GREENLAND}
MAPS = {name: americas_form(spec) for name, spec in DRAFTS.items()}
# Lands made into regions; the others stay drafts.
PLAYABLE = tuple(sorted(name for name, spec in DRAFTS.items() if spec.get('metadata')))
