"""Prepare isolated DM sources only; never invoke an engine or a process."""

import argparse
import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent
SOURCE_HEAD = "76406ef6d26e2fd01fa3a3fbf87d4bded0577417"
SOURCE_PATH = "code/game/mob/living/simple_animal/friendly/static.dm"
SOURCE_BLOB = "2a8a7803320d1ba5987bf986e718c6a59bd4303e"
SOURCE_SHA256 = "49688581152ebea1d6f1f316e3b0e51a451b774ebcc643737c2c9288ce26369a"
SIGNATURE = "/obj/structure/fish/attackby(var/obj/item/W as obj, var/mob/living/human/H as mob)"
NEXT_SIGNATURE = "/obj/structure/fish/proc/get_fish()"
ROUTES = (("modern", 120, 40), ("ordinary", 150, 30), ("branch", 120, 20))
VARIANTS = ("candidate", "omit-modern", "omit-ordinary", "omit-branch")
SOURCE_LIMIT = 16384
OUTPUT_LIMIT = 262144
TEMPLATE_HASHES = {'adapters.dm': '9594f3586a5e433e8e0a9962cc852df7e2af6574ac00e3c818ba1fec7d8c08d7', 'fixture.dm': 'c8e6f25c4747c0348e240c7337bda90c9c7596fd5ae13bf2b7c938deb2ced2d2'}


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def labels():
    names = [name for name, _, _ in ROUTES]
    return ([f"pair/{a}/{b}" for a in names for b in names]
            + [f"cancel/{name}" for name in names]
            + [f"miss/{name}" for name in names]
            + [f"species/{name}/{species}" for name in names for species in ("fish", "salmon", "cod")])


def expected_failures(variant):
    if variant not in VARIANTS:
        raise ValueError("unknown variant")
    if variant == "candidate":
        return []
    outer = variant.removeprefix("omit-")
    return [f"pair/{outer}/{inner}" for inner, _, _ in ROUTES]


def extract_attackby(data):
    if len(data) > SOURCE_LIMIT or sha256(data) != SOURCE_SHA256:
        raise ValueError("source does not match reviewed immutable 76406ef6 bytes")
    blob = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
    if blob != SOURCE_BLOB:
        raise ValueError("source Git blob mismatch")
    source = data.decode("utf-8")
    if source.count(SIGNATURE + "\n") != 1 or source.count(NEXT_SIGNATURE + "\n") != 1:
        raise ValueError("procedure boundaries are not unique")
    start = source.index(SIGNATURE + "\n")
    end = source.index(NEXT_SIGNATURE + "\n", start)
    body = source[start:end]
    if body.count("if (do_after(") != 3 or body.count("counter = (counter-1)") != 3:
        raise ValueError("unexpected production procedure shape")
    return body.encode()


def mutate(body, variant):
    if variant not in VARIANTS:
        raise ValueError("unknown variant")
    if variant == "candidate":
        return body
    route = variant.removeprefix("omit-")
    _, delay, chance = next(row for row in ROUTES if row[0] == route)
    before = (f"\t\t\tif (do_after(H, {delay}, src))\n"
              "\t\t\t\tif (counter <= 0)\n\t\t\t\t\treturn\n"
              f"\t\t\t\tif (prob({chance}))").encode()
    after = (f"\t\t\tif (do_after(H, {delay}, src))\n"
             f"\t\t\t\tif (prob({chance}))").encode()
    if body.count(before) != 1:
        raise ValueError("control must remove exactly one selected guard")
    return body.replace(before, after, 1)


