"""Offline checks of the escrow integration. Exercise the codec in voyage_probe.dm."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
REGION = (ROOT / 'code/modules/persistence/region_travel.dm').read_text()
BRIDGE = (ROOT / 'code/modules/persistence/transfer_bridge.dm').read_text()
VOYAGE = (ROOT / 'code/modules/naval/airship_voyage.dm').read_text()


class VoyageSettlement(unittest.TestCase):
    def test_hosted_probe_is_selected_and_admitted_by_the_native_runner(self):
        probe = 'tests/airship_hull/voyage_probe.dm'
        workflow = (ROOT / '.github/workflows/test.yml').read_text()
        runner = (ROOT / 'tests/resource_extraction/run.ps1').read_text()
        self.assertIn(f'-Probe {probe}', workflow)
        allowlist = runner.split('[ValidateSet(', 1)[1].split(')]', 1)[0]
        self.assertIn(f"'{probe}'", allowlist)

    def test_each_preparation_runs_after_status_requests_but_before_escrow(self):
        party = REGION.split('/obj/structure/region_gate/proc/depart_party(', 1)[1]
        prepare = party.index('departure_prepare_party(ready)')
        self.assertLess(party.index('travel_build_problem(expected)'), prepare)
        self.assertLess(prepare, party.index('region_travel_payload('))
        self.assertLess(party.index('payloads.len != members.len'), party.index('begin_escrow('))

    def test_ship_is_not_removed_until_every_member_is_escrowed(self):
        party = REGION.split('/obj/structure/region_gate/proc/depart_party(', 1)[1]
        self.assertLess(party.index('if(!result)'), party.index('depart_finish(H,'))
        self.assertLess(party.index('depart_finish(H,'), party.index('departure_party_finished()'))
        hook = VOYAGE.split('/obj/structure/region_gate/airship_voyage/departure_party_finished()', 1)[1]
        self.assertIn('airship_voyage_remove(helm, packed)', hook.split('/obj/', 1)[0])

    def test_in_place_travel_never_brings_crew_into_gate(self):
        party = REGION.split('/obj/structure/region_gate/proc/depart_party(', 1)[1]
        self.assertIn('else\n\t\tfor(var/mob/living/human/H in packed)\n\t\t\tH.forceMove(src)', party)
        self.assertIn('/airship_voyage/departure_in_place()\n\treturn TRUE', VOYAGE)
        self.assertIn('/airship_voyage/departure_whole_party()\n\treturn TRUE', VOYAGE)

    def test_mutable_deck_cargo_waits_for_a_durable_source_save(self):
        party = REGION.split('/obj/structure/region_gate/proc/depart_party(', 1)[1]
        self.assertIn('begin_escrow(destination, payloads, departure_fast_escrow())', party)
        self.assertIn('/airship_voyage/departure_fast_escrow()\n\treturn FALSE', VOYAGE)
        self.assertNotIn('airship_voyage_replay_departure', REGION)
        self.assertIn('request_save_soon()', party)

    def test_mixed_build_travel_requires_an_explicit_fresh_capability(self):
        escrow = BRIDGE.split('/datum/transfer_bridge/proc/begin_escrow(', 1)[1]
        self.assertLess(escrow.index('!shard_group.poll_peer(peer)'), escrow.index('begin_effect("/escrow"'))
        self.assertLess(escrow.index('receiver["airship_voyages"] != TRUE'), escrow.index('begin_effect("/escrow"'))


if __name__ == '__main__':
    unittest.main()
