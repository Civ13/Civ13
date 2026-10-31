import hashlib
from pathlib import Path
import tempfile
import threading
import unittest

from bounded_spool import BoundedSpool


class BlockingPath:
    def __init__(self, path, entered, gate):
        self.path, self.entered, self.gate = path, entered, gate
    def open(self, mode):
        self.entered.set()
        if not self.gate.wait(3):
            raise TimeoutError('offline test gate')
        return self.path.open(mode)


class BrokenPath:
    def open(self, mode):
        raise OSError('offline simulated spool failure')


class ShortWritePath:
    def open(self, mode):
        class Stream:
            def __enter__(self): return self
            def __exit__(self, *args): pass
            def write(self, data): return len(data)-1
        return Stream()


class SpoolTests(unittest.TestCase):
    def setUp(self):
        self.data = bytes(range(256))*2700
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.worker = BoundedSpool()

    def tearDown(self):
        self.assertTrue(self.worker.cancel_and_join(timeout=4))
        self.temp.cleanup()

    def test_hash_and_exclusive_persistence(self):
        for i in range(4):
            self.worker.submit(i,self.root/f'{i}.rgb',self.data)
        hashes = self.worker.finish(4,lambda:None,timeout=3)
        self.assertEqual(set(hashes),set(range(4)))
        self.assertEqual(self.worker.stats()['completed'],4)
        self.assertLessEqual(self.worker.stats()['peak_outstanding'],4)
        self.assertEqual(set(self.worker.created_paths()),{self.root/f'{i}.rgb' for i in range(4)})
        for i in range(4):
            self.assertEqual(hashes[i],hashlib.sha256((self.root/f'{i}.rgb').read_bytes()).hexdigest())

    def test_four_outstanding_backpressure_and_no_unsafe_cleanup(self):
        entered,gate = threading.Event(),threading.Event()
        self.worker.submit(0,BlockingPath(self.root/'0.rgb',entered,gate),self.data)
        self.assertTrue(entered.wait(1))
        try:
            for i in range(1,4):self.worker.submit(i,self.root/f'{i}.rgb',self.data)
            with self.assertRaisesRegex(RuntimeError,'backlog exhausted'):
                self.worker.submit(4,self.root/'4.rgb',self.data)
            self.assertFalse(self.worker.cancel_and_join(timeout=.02))
        finally:
            gate.set()

    def test_write_failure_and_short_write_abort(self):
        for path in (BrokenPath(),ShortWritePath()):
            worker=BoundedSpool()
            try:
                try:
                    worker.submit(0,path,self.data)
                except RuntimeError as error:
                    self.assertIn('Raw spool worker failed',str(error))
                worker._thread.join(1)
                with self.assertRaisesRegex(RuntimeError,'Raw spool worker failed'):
                    worker.finish(1,lambda:None,timeout=1)
            finally:
                self.assertTrue(worker.cancel_and_join())

    def test_existing_file_is_not_overwritten(self):
        path=self.root/'existing.rgb'
        path.write_bytes(b'original')
        try:
            self.worker.submit(0,path,self.data)
        except RuntimeError as error:
            self.assertIn('Raw spool worker failed',str(error))
        self.worker._thread.join(1)
        with self.assertRaisesRegex(RuntimeError,'Raw spool worker failed'):
            self.worker.finish(1,lambda:None,timeout=1)
        self.assertEqual(path.read_bytes(),b'original')
        self.assertEqual(self.worker.created_paths(),[])

    def test_nonsequential_item_does_not_corrupt_capacity_accounting(self):
        self.worker.submit(0,self.root/'0.rgb',self.data)
        with self.assertRaisesRegex(RuntimeError,'sequential'):
            self.worker.submit(2,self.root/'2.rgb',self.data)
        self.worker.submit(1,self.root/'1.rgb',self.data)
        self.assertEqual(set(self.worker.finish(2,lambda:None,timeout=2)),{0,1})

    def test_drain_timeout_is_not_success(self):
        entered,gate=threading.Event(),threading.Event()
        self.worker.submit(0,BlockingPath(self.root/'0.rgb',entered,gate),self.data)
        self.assertTrue(entered.wait(1))
        try:
            with self.assertRaisesRegex(RuntimeError,'drain deadline'):
                self.worker.finish(1,lambda:None,timeout=.02)
            self.assertFalse(self.worker.cancel_and_join(timeout=.02))
        finally:
            gate.set()

    def test_incomplete_and_bad_item_rejected(self):
        with self.assertRaisesRegex(RuntimeError,'Invalid raw spool item'):
            self.worker.submit(0,self.root/'bad.rgb',b'short')
        with self.assertRaisesRegex(RuntimeError,'incomplete'):
            self.worker.finish(1,lambda:None,timeout=1)


if __name__=='__main__':
    unittest.main()
