"""Source-derived offline checks for Civ13's read-only current sky and transits."""
from pathlib import Path
import re
import unittest

from test_birth_chart_wheel import SIGN_IDS, angles, aspect, body, formula, house

ROOT = Path(__file__).resolve().parents[2]
PATH = "code/game/mob/living/carbon/human/star_chart.dm"
SKY = (ROOT / PATH).read_text(encoding="utf-8")
CALENDAR = (ROOT / "code/modules/1713/world_calendar.dm").read_text(encoding="utf-8")


def define(name):
    return int(re.search(rf"^#define {name} (\d+)$", SKY, re.M)[1])


def expr(source, target):
    return re.search(rf"^\s*{re.escape(target)} (.+)$", source, re.M)[1]


def moment(utc_day, utc_ticks, longitude):
    raw = body(SKY, "/proc/star_chart_moment(")
    values = {k: define(k) for k in
              ("STAR_CHART_DAY_TICKS", "STAR_CHART_GAME_MINUTE_TICKS")}
    zone_expr = expr(body(CALENDAR, "/proc/world_calendar_zone("), "return")
    # Shared zones round to the nearest hour with half toward +infinity.
    zone = formula(zone_expr.replace("0.5", "1 / 2"), longitude=longitude)
    day = formula(expr(raw, "var/day ="), utc_day=utc_day, utc_ticks=utc_ticks, **values)
    minute = formula(expr(raw, "var/minute ="), utc_ticks=utc_ticks, **values)
    local = formula(expr(raw, "var/local ="), minute=minute, zone=zone)
    return day, minute, day + local // 1440, local % 1440


def live(day, minute, local_minute):
    s = formula(expr(body(SKY, "/proc/star_chart_sun_angle("), "return"), day=day)
    return (s, formula("birth_chart_moon_angle(day, minute)", day=day, minute=minute),
            formula("birth_chart_rising_angle(local_minute)", local_minute=local_minute))


def crossing(label, day, minute, angle):
    # Follow the documented bounded sample seam and the production step expression.
    src = body(SKY, "/proc/star_chart_next_sign(")
    degree = angle % 30
    start = angle // 30
    if label == "Sun":
        return SIGN_IDS[(start + 1) % 12], (30 - degree) * 1440 - minute
    elapsed = 0
    for _ in range(define("STAR_CHART_MOON_SEARCH")):
        step = formula(expr(src, "var/step ="), minute=minute)
        elapsed += step
        minute += step
        if minute >= 1440:
            day += 1
            minute = 0
        new = live(day, minute, 0)[1] // 30
        if new != start:
            return SIGN_IDS[new], elapsed
    return None


class StarChartTests(unittest.TestCase):
    def test_game_midnight_and_region_move_keep_shared_bodies(self):
        west = moment(1, 0, -30)     # Gaia, UTC-2 by the game clock
        east = moment(1, 0, 10)     # Europe, UTC+1 by the game clock
        self.assertEqual(west, (12, 0, 11, 1320))
        self.assertEqual(east, (12, 0, 12, 60))
        self.assertEqual(live(*west[:2], west[3]), (12, 156, 330))
        self.assertEqual(live(*east[:2], east[3]), (12, 156, 15))
        self.assertEqual(moment(1, 863999, 0)[:2], (23, 1439))
        self.assertEqual(moment(2, 0, 0)[:2], (24, 0))

    def test_rotation_and_almanac_at_last_minute_and_lunar_skip(self):
        self.assertEqual(live(359, 1439, 1439)[0], 359)
        self.assertEqual(live(360, 0, 0)[0], 0)
        self.assertEqual(crossing("Sun", 359, 1439, 359), ("ox", 1))
        self.assertEqual(crossing("Moon", 6, 1439, 89), ("heron", 1))
        self.assertEqual(live(7, 0, 0)[1], 91)  # did not pass exactly through 90
        self.assertEqual(crossing("Moon", 276, 1439, 359), ("ox", 1))
        # Check a full cycle of sample dates immediately before a lunar step.
        for day in range(360):
            now = live(day, 119, 0)[1]
            result = crossing("Moon", day, 119, now)
            self.assertIsNotNone(result)
            nxt, wait = result
            before_delta, before_minute = divmod(119 + wait - 1, 1440)
            after_delta, after_minute = divmod(119 + wait, 1440)
            self.assertEqual(live(day + before_delta, before_minute, 0)[1] // 30, now // 30)
            self.assertEqual(SIGN_IDS[live(day + after_delta, after_minute, 0)[1] // 30], nxt)

    def test_transits_use_real_natal_not_observer_or_new_sign(self):
        natal = angles("serpent", 12, 400, -2)
        self.assertEqual(natal, (222, 159, 70))
        present_gaia = live(7, 120, 0)
        present_europe = live(7, 120, 180)
        self.assertNotEqual(present_gaia[0] // 30, natal[0] // 30)
        self.assertEqual(present_gaia[:2], present_europe[:2])
        self.assertEqual(aspect(present_gaia[0], natal[2]), ("Sextile", 3))
        self.assertEqual(house(present_gaia[0], natal[2]), 10)
        transits = body(SKY, "/proc/star_chart_transits(")
        self.assertIn('moving in list("Sun", "Moon")', transits)
        self.assertIn('fixed in list("Sun", "Moon", "Rising")', transits)
        self.assertIn("birth_chart_aspect(transiting, natal[fixed])", transits)

    def test_caller_takes_one_calendar_sample_and_fails_closed(self):
        sampler = body(SKY, "/proc/star_chart_now()")
        self.assertEqual(sampler.count("world_calendar_now()"), 1)
        self.assertLess(sampler.index("!world_calendar_daynight()"), sampler.index("world_calendar_now()"))
        self.assertIn('shard_group.name : map.title', sampler)
        guard = body(SKY, "/proc/star_chart_moment(")
        for requirement in ("!islist(now)", "longitude < -180", "longitude > 180",
                            "!istext(region)", "length(region) > 64", "utc_ticks < 0", "utc_ticks >= 864000"):
            self.assertIn(requirement, guard)
        self.assertNotRegex(SKY, r"\b(world\.realtime|world\.time|TOD_ticks|world_calendar_season)\b")

    def test_current_chart_is_self_only_read_only_and_safe_text(self):
        reader = body(SKY, "/mob/living/human/verb/view_star_chart()")
        for requirement in ("usr != src", "!client", "client.mob != src", "stat == DEAD"):
            self.assertIn(requirement, reader.split("var/list/moment", 1)[0])
        self.assertIn('star_chart_html(moment, birth_chart, birth_chart_record)', reader)
        self.assertIn('new(src, "current_star_chart"', reader)
        self.assertLess(reader.index("if (!moment)"), reader.index("new(src,"))
        self.assertEqual(reader.count("star_chart_now()"), 1)
        self.assertIn('birth_chart_angles(natal_sign, record)', SKY)
        self.assertIn('html_encode(moment["region"])', SKY)
        self.assertIn("No exact natal placements were recorded.", SKY)
        for forbidden in ("href=", "Topic(", "<script", "world <<", "apply_birth_chart(",
                          "birth_chart_record =", "setStat(", ".ckey", ".address", ".computer_id"):
            self.assertNotIn(forbidden, SKY)
        self.assertIn('#include "' + PATH.replace("/", "\\") + '"',
                      (ROOT / "civ13.dme").read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
