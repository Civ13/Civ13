"""Scene-specific framing check; run only on an already safely admitted capture.

This does not replace pixel diagnostics or any native ownership/capture guard.
A false `accepted` MUST fail acceptance, retaining this bounded diagnostic first.
Malformed input raises ValueError and MUST also fail acceptance. No pixels retained.
"""

WIDTH = HEIGHT = 480
BORDER = 32
STRIP_PIXELS = WIDTH * BORDER
BLACK_THRESHOLD = STRIP_PIXELS * 95 // 100


def viewport_border(rgb, width=WIDTH, height=HEIGHT):
    """Count exact RGB(0,0,0) over every pixel in each four border strips.

    Corner pixels intentionally participate in both intersecting strips. Three
    equally sized channel integers are ORed; each resulting byte is zero iff all
    three original channels are zero. No approximation, sampling or dependencies.
    Fixed 691,200-byte input and bounded intermediates (<4 MiB conservative live
    payload budget, excluding interpreter/input/caller and allocator overhead).
    """
    if type(width) is not int or type(height) is not int or (width, height) != (WIDTH, HEIGHT):
        raise ValueError("viewport_border requires exactly 480x480")
    if type(rgb) is not bytes or len(rgb) != WIDTH * HEIGHT * 3:
        raise ValueError("viewport_border requires exactly 691200 immutable RGB bytes")
    channels = (int.from_bytes(rgb[0::3], 'little') |
                int.from_bytes(rgb[1::3], 'little') |
                int.from_bytes(rgb[2::3], 'little')).to_bytes(WIDTH * HEIGHT, 'little')
    top = channels[:STRIP_PIXELS].count(0)
    bottom = channels[-STRIP_PIXELS:].count(0)
    left = sum(channels[y * WIDTH:y * WIDTH + BORDER].count(0) for y in range(HEIGHT))
    right = sum(channels[(y + 1) * WIDTH - BORDER:(y + 1) * WIDTH].count(0) for y in range(HEIGHT))
    return {
        "schema": 1, "width": WIDTH, "height": HEIGHT, "border_pixels": BORDER,
        "pixels_per_strip": STRIP_PIXELS, "reject_at_black_pixels": BLACK_THRESHOLD,
        "top_black_pixels": top, "bottom_black_pixels": bottom,
        "left_black_pixels": left, "right_black_pixels": right,
        "accepted": max(top, bottom, left, right) < BLACK_THRESHOLD,
    }
