"""Fresh executable graph tests, not native or end-to-end transport evidence."""
import json
import unittest
from dataclasses import replace
from tools.transfer_storage.train_topology import accept_snapshot, validate, Crossing, Refused


def packet(region):
    return dict(version=1, region=region, generation='g1', challenge='request-1',
                dimensions=[7,5,2], rails=[[x,3,2] for x in range(1,8)],
                stations=[dict(id='station', party='alice', rail=[2,3,2])])


def parse(data, **kwargs):
    args = dict(authenticated_region=data['region'], challenge='request-1', received_at=100)
    args.update(kwargs)
    return accept_snapshot(json.dumps(data), **args)


class FreshTopology(unittest.TestCase):
    def setUp(self):
        self.snaps = {r: parse(packet(r)) for r in ('a','b','c')}
        self.links = [Crossing('ab','a','g1',(7,3,2),'b','g1',(1,3,2)),
                      Crossing('bc','b','g1',(7,3,2),'c','g1',(1,3,2))]

    def run_route(self, **overrides):
        args = dict(source=('a','station'), destination=('c','station'), party='alice',
                    crossing_ids=['ab','bc'], registry=self.links, snapshots=self.snaps,
                    revisions={r:s.revision for r,s in self.snaps.items()}, now=110)
        args.update(overrides)
        return validate(**args)

    def test_connected_three_regions(self):
        self.assertEqual([row[2] for row in self.run_route()], [5,6,1])

    def test_intermediate_gap(self):
        data=packet('b'); data['rails'].remove([4,3,2]); self.snaps['b']=parse(data)
        with self.assertRaisesRegex(Refused,'disconnected rails in b'): self.run_route()

    def test_replan_on_revision_change(self):
        old={r:s.revision for r,s in self.snaps.items()}
        data=packet('b'); data['rails'].remove([4,3,2]); self.snaps['b']=parse(data)
        with self.assertRaisesRegex(Refused,'changed topology'): self.run_route(revisions=old)

    def test_missing_stale_future_intermediate(self):
        for item in (None,replace(self.snaps['b'],received_at=1),replace(self.snaps['b'],received_at=111)):
            with self.subTest(item=item), self.assertRaises(Refused):
                self.run_route(snapshots={**self.snaps,'b':item})

    def test_link_registry_and_cycles(self):
        for ids in (['unknown'],['bc','ab'],['ab'],['ab']*16):
            with self.subTest(ids=ids),self.assertRaises(Refused): self.run_route(crossing_ids=ids)
        back=Crossing('ba','b','g1',(7,3,2),'a','g1',(1,3,2))
        with self.assertRaisesRegex(Refused,'cyclic'):
            self.run_route(crossing_ids=['ab','ba'],registry=self.links+[back])

    def test_generation_and_owner(self):
        data=packet('b');data['generation']='g2';self.snaps['b']=parse(data)
        with self.assertRaisesRegex(Refused,'generation'):self.run_route()
        self.snaps['b']=parse(packet('b'))
        with self.assertRaisesRegex(Refused,'owned endpoint'):self.run_route(party='bob')

    def test_bad_crossing_positions(self):
        for p in ((4,3,2),(1,1,2),(0,3,2)):
            with self.subTest(p=p),self.assertRaises(Refused):
                self.run_route(registry=[replace(self.links[0],source_edge=p),self.links[1]])

    def test_auth_binding_and_challenge(self):
        for args in (dict(authenticated_region='wrong'),dict(challenge='old')):
            with self.subTest(args=args),self.assertRaises(Refused):parse(packet('a'),**args)

    def test_snapshot_corruption_and_limits(self):
        for key,value in (('version',True),('dimensions',[True,5,2]),('rails',[[1,3,2]]*2),
                          ('rails',[[True,3,2]]),('rails',[[1,3,2]]*50001)):
            data=packet('a');data[key]=value
            with self.subTest(key=key),self.assertRaises(Refused):parse(data)
        with self.assertRaises(Refused):accept_snapshot(' '*1000001,authenticated_region='a',challenge='r',received_at=100)

    def test_canonical_order_and_local_freshness(self):
        data=packet('a');data['rails'].reverse();data['challenge']='request-2'
        self.assertEqual(parse(data,challenge='request-2').revision,self.snaps['a'].revision)
        data['received_at']=10000
        with self.assertRaises(Refused):parse(data)
        with self.assertRaises(Refused):self.run_route(max_age=10000)

    def test_no_cross_level_adjacency(self):
        data=packet('b');data['rails']=[[x,3,2 if x<4 else 1] for x in range(1,8)]
        self.snaps['b']=parse(data)
        links=[self.links[0],replace(self.links[1],source_edge=(7,3,1))]
        with self.assertRaisesRegex(Refused,'disconnected'):self.run_route(registry=links)


if __name__=='__main__':unittest.main()
