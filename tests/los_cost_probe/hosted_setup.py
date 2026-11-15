#!/usr/bin/env python3
"""Unpack the pinned BYOND build on a GitHub-hosted Windows runner.

Downloads the installer named in tools/byond/version.json (size and SHA-256
checked by scripts/byond_toolchain.py), unpacks it with 7-Zip without running
it, and adds the two x86 Direct3D 9 helper libraries Dream Seeker needs from
Microsoft's Microsoft.DXSDK.D3DX NuGet package. Prints the bin folder.
"""
import hashlib
import pathlib
import subprocess
import sys
import urllib.request
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
D3DX_URL = "https://www.nuget.org/api/v2/package/Microsoft.DXSDK.D3DX/9.29.952.8"
D3DX_SHA256 = None  # printed on the first run; the package is fetched over HTTPS from nuget.org


def main():
    work = pathlib.Path(sys.argv[1]).resolve()
    work.mkdir(parents=True, exist_ok=True)
    installer = work / "byond.exe"
    subprocess.run([sys.executable, "-B", str(ROOT / "scripts" / "byond_toolchain.py"), "download", "--platform", "windows", "--output", str(installer)], check=True, stdout=subprocess.DEVNULL)
    subprocess.run([r"C:\Program Files\7-Zip\7z.exe", "x", str(installer), f"-o{work / 'byond'}", "-y"], check=True, stdout=subprocess.DEVNULL)
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
