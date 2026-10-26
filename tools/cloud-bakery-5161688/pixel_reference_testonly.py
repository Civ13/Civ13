"""Frozen V28 reference for differential offline tests only."""
from collections import Counter
from capture import _rgb_bytes, PixelHeuristicFailure
def pixel_diagnostics(rgb, width, height):
    """Reject blank/nearly blank buffers; return explicitly non-semantic facts."""
    _rgb_bytes(rgb, width, height)
    bins = Counter()
    distinct = set()
    lowest, highest, middle, changes = 255, 0, 0, 0
    previous = None
    nonzero = 0
    for offset in range(0, len(rgb), 3):
        color = rgb[offset:offset + 3]
        red, green, blue = color
        nonzero += int(bool(red or green or blue))
        if len(distinct) < 256:
            distinct.add(color)
        bucket = (red >> 4, green >> 4, blue >> 4)
        bins[bucket] += 1
        lowest = min(lowest, red, green, blue)
        highest = max(highest, red, green, blue)
        if max(color) > 24 and min(color) < 232:
            middle += 1
        if previous is not None and bucket != previous:
            changes += 1
        previous = bucket
    total = width * height
    dominant = max(bins.values()) / total
    facts = dict(pixel_count=total, nonzero_pixel_count=nonzero,
                 channel_min=lowest, channel_max=highest, entirely_black=(nonzero == 0),
                 flat_rgb=(len(distinct) == 1), distinct_rgb_capped_at_256=len(distinct),
                 quantized_color_count=len(bins), channel_range=highest - lowest,
                 middle_pixel_fraction=round(middle / total, 6),
                 dominant_quantized_fraction=round(dominant, 6),
                 adjacent_quantized_changes=changes,
                 semantic_appearance_verified=False)
    if (len(distinct) < 16 or len(bins) < 8 or highest - lowest < 32
            or middle < max(16, total // 100) or dominant > 0.98
            or changes < max(8, total // 200)):
        raise PixelHeuristicFailure(facts)
    return facts

