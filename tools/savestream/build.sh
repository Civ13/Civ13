#!/bin/bash
# Build the stream save shim (32-bit, loaded by Dream Daemon) and helper (64-bit).
#
#   bash tools/savestream/build.sh linux     # bin/linux/libsavestream.so (i386) + savestream_helper (x86_64)
#   bash tools/savestream/build.sh windows   # bin/windows/savestream.dll (x86) + savestream_helper.exe (x64), mingw-w64
#
# Outputs go to tools/savestream/bin/, which is not committed. Linux needs
# gcc-multilib for -m32; Windows cross builds need mingw-w64.
set -eo pipefail
here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
src="$here/src"
target="${1:-linux}"
out="$here/bin/$target"
mkdir -p "$out"
cflags=(-O2 -Wall -Wextra -std=c99 -D_DEFAULT_SOURCE -D_GNU_SOURCE)
case "$target" in
linux)
	gcc "${cflags[@]}" -m32 -shared -fPIC -fvisibility=hidden -o "$out/libsavestream.so" "$src/savestream_shim.c" -ldl
	gcc "${cflags[@]}" -o "$out/savestream_helper" "$src/savestream_helper.c" -lm
	;;
windows)
	# No link timestamp, so a rebuild of the same source gives the same bytes
	# as the copies shipped at the repository root (see README).
	i686-w64-mingw32-gcc "${cflags[@]}" -shared -static-libgcc -Wl,--no-insert-timestamp -o "$out/savestream.dll" "$src/savestream_shim.c"
	x86_64-w64-mingw32-gcc "${cflags[@]}" -static -Wl,--no-insert-timestamp -o "$out/savestream_helper.exe" "$src/savestream_helper.c" -lpsapi
	;;
*)
	echo "usage: $0 linux|windows" >&2
	exit 2
	;;
esac
ls -l "$out"
