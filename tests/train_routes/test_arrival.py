"""Arrival source-contract checks; native save/custody execution remains separate."""
from pathlib import Path
import unittest

SOURCE = (Path(__file__).resolve().parents[2] / 'code/modules/persistence/train_arrival.dm').read_text()


class ArrivalContracts(unittest.TestCase):
    def test_payload_bound_to_journey_digest_station(self):
        for text in ('R.len != 9', 'length(text) > 300000', 'md5(R["payload"]) != R["digest"]',
                     'M["journey"] != R["journey"]', 'M["station"] != R["station"]',
                     'M["party"] != R["party"]'):
            self.assertIn(text, SOURCE)

    def test_rejects_malformed_and_noncontiguous_centres(self):
        for text in ('if(!islist(entry)) return null', 'position.len != 3',
                     'position[1] != last[1] + dx', 'position[3] != last[3]'):
            self.assertIn(text, SOURCE)

    def test_all_widths_reserved_across_all_gates(self):
        self.assertIn('for(var/side = -1, side <= 1, side++)', SOURCE)
        self.assertIn('for(var/obj/structure/region_gate/S in region_gates)', SOURCE)
        self.assertIn('if(footprint[key]) return TRUE', SOURCE)
        self.assertIn('if(ignored) return TRUE', SOURCE)

    def test_revalidates_exact_strip_not_alternative(self):
        clear = SOURCE.split('/proc/train_arrival_clear(list/R)')[1].split('/obj/structure/region_gate/proc/train_arrival_after_load')[0]
        self.assertIn('train_route_revision(S) != R["revision"]', clear)
        self.assertIn('locate(P[1], P[2], P[3])', clear)
        self.assertIn('!train_route_straight_rail(T, R["heading"])', clear)
        self.assertIn('isliving(A)', clear)
        self.assertNotIn('train_route_arrival_centres', clear)

    def test_saved_barrier_matches_exact_record(self):
        self.assertIn('require_saved && train_arrival_durable[journey] != text', SOURCE)
        self.assertIn('train_arrival_durable -= M["journey"]', SOURCE)
        self.assertIn('train_arrival_durable[R["journey"]] = text', SOURCE)
        self.assertIn('train_arrival_hold_reason = "A saved arrival reservation is invalid or duplicated."', SOURCE)

    def test_release_matches_both_and_never_deletes_world_objects(self):
        release = SOURCE.split('/proc/train_arrival_release')[1]
        self.assertIn('R["journey"] == journey && R["digest"] == digest', release)
        self.assertIn('persistence_save_active()', release)
        self.assertNotIn('qdel(', SOURCE)

    def test_reserve_checks_overlap_before_mutation(self):
        reserve = SOURCE.split('/proc/train_arrival_reserve')[1].split('/proc/train_arrival_validate')[0]
        self.assertLess(reserve.index('train_arrival_overlap(R)'), reserve.index('train_arrival_records += text'))
        self.assertLess(reserve.index('return train_arrival_validate'), reserve.index('train_arrival_records.len >= TRAIN_ARRIVAL_LIMIT'))
        self.assertIn('M["destination"] != shard_group.region', reserve)
        self.assertIn("!shard_group || !shard_group.enabled", reserve)
        self.assertLess(reserve.index("!shard_group || !shard_group.enabled"), reserve.index("shard_group.region"))


if __name__ == '__main__':
    unittest.main()
