import random
import unittest
from viewport_border import viewport_border, BLACK_THRESHOLD

N = 480 * 480


def oracle(rgb):
    def black(x, y):
        start = (y * 480 + x) * 3
        return rgb[start:start + 3] == b'\0\0\0'
    return dict(top_black_pixels=sum(black(x,y) for y in range(32) for x in range(480)),
                bottom_black_pixels=sum(black(x,y) for y in range(448,480) for x in range(480)),
                left_black_pixels=sum(black(x,y) for y in range(480) for x in range(32)),
                right_black_pixels=sum(black(x,y) for y in range(480) for x in range(448,480)))


class BorderTests(unittest.TestCase):
    def test_all_black(self):
        d = viewport_border(bytes(N * 3))
        self.assertFalse(d['accepted'])
        for key in oracle(bytes(N * 3)):
            self.assertEqual(d[key], 15360)

    def test_schema_bounded(self):
        d = viewport_border(b'\1\2\3' * N)
        self.assertEqual(set(d), {'schema','width','height','border_pixels','pixels_per_strip',
            'reject_at_black_pixels','top_black_pixels','bottom_black_pixels',
            'left_black_pixels','right_black_pixels','accepted'})
        self.assertEqual(d['reject_at_black_pixels'], 14592)
        self.assertTrue(d['accepted'])
        self.assertTrue(all(type(v) is int for k,v in d.items() if k != 'accepted'))

    def test_threshold_each_strip(self):
        strips = {
            'top': [(x,y) for y in range(32) for x in range(480)],
            'bottom': [(x,y) for y in range(448,480) for x in range(480)],
            'left': [(x,y) for y in range(480) for x in range(32)],
            'right': [(x,y) for y in range(480) for x in range(448,480)],
        }
        for name, coords in strips.items():
            for count in (BLACK_THRESHOLD - 1, BLACK_THRESHOLD, BLACK_THRESHOLD + 1):
                with self.subTest(strip=name, count=count):
                    buf = bytearray(b'\1\2\3' * N)
                    for x,y in coords[:count]:
                        i = (y*480+x)*3
                        buf[i:i+3] = b'\0\0\0'
                    d = viewport_border(bytes(buf))
                    self.assertEqual(d[name+'_black_pixels'], count)
                    self.assertEqual(d['accepted'], count < BLACK_THRESHOLD)

    def test_malformed(self):
        for rgb in (None, '', bytearray(N*3), memoryview(bytes(N*3)), bytes(N*3-1), bytes(N*3+1)):
            with self.subTest(kind=type(rgb)), self.assertRaises(ValueError):
                viewport_border(rgb)
        for w,h in ((True,480),(480,False),(480.0,480),(480,'480'),(479,480),(480,481),(0,0)):
            with self.subTest(width=w,height=h), self.assertRaises(ValueError):
                viewport_border(bytes(N*3),w,h)

    def test_nonblack_single_channels_and_unaligned_zeros(self):
        for pixel in (b'\0\0\1',b'\0\1\0',b'\1\0\0',b'\0\0\xff'):
            d = viewport_border(pixel * N)
            self.assertTrue(d['accepted'])
            self.assertEqual(sum(d[k] for k in oracle(pixel * N)), 0)

    def test_diverse_and_random_differential(self):
        rng = random.Random(84923)
        fixtures = [bytes(range(256)) * 2700]
        for _ in range(6):
            fixtures.append(b''.join(rng.choice((b'\0\0\0', b'\1\0\0', b'\0\0\xff', b'\1\2\3')) for _ in range(N)))
        for rgb in fixtures:
            d = viewport_border(rgb)
            expected = oracle(rgb)
            for k,v in expected.items():
                self.assertEqual(d[k], v)
            self.assertEqual(d['accepted'], max(expected.values()) < BLACK_THRESHOLD)

    def test_center_not_border(self):
        buf = bytearray(b'\0\0\1' * N)
        for y in range(32,448):
            buf[(y*480+32)*3:(y*480+448)*3] = bytes(416*3)
        d = viewport_border(bytes(buf))
        self.assertTrue(d['accepted'])
        self.assertEqual(sum(d[k] for k in oracle(bytes(buf))), 0)


if __name__ == '__main__':
    unittest.main()
