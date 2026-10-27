"""Offline RGB comparisons only. This cannot authenticate or accept a capture."""
WIDTH = HEIGHT = 480
PIXELS = WIDTH * HEIGHT


def rgb(value):
    if type(value) is not bytes or len(value) != PIXELS * 3:
        raise ValueError('Expected exact immutable 480x480 RGB capture bytes')
    return value


def compare_clear(before, after):
    before, after = rgb(before), rgb(after)
    changed = sum(before[i:i + 3] != after[i:i + 3] for i in range(0, len(before), 3))
    if changed:
        raise ValueError('Clear/ordinary control changed: ' + str(changed))
    return {'pixel_comparison': 'equal', 'native_acceptance': False}


def compare_occluded(before, after, occluded_pixels):
    before, after = rgb(before), rgb(after)
    if (type(occluded_pixels) is not tuple or not occluded_pixels or len(occluded_pixels) >= PIXELS
            or any(type(i) is not int or not 0 <= i < PIXELS for i in occluded_pixels)
            or len(set(occluded_pixels)) != len(occluded_pixels)):
        raise ValueError('Independent nonempty, unique, bounded occluded pixel indices required')
    hidden = set(occluded_pixels)
    reproduced = changed = 0
    for pixel in range(PIXELS):
        index = pixel * 3
        a, b = before[index:index + 3], after[index:index + 3]
        if pixel in hidden:
            reproduced += a != b'\x00\x00\x00'
            if b != b'\x00\x00\x00':
                raise ValueError('Occluded overhang remained nonblack')
        elif a != b:
            raise ValueError('Visible/ordinary/HUD/viewport pixels changed outside the reviewed occlusion mask')
        changed += a != b
    if not reproduced:
        raise ValueError('Baseline did not reproduce an unlit occluded overhang')
    return {'pixel_comparison': 'expected-occlusion-only', 'changed_pixels': changed,
            'baseline_nonblack_occluded_pixels': reproduced, 'native_acceptance': False,
            'review_required': 'Independent oracle ownership, source/run binding, native visibility and real lifecycle'}
