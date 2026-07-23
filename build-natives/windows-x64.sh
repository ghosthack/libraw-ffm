#!/bin/sh
# Build LibRaw (shared, thread-safe libraw_r only) for windows-x64 and stage
# the DLL into natives/src/main/resources/libraw-natives/windows-x64/.
#
# Run from an MSYS2 **MINGW64** shell on the Windows machine:
#   pacman -S --needed mingw-w64-x86_64-toolchain mingw-w64-x86_64-zlib make
#   build-natives/windows-x64.sh [path-to-LibRaw-source]   (default build/LibRaw-0.22.2)
#
# Fetch the source first if needed:
#   mkdir -p build && curl -sfL https://www.libraw.org/data/LibRaw-0.22.2.tar.gz | tar xz -C build
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:-$ROOT/build/LibRaw-0.22.2}"
PREFIX="$ROOT/build/prefix-windows-x64"
DEST="$ROOT/natives/src/main/resources/libraw-natives/windows-x64"
BUILD="$SRC/build-windows-x64"

mkdir -p "$BUILD"
cd "$BUILD"

# Static zlib and static gcc/stdc++ runtimes: the staged set is one DLL.
../configure \
  --prefix="$PREFIX" \
  --enable-shared --disable-static \
  --enable-zlib ZLIB_CFLAGS=" " ZLIB_LIBS="/mingw64/lib/libz.a" \
  --disable-lcms --disable-jpeg --disable-examples --disable-openmp \
  LDFLAGS="-static-libgcc -static-libstdc++"
make -j"$(nproc)"
make install

rm -rf "$DEST"
mkdir -p "$DEST"

dll="$(ls "$PREFIX"/bin/libraw_r-*.dll)"
base="$(basename "$dll")"
cp "$dll" "$DEST/$base"
printf '%s\n' "$base" > "$DEST/manifest.txt"

# No import may resolve outside Windows itself.
ALLOWED='libraw_r|KERNEL32|USER32|ADVAPI32|msvcrt|ntdll|api-ms-'
for f in "$DEST"/*.dll; do
  if objdump -p "$f" | awk '/DLL Name:/{print $3}' | grep -viE "^($ALLOWED)"; then
    echo "ERROR: $f imports from unexpected DLLs (above)"; exit 1
  fi
done

cp "$SRC/COPYRIGHT" "$DEST/COPYRIGHT"
cp "$SRC/LICENSE.LGPL" "$DEST/LICENSE.LGPL"
cp "$SRC/LICENSE.CDDL" "$DEST/LICENSE.CDDL"
{
  echo "LibRaw $(sed -n 's/.*LIBRAW_VERSION_STR *"\([^"]*\)".*/\1/p' "$SRC/libraw/libraw_version.h" | head -1) (windows-x64), built from unmodified source with MSYS2 mingw-w64"
  echo "built: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "source: https://www.libraw.org (unmodified)"
  echo "configure: shared-only, static zlib, no lcms/jpeg/examples/openmp, static gcc/stdc++ runtimes"
} > "$DEST/BUILD-INFO.txt"

echo "Staged $(ls "$DEST" | wc -l) files into $DEST"
