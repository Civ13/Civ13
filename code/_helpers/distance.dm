#define abs_dist(a1, a2) round(sqrt(Square(abs(a1:x - a2:x)) + Square(abs(a1:y - a2:y))))
#define abs_dist_no_rounding(a1, a2) sqrt(Square(abs(a1:x - a2:x)) + Square(abs(a1:y - a2:y)))