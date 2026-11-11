"""Pure bounded rail graph validation. No network endpoint or travel activation.

Snapshots MUST originate from a reconciled live world through an enrolled,
authenticated agent adapter. That adapter verifies group/region identity, binds
a fresh single-use challenge, supplies local monotonic receipt time, and never
restamps cached replies. World capture must be synchronous or reject concurrent
track/station mutation. Process restart discards cached snapshots. Station
anchors represent completed authorized offices/berths, not arbitrary map labels.

Registered crossings are operator-owned, directional, generation-bound records;
reverse travel requires another record. This module cannot infer or register
region adjacency. A graph pass proves cardinal rail connectivity only, not
switch direction, train clearance, account membership, reservations or custody.
Those require authoritative per-hop admission before any departure. Public
shard status is not an authenticated producer. That producer is not implemented.
"""
from collections import deque
from dataclasses import dataclass
import hashlib
import json
import math

MAX_NODES = 50000
MAX_TOTAL_NODES = 200000
MAX_BYTES = 1000000


class Refused(ValueError):
    pass


def require(condition, reason):
    if not condition:
        raise Refused(reason)


def name(value):
    return isinstance(value, str) and 0 < len(value) <= 100


def finite(value):
    return type(value) in (int, float) and math.isfinite(value)


def point(value, dimensions):
    require(isinstance(value, (list, tuple)) and len(value) == 3, 'invalid coordinate')
    require(all(type(v) is int and 1 <= v <= d for v, d in zip(value, dimensions)), 'coordinate out of bounds')
    return tuple(value)


@dataclass(frozen=True)
class Snapshot:
    region: str
    generation: str
    dimensions: tuple
    rails: frozenset
    stations: tuple  # (station ID, party ID, rail anchor)
    revision: str
    received_at: float


@dataclass(frozen=True)
class Crossing:
    identity: str
    source: str
    source_generation: str
    source_edge: tuple
    destination: str
    destination_generation: str
    destination_edge: tuple


def accept_snapshot(text, *, authenticated_region, challenge, received_at):
    """Adapter-only parser; parameters must NOT be sourced from request JSON."""
    require(isinstance(text, str) and len(text.encode()) <= MAX_BYTES, 'snapshot size')
    try:
        data = json.loads(text)
    except (ValueError, RecursionError) as exc:
        raise Refused('invalid JSON') from exc
    require(isinstance(data, dict) and set(data) == {'version', 'region', 'generation', 'challenge', 'dimensions', 'rails', 'stations'}, 'snapshot fields')
    require(type(data['version']) is int and data['version'] == 1, 'version')
    require(name(authenticated_region) and data['region'] == authenticated_region, 'origin mismatch')
    require(name(challenge) and data['challenge'] == challenge, 'challenge mismatch')
    require(name(data['generation']) and finite(received_at), 'generation or receipt time')
    dims = data['dimensions']
    require(isinstance(dims, list) and len(dims) == 3 and all(type(d) is int and 1 <= d <= 65535 for d in dims), 'dimensions')
    raw = data['rails']
    require(isinstance(raw, list) and 0 < len(raw) <= MAX_NODES, 'node limit')
    rails = frozenset(point(p, dims) for p in raw)
    require(len(rails) == len(raw), 'duplicate rail')
    raw = data['stations']
    require(isinstance(raw, list) and len(raw) <= 128, 'station limit')
    stations, ids = [], set()
    for row in raw:
        require(isinstance(row, dict) and set(row) == {'id', 'party', 'rail'}, 'station fields')
        require(name(row['id']) and name(row['party']) and row['id'] not in ids, 'station identity')
        anchor = point(row['rail'], dims)
        require(anchor in rails, 'station lacks rail anchor')
        ids.add(row['id'])
        stations.append((row['id'], row['party'], anchor))
    stations.sort()
    canonical = [authenticated_region, data['generation'], dims, sorted(rails), stations]
    revision = hashlib.sha256(json.dumps(canonical, separators=(',', ':')).encode()).hexdigest()
    return Snapshot(authenticated_region, data['generation'], tuple(dims), rails, tuple(stations), revision, received_at)


