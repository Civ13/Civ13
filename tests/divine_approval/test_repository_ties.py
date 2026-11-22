"""Source guards for ties to targets (repository_ties.dm): by touch, unseen, lasting, and movable only by their maker."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
TIES = (ROOT / 'code/modules/divine/repository_ties.dm').read_text()
REPO = (ROOT / 'code/modules/divine/repository.dm').read_text()


def body(text, path):
    return text.split(path, 1)[1].split('\n/', 1)[0]


class RepositoryTies(unittest.TestCase):
    def test_built(self):
        dme = (ROOT / 'civ13.dme').read_text()
        self.assertIn('#include "code\\modules\\divine\\repository_ties.dm"', dme)

    def test_readied_like_a_throw_and_caught_by_any_touch(self):
        hook = body(REPO, '/proc/magic_touch_hook(')
        self.assertIn('H.magic_tie_mode == "target"', hook)
        self.assertIn('H.magic_tie_target(A)', hook)
        # One touch uses up the readied tie.
        self.assertLess(hook.index('H.magic_tie_ready = FALSE'), hook.index('H.magic_tie_target(A)'))
        ready = body(REPO, '/mob/living/human/proc/magic_ready_tie()')
        self.assertIn('"Tie the next thing I touch to..."', ready)

    def test_target_is_never_told(self):
        tie = body(TIES, '/mob/living/human/proc/magic_tie_target(')
        # Every message goes to the one tying (src), never to the target.
        self.assertNotIn('to_chat(A', tie)
        self.assertNotIn('to_chat(H', tie)
        self.assertIn('H.magic_is_magic_user()', tie)

    def test_tie_needs_a_live_repository_of_the_same_god(self):
        tie = body(TIES, '/mob/living/human/proc/magic_tie_target(')
        self.assertIn('repo.magic_repo_dormant()', tie)
        self.assertIn('repo.magic_repo_deity != divine_book_key(divine_patron)', tie)
        self.assertIn('in magic_registered_repos', tie)

    def test_lasts_until_death_or_destruction(self):
        prune = body(TIES, '/obj/proc/magic_repo_prune_ties()')
        self.assertIn('L.stat == DEAD', prune)
        self.assertIn('persistence_player_restore_ready', prune)
        # No timed expiry.
        self.assertNotIn('world.realtime -', TIES)

    def test_only_the_maker_moves_a_tie_and_the_date_carries(self):
        move = body(TIES, '/mob/living/human/proc/magic_tie_move(')
        self.assertIn('magic_tie_entry(from.magic_repo_targets[key], "by") != me', move)
        self.assertIn('O.magic_repo_deity == from.magic_repo_deity', move)
        self.assertIn('to_repo.magic_repo_targets[key] = from.magic_repo_targets[key]', move)

    def test_keepers_see_all_others_their_own(self):
        review = body(TIES, '/mob/living/human/proc/magic_tie_review(')
        self.assertIn('keeper || magic_tie_entry(entry, "by") == me', review)

    def test_saved_form_is_plain(self):
        self.assertIn('var/magic_tie_id = null', TIES)
        self.assertIn('var/list/magic_repo_targets = null', TIES)
        self.assertIn('var/tmp/magic_tie_mode', TIES)
        self.assertIn('var/tmp/magic_tie_repo', TIES)
        self.assertIn('magic_tie_index[magic_tie_id] = src', body(REPO, '/obj/after_load()'))


if __name__ == '__main__':
    unittest.main()
