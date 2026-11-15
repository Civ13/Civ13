#!/usr/bin/env python3
"""Unpack the pinned BYOND build on a GitHub-hosted Windows runner.

Downloads the 516.1688 Windows archive pinned by size and SHA-256 in
tests/dreamseeker_smoke/vendor.json, unpacks it, and adds the two x86 Direct3D 9 helper libraries Dream Seeker needs from
Microsoft's Microsoft.DXSDK.D3DX NuGet package. Prints the bin folder.
"""
import hashlib
import json
import pathlib
import sys
import urllib.request
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
D3DX_URL = "https://www.nuget.org/api/v2/package/Microsoft.DXSDK.D3DX/9.29.952.8"
D3DX_SHA256 = None  # printed on the first run; the package is fetched over HTTPS from nuget.org


def main():
    work = pathlib.Path(sys.argv[1]).resolve()
    work.mkdir(parents=True, exist_ok=True)
    # byond.com refuses hosted runners (HTTP 403), so use the mirror archive
    # whose exact bytes tests/dreamseeker_smoke/vendor.json already pins.
    vendor = json.loads((ROOT / "tests" / "dreamseeker_smoke" / "vendor.json").read_text())
    request = urllib.request.Request(vendor["url"], headers={"User-Agent": "los-cost-probe"})
    with urllib.request.urlopen(request, timeout=120) as response:
        data = response.read()
    if len(data) != vendor["bytes"] or hashlib.sha256(data).hexdigest() != vendor["sha256"]:
        raise SystemExit("the BYOND archive does not match the pinned size and SHA-256")
    archive_path = work / "byond.zip"
    archive_path.write_bytes(data)
    with zipfile.ZipFile(archive_path) as archive:
        archive.extractall(work / "byond")
    daemons = [path for path in (work / "byond").rglob("dd.exe")]
    if len(daemons) != 1:
        raise SystemExit("expected exactly one dd.exe in the unpacked installer")
    bin_dir = daemons[0].parent
    package = work / "d3dx.zip"
    request = urllib.request.Request(D3DX_URL, headers={"User-Agent": "los-cost-probe"})
    with urllib.request.urlopen(request, timeout=60) as response:
        package.write_bytes(response.read())
    print("d3dx package sha256", hashlib.sha256(package.read_bytes()).hexdigest(), file=sys.stderr)
    with zipfile.ZipFile(package) as archive:
        for name in archive.namelist():
            lower = name.lower()
            if "/x86/" in lower and "release" in lower and lower.endswith(("d3dx9_43.dll", "d3dcompiler_43.dll")):
                (bin_dir / pathlib.PurePosixPath(name).name).write_bytes(archive.read(name))
                print("added", name, file=sys.stderr)
    print(bin_dir)


if __name__ == "__main__":
    main()
