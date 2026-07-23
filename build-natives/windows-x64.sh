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

# Static gcc/stdc++ runtimes; zlib links dynamically (libtool refuses static
# archives in shared links) and its DLL is staged below.
../configure \
  --prefix="$PREFIX" \
  --enable-shared --disable-static \
  --enable-zlib ZLIB_CFLAGS=" " ZLIB_LIBS="-lz" \
  --disable-lcms --disable-jpeg --disable-examples --disable-openmp \
  LDFLAGS="-static-libgcc -static-libstdc++"
make -j"$(nproc)"
make install

rm -rf "$DEST"
mkdir -p "$DEST"

dll="$(ls "$PREFIX"/bin/libraw_r-*.dll)"
base="$(basename "$dll")"

: > "$DEST/manifest.txt"
# mingw runtime DLLs first, if the libraw DLL links them.
for runtime in zlib1.dll libwinpthread-1.dll libgcc_s_seh-1.dll libstdc++-6.dll; do
  if [ -f "/mingw64/bin/$runtime" ] \
     && objdump -p "$dll" | grep -q "DLL Name: $runtime"; then
    cp "/mingw64/bin/$runtime" "$DEST/$runtime"
    echo "$runtime" >> "$DEST/manifest.txt"
  fi
done

cp "$dll" "$DEST/$base"
echo "$base" >> "$DEST/manifest.txt"

# No import may resolve outside: staged runtime or Windows itself.
ALLOWED='libraw_r|zlib1|libwinpthread|libgcc_s_seh|libstdc\+\+|KERNEL32|USER32|ADVAPI32|SHELL32|WS2_32|msvcrt|ntdll|api-ms-'
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
  echo "configure: shared-only, mingw zlib (staged), no lcms/jpeg/examples/openmp, static gcc/stdc++ runtimes"
} > "$DEST/BUILD-INFO.txt"

echo "Staged $(ls "$DEST" | wc -l) files into $DEST"
