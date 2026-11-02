"""Exact fixture base and path guard; external review must bind the head tree."""
import subprocess
import time

BASE_COMMIT = "831c0bb8ee6d95cbafa2f78795f5c73eed2dbb3f"
BASE_TREE = "fefc60079240271e244b5f3024c75b0d135a7e06"
PINNED = {
    "code/game/mob/living/simple_animal/subtile_movement.dm": "734c3d4a070f53614e7eeefa284836ac51c6f029",
    "code/game/mob/living/simple_animal/friendly/crab.dm": "4210a620115ca4f405ea9182460fb06a2de223f6",
    "tests/human_subtile/species_fallback_fixture.dm": "73870dce743bbfe88b76e327d3ccc04bcac83727",
    "tests/human_subtile/species_fallback_stage.py": "5c68a606e98b2c4084fdcc62f63e9a23b0fb68bf",
    "tests/human_subtile/species_fallback_contract.py": "a01046f9a7a592c8dedf806fcf064b0fe68252cd",
    "tests/human_subtile/probe.dm": "58afd77c15b3b89a3c924e428068085b04f6614a",
    "civ13.dme": "1ec749aba78bbd2c944da0131540f3eca832a037",
}
ALLOWED_DELTA = frozenset({
    '.github/workflows/wildlife-cardinal-cadence.yml',
    'code/game/mob/living/simple_animal/friendly/crab.dm',
    'code/game/mob/living/simple_animal/subtile_movement.dm',
    'scripts/ci_baseline.py',
    'tests/human_subtile/SPECIES-FALLBACK.md',
    'tests/human_subtile/cloud_npc_controller.py',
    'tests/human_subtile/cloud_npc_job.py',
    'tests/human_subtile/cloud_npc_smoke.py',
    'tests/human_subtile/species_fallback_binding.py',
    'tests/human_subtile/species_fallback_contract.py',
    'tests/human_subtile/species_fallback_evidence.py',
    'tests/human_subtile/species_fallback_fixture.dm',
    'tests/human_subtile/species_fallback_stage.py',
    'tests/human_subtile/species_fallback_worker.py',
    'tests/human_subtile/test_npc_pursuit.py',
    'tests/human_subtile/test_npc_species.py',
    'tests/human_subtile/test_npc_wild_walk.py',
    'tests/human_subtile/test_species_fallback_controller.py',
    'tests/human_subtile/test_species_fallback_fixture.py',
    'tests/human_subtile/test_vendor_legacy_integrated.py',
    'tests/test_wildlife_ci_registration.py',
})


def require(value, reason):
    if not value:
        raise ValueError(reason)


def validate_source(git, env, head, deadline=None):
    require(isinstance(head, str) and len(head) == 40 and
            all(c in "0123456789abcdef" for c in head), "invalid source head")
    def limit(seconds):
        if deadline is None:
            return seconds
        remaining = deadline - time.monotonic()
        require(remaining > 0, "source validation deadline")
        return min(seconds, remaining)
    def read(args, timeout=10):
        return subprocess.check_output(git + args, env=env, timeout=limit(timeout)).decode("ascii").strip()
    require(read(["rev-parse", BASE_COMMIT + "^{tree}"]) == BASE_TREE, "base tree")
    result = subprocess.run(git + ["merge-base", "--is-ancestor", BASE_COMMIT, head],
                            env=env, capture_output=True, timeout=limit(10))
    require(result.returncode == 0, "base ancestry")
    raw = subprocess.check_output(git + ["diff", "--no-ext-diff", "--no-renames",
        "--name-only", "-z", BASE_COMMIT, head, "--"], env=env, timeout=limit(30))
    paths = raw.split(b"\0")
    require(paths[-1] == b"" and all(paths[:-1]), "delta encoding")
    names = [p.decode("utf-8") for p in paths[:-1]]
    require(len(names) == len(set(names)) and frozenset(names) == ALLOWED_DELTA,
            "unexpected source delta")
    for path, expected in PINNED.items():
        require(read(["rev-parse", head + ":" + path]) == expected, "changed input: " + path)
    return True