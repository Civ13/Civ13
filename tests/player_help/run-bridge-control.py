"""Prove the direct-dispatch regression rejects a missing production limiter."""
from pathlib import Path
import types
import unittest
import test_bridge

source_path = Path(test_bridge.bridge.__file__)
source = source_path.read_text(encoding='utf-8')
guard = 'status, retry = self.limiter.acquire(account)'
if source.count(guard) != 1:
    raise SystemExit('Expected one production dispatch admission boundary')
mutated = types.ModuleType('bridge_control')
mutated.__file__ = str(source_path)
exec(compile(source.replace(guard, 'status, retry = None, 0', 1), str(source_path), 'exec'), mutated.__dict__)
test_bridge.bridge = mutated
case = test_bridge.BridgeTests('test_direct_bridge_repeats_reconnect_and_account_not_in_payload')
result = unittest.TestResult()
case.run(result)
if result.errors or len(result.failures) != 1 or 'rate_limited' not in result.failures[0][1]:
    raise SystemExit('Direct bridge admission omission was not rejected as expected')
print('PASS: direct bridge limiter omission caught at rapid-repeat assertion')