def prepare(source, output, expected_byond_version=None, source_head=SOURCE_HEAD):
    if len(source_head) != 40 or any(c not in "0123456789abcdef" for c in source_head):
        raise ValueError("exact source execution head required")
    if expected_byond_version != "516.1688":
        raise ValueError("explicit reviewed 516.1688 profile required")
    source, output = Path(source), Path(output)
    if output.exists():
        raise ValueError("output must be a fresh directory")
    if source.stat().st_size > SOURCE_LIMIT:
        raise ValueError("source exceeds size bound")
    data = source.read_bytes()
    attackby = extract_attackby(data)
    templates = {}
    if set(TEMPLATE_HASHES) != {"adapters.dm", "fixture.dm"}:
        raise ValueError("reviewed template identities are missing")
    for name, expected_hash in TEMPLATE_HASHES.items():
        content = (ROOT / name).read_bytes()
        if len(content) > SOURCE_LIMIT or sha256(content) != expected_hash:
            raise ValueError("template identity mismatch: " + name)
        templates[name] = content
    manifest = dict(schema_version=1, source_head=source_head, production_origin_head=SOURCE_HEAD, source_path=SOURCE_PATH,
                    source_blob=SOURCE_BLOB, source_sha256=SOURCE_SHA256,
                    extracted_hook_sha256=sha256(attackby),
                    expected_byond_version=expected_byond_version,
                    compile_executed=False, runtime_executed=False,
                    real_do_after=False, real_food_constructors=False,
                    real_refill=False, template_sha256=TEMPLATE_HASHES,
                    case_labels=labels(), variants={})
    files = {}
    for variant in VARIANTS:
        hook = mutate(attackby, variant)
        dme = (f'#define FISHING_SOURCE_HEAD "{source_head}"\n'
               f'#define FISHING_SOURCE_SHA "{SOURCE_SHA256}"\n'
               f'#define FISHING_HOOK_SHA "{sha256(hook)}"\n'
               f'#define FISHING_VARIANT "{variant}"\n'
               '#include "adapters.dm"\n'
               '#define prob(CHANCE) fish_probe_prob(CHANCE)\n'
               '#include "hooks.dm"\n'
               '#undef prob\n'
               '#include "fixture.dm"\n').encode()
        target = {"probe.dme": dme, "hooks.dm": hook, **templates}
        manifest["variants"][variant] = dict(
            hook_sha256=sha256(hook), expected_failed_cases=expected_failures(variant),
            files={name: dict(bytes=len(value), sha256=sha256(value)) for name, value in target.items()})
        files.update({f"{variant}/{name}": content for name, content in target.items()})
    files["manifest.json"] = (json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode()
    if sum(map(len, files.values())) > OUTPUT_LIMIT:
        raise ValueError("prepared output exceeds aggregate size bound")
    output.mkdir(parents=True, exist_ok=False)
    for relative, content in files.items():
        destination = output / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(content)
    return manifest


def verify_receipt(receipt, variant, hook_sha256, source_head=SOURCE_HEAD):
    """Pure verifier for a FUTURE native result; does not launch or certify one."""
    errors = []
    expected = dict(schema_version=1, fixture="fishing-completion-v1",
                    source_head=source_head, source_sha256=SOURCE_SHA256,
                    hook_sha256=hook_sha256, variant=variant,
                    byond_version=516, byond_build=1688, port_closed=1,
                    reopen_refused=1, clients=0, topics=0, cleanup_owned_remaining=0)
    if not isinstance(receipt, dict):
        return ["receipt must be an object"]
    for key, value in expected.items():
        if type(receipt.get(key)) is not type(value) or receipt[key] != value:
            errors.append("invalid " + key)
    initial = receipt.get("initial_port")
    if type(initial) is not int or not 1 <= initial <= 65535:
        errors.append("invalid initial port")
    if receipt.get("errors") != []:
        errors.append("native diagnostic/exception present or missing")
    cases = receipt.get("cases")
    if not isinstance(cases, dict) or set(cases) != set(labels()):
        errors.append("incomplete or unknown case set")
    else:
        failed = expected_failures(variant)
        for label, value in cases.items():
            if type(value) is not int or value != (0 if label in failed else 1):
                errors.append("unexpected case verdict: " + label)
    expected_failed = expected_failures(variant)
    failures = receipt.get("failed_cases")
    if (not isinstance(failures, list) or len(failures) != len(expected_failed)
            or any(not isinstance(value, str) for value in failures)
            or set(failures) != set(expected_failed)):
        errors.append("wrong causal failure set")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prepare-only", action="store_true", required=True)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--expected-byond-version", choices=("516.1688",), required=True)
    args = parser.parse_args()
    manifest = prepare(args.source, args.output, args.expected_byond_version)
    print(json.dumps(dict(prepared=True, variants=list(manifest["variants"]),
                          cases_per_variant=len(labels()), compile_executed=False,
                          runtime_executed=False), sort_keys=True))


if __name__ == "__main__":
    main()
