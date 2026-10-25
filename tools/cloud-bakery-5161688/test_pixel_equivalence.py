import random
import unittest
import capture
import pixel_reference_testonly as reference

def outcome(function, rgb, width, height):
    try:return 'accepted',function(rgb,width,height)
    except capture.PixelHeuristicFailure as error:return 'rejected',error.facts
    except capture.CaptureError as error:return 'invalid',str(error)

class PixelEquivalence(unittest.TestCase):
    def compare(self,rgb,w,h):
        self.assertEqual(outcome(reference.pixel_diagnostics,rgb,w,h),outcome(capture.pixel_diagnostics,rgb,w,h))

    def test_black_flat_and_channel_edges(self):
        for color in ((0,0,0),(255,255,255),(24,24,24),(25,25,25),(231,231,231),(232,232,232),(0,255,0),(1,0,0)):
            for w,h in ((1,1),(16,16),(480,480)):
                self.compare(bytes(color)*(w*h),w,h)

    def test_distinct_quantized_and_channel_range_edges(self):
        for count in (7,8,15,16,255,256,257):
            palette=[bytes((i%256,i//256,(i*31)%256)) for i in range(count)]
            self.compare(b''.join(palette[i%count] for i in range(4096)),64,64)
        for bins in (7,8,9):
            palette=[bytes((i*16, i*16+1, i*16+2)) for i in range(bins)]
            self.compare(b''.join(palette[i%bins] for i in range(4096)),64,64)
        for highest in (31,32,33):
            self.compare(bytes((0,highest,highest))*2048+bytes((highest,0,0))*2048,64,64)

    def test_dominance_and_middle_fraction_edges(self):
        rng=random.Random(781)
        for count in (15,16,17,39,40,41,81,82,83):
            colors=[bytes((rng.randrange(25,232),rng.randrange(256),rng.randrange(256))) for _ in range(count)]
            rgb=b''.join(colors)+bytes(3*(4096-count))
            self.compare(rgb,64,64)

    def test_transition_and_row_boundary_edges(self):
        for transitions in (7,8,9,19,20,21):
            palette=[bytes((i*13%256,i*29%256,i*43%256)) for i in range(transitions+1)]
            self.compare(b''.join(palette[min(i//(4096//(transitions+1)),transitions)] for i in range(4096)),64,64)
        self.compare((bytes((1,15,16))*31+bytes((16,15,1)))*32,32,32)

    def test_seeded_random_full_frames_and_low_color_adversaries(self):
        rng=random.Random(1688)
        for i in range(36):
            w,h=(480,480) if i<4 else (rng.randrange(1,100),rng.randrange(1,100))
            if i%2:
                palette=[rng.randbytes(3) for _ in range(rng.randrange(1,260))]
                rgb=b''.join(rng.choice(palette) for _ in range(w*h))
            else:rgb=rng.randbytes(w*h*3)
            self.compare(rgb,w,h)

    def test_max_dimensions_and_invalid_input_match(self):
        self.compare(bytes((0,0,0))*(1024*1024),1024,1024)
        for rgb,w,h in ((b'',1,1),(b'1234',1,1),(bytearray(b'123'),1,1),(b'123',0,1),(b'123',1025,1)):
            self.compare(rgb,w,h)

if __name__=='__main__':unittest.main()
