"""Check notice board paper removal admission, from source, not BYOND."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/objects/structures/noticeboard.dm'
DECL = '/obj/structure/noticeboard/Topic(href, href_list)'

# The pre-fix proc head, frozen as a negative control.
OLD_TOPIC = DECL + '''
	..()
	usr.set_using_object(src)
	if (href_list["remove"])
		if ((usr.stat || usr.restrained()))
			return
		var/obj/item/P = locate(href_list["remove"])
'''


def removal_problems(source):
    start = source.index(DECL)
    body = source[start:source.find('\n/', start + 1)]
    problems = []
    if not body.startswith(DECL + '\n\tif (..())\n\t\treturn'):
        problems.append('ignores the parent Topic denial')
    remove = body.find('if (href_list["remove"])')
    move = body.find('var/obj/item/P = locate(href_list["remove"])')
    branch = body[remove:move]
    if '!isliving(usr)' not in branch or '!usr.Adjacent(src)' not in branch:
        problems.append('removes papers for non-living or distant users')
    return problems


class NoticeboardRemoveTest(unittest.TestCase):
    def test_removal_needs_access_life_and_adjacency(self):
        self.assertEqual(removal_problems(SOURCE.read_text(encoding='utf-8')), [])

    def test_negative_control_old_topic_fails(self):
        self.assertEqual(len(removal_problems(OLD_TOPIC)), 2)


if __name__ == '__main__':
    unittest.main()