def edge(snapshot, coordinate):
    p = point(coordinate, snapshot.dimensions)
    x, y, _ = p
    w, h, _ = snapshot.dimensions
    require(p in snapshot.rails and ((x in (1, w) and 1 < y < h) or (y in (1, h) and 1 < x < w)), 'crossing is not non-corner edge rail')
    return p


def distance(snapshot, start, finish):
    require(start in snapshot.rails and finish in snapshot.rails, 'missing endpoint rail')
    pending, seen = deque([(start, 0)]), {start}
    while pending:
        p, steps = pending.popleft()
        if p == finish:
            return steps
        x, y, z = p
        for q in ((x-1,y,z), (x+1,y,z), (x,y-1,z), (x,y+1,z)):
            if q in snapshot.rails and q not in seen:
                seen.add(q)
                pending.append((q, steps+1))
    raise Refused('disconnected rails in ' + snapshot.region)


def validate(*, source, destination, party, crossing_ids, registry, snapshots, revisions, now, max_age=30):
    """source/destination are (region, station ID); return per-region path lengths.

    No side effects. registry is the trusted operator list, not a player supplied
    set of links. revisions are the exact snapshots selected at planning time.
    """
    require(finite(now) and finite(max_age) and 0 < max_age <= 60, 'freshness policy')
    require(isinstance(source, tuple) and len(source) == 2 and all(name(v) for v in source), 'source')
    require(isinstance(destination, tuple) and len(destination) == 2 and all(name(v) for v in destination), 'destination')
    require(name(party), 'party')
    require(isinstance(crossing_ids, (list, tuple)) and 1 <= len(crossing_ids) <= 15, 'hop limit')
    require(isinstance(registry, (list, tuple)) and len(registry) <= 256, 'registry limit')
    links = {}
    for link in registry:
        require(isinstance(link, Crossing) and name(link.identity) and link.identity not in links, 'duplicate or invalid crossing')
        require(all(name(v) for v in (link.source, link.destination, link.source_generation, link.destination_generation)), 'crossing identity')
        links[link.identity] = link
    route, regions = [], [source[0]]
    for key in crossing_ids:
        require(name(key) and key in links, 'unregistered crossing')
        link = links[key]
        require(link.source == regions[-1] and link.destination not in regions, 'discontinuous or cyclic itinerary')
        route.append(link)
        regions.append(link.destination)
    require(regions[-1] == destination[0], 'wrong destination')
    require(isinstance(revisions, dict) and set(revisions) == set(regions), 'revision set')
    require(isinstance(snapshots, dict), 'snapshot set')
    verified, total = {}, 0
    for region in regions:
        s = snapshots.get(region)
        require(isinstance(s, Snapshot) and s.region == region, 'unavailable topology: ' + region)
        require(0 <= now - s.received_at <= max_age, 'stale topology: ' + region)
        require(s.revision == revisions[region], 'changed topology: ' + region)
        total += len(s.rails)
        require(total <= MAX_TOTAL_NODES, 'total graph budget')
        verified[region] = s
    for link in route:
        a, b = verified[link.source], verified[link.destination]
        require(a.generation == link.source_generation and b.generation == link.destination_generation, 'world generation changed')
        edge(a, link.source_edge)
        edge(b, link.destination_edge)
    def station(endpoint):
        for identity, owner, anchor in verified[endpoint[0]].stations:
            if identity == endpoint[1] and owner == party:
                return anchor
        raise Refused('owned endpoint station missing')
    start, finish = station(source), station(destination)
    result = []
    for i, region in enumerate(regions):
        begin = start if i == 0 else tuple(route[i-1].destination_edge)
        end = finish if i == len(route) else tuple(route[i].source_edge)
        result.append((region, verified[region].revision, distance(verified[region], begin, end)))
    return tuple(result)
