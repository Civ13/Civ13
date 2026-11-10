"""Offline source contracts for physical route wiring, not native acceptance."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
ROUTES = (ROOT / 'code/modules/persistence/train_routes.dm').read_text()


class RouteContracts(unittest.TestCase):
    def test_advertisements_are_bounded_and_revalidated(self):
        self.assertIn('records.len > TRAIN_ROUTE_STATIONS_MAX', ROUTES)
        self.assertIn('seen[id]', ROUTES)
        self.assertIn('S.completed && !S.station_problem()', ROUTES)
        self.assertIn('train_route_station(station_id, party)', ROUTES)

    def test_ids_are_hex_and_preview_is_explicit(self):
        self.assertIn('findtext("0123456789abcdef", copytext(id, i, i + 1))', ROUTES)
        self.assertIn("Physical departures remain unavailable", ROUTES)
        station = (ROOT / "code/modules/persistence/party_train.dm").read_text()
        self.assertIn("boarded;freight;train_station_id", station)

    def test_no_partial_overflow_network(self):
        self.assertIn('if(pending.len > 50000) return null', ROUTES)
        self.assertIn('if(!islist(network)) return null', ROUTES)

    def test_arrival_full_consist_and_deck(self):
        self.assertIn('count > TRAIN_ROUTE_SEGMENTS_MAX', ROUTES)
        self.assertIn('if(!left || !right)', ROUTES)
        self.assertIn('clear && centres.len == count', ROUTES)
        self.assertIn('isliving(A)', ROUTES)
        self.assertIn('istype(A, /obj/structure/train_part)', ROUTES)
        self.assertIn('centres.Insert(1, T)', ROUTES)

    def test_routes_are_hub_only_and_enrolled(self):
        self.assertIn('destination in transfer_bridge.peers', ROUTES)
        self.assertIn('shard_group.kind == "RAILYARD" || peer["kind"] == "RAILYARD"', ROUTES)

    def test_menu_rechecks_after_sleep(self):
        after = ROUTES.split('// Both prompts sleep;')[1]
        for check in ('QDELETED(L)', 'Adjacent(H)', 'party_train_may_board(H, party)',
                      'station_problem()', 'L.automovement', 'L.train_transfer_busy',
                      'L.z != z'):
            self.assertIn(check, after)

    def test_discovery_and_menu_wired(self):
        shard = (ROOT / 'code/modules/persistence/shard_group.dm').read_text()
        menu = (ROOT / 'code/modules/persistence/party_freight.dm').read_text()
        self.assertIn('train_route_advertisements()', shard)
        self.assertIn('train_route_clean_advertisements(reply["train_stations"])', shard)
        self.assertIn('train_route_menu(H)', menu)

    def test_no_destructive_transport_in_routes(self):
        for operation in ('qdel(', 'begin_escrow(', 'send_player_soon('):
            self.assertNotIn(operation, ROUTES)


if __name__ == '__main__':
    unittest.main()
