"""Prove the spelling-only correction preserves the entire blocked address set."""
import ipaddress
import re
import unittest
from pathlib import Path

MAX6=2**128-1
RANGE6='::2-ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff'


def intervals(values):
    result=[]
    for value in values:
        if '-' in value:
            first,last=map(ipaddress.ip_address,value.split('-'))
        else:
            net=ipaddress.ip_network(value,strict=True)
            first,last=net.network_address,net.broadcast_address
        if first.version != last.version or int(first)>int(last): raise ValueError('invalid range')
        result.append((int(first),int(last)))
    return sorted(result)


class FirewallAddressContract(unittest.TestCase):
    def read(self,family):
        source=(Path(__file__).parent/'firewall_supervisor.ps1').read_text(encoding='utf-8')
        line=re.search(r'(?m)^    '+family+r' = @\(([^\n]*)\)$',source)
        self.assertIsNotNone(line)
        return re.findall("'([^']+)'",line.group(1))

    def test_exact_request_matches_retained_windows_readback(self):
        # Observed in run41144686449; validation SHA25640e60fd8f41cb45a921413ff18c092fc2f089c28cea42b8f746789d01a05ecc7.
        self.assertEqual(self.read('v6'),['::',RANGE6])

    def test_full_ipv6_coverage_is_identical_and_excludes_loopback(self):
        old=intervals(['::/128',RANGE6]);new=intervals(self.read('v6'))
        self.assertEqual(old,new)
        self.assertEqual(new,[(0,0),(2,MAX6)])
        self.assertFalse(any(first<=1<=last for first,last in new))

    def test_broader_narrower_or_wrong_single_address_does_not_match(self):
        expected=[(0,0),(2,MAX6)]
        for values in [['::/0'],[RANGE6],['::1',RANGE6],['::','::3-ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff']]:
            with self.subTest(values=values): self.assertNotEqual(intervals(values),expected)

    def test_ipv4_request_is_unchanged(self):
        self.assertEqual(self.read('v4'),['0.0.0.0-126.255.255.255','128.0.0.0-255.255.255.255'])


if __name__=='__main__': unittest.main()
