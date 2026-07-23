#!/bin/sh
# Build LibRaw (shared, thread-safe libraw_r only) for macos-arm64 and stage
# the dylib into natives/src/main/resources/libraw-natives/macos-arm64/.
#
# Usage: build-natives/macos-arm64.sh [path-to-LibRaw-source]   (default build/LibRaw-0.22.2)
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:-$ROOT/build/LibRaw-0.22.2}"
PREFIX="$ROOT/build/prefix-macos-arm64"
DEST="$ROOT/natives/src/main/resources/libraw-natives/macos-arm64"
BUILD="$SRC/build-macos-arm64"

mkdir -p "$BUILD"
cd "$BUILD"

# zlib comes from the macOS SDK (deflate-compressed DNGs); lcms/jpeg/examples
# off — lossy-JPEG-compressed DNGs are out of scope for v1 (see README).
# ZLIB_* passed explicitly so configure does not depend on a zlib.pc.
../configure \
  --prefix="$PREFIX" \
  --enable-shared --disable-static \
  --enable-zlib ZLIB_CFLAGS=" " ZLIB_LIBS="-lz" \
  --disable-lcms --disable-jpeg --disable-examples --disable-openmp
make -j"$(sysctl -n hw.ncpu)"
make install

rm -rf "$DEST"
mkdir -p "$DEST"

# Only the thread-safe variant ships; the plain libraw.dylib is not needed.
dylib="$PREFIX/lib/libraw_r.dylib"
base="$(basename "$(readlink -f "$dylib")")"    # e.g. libraw_r.23.dylib
cp "$(readlink -f "$dylib")" "$DEST/$base"
chmod 644 "$DEST/$base"
install_name_tool -id "@loader_path/$base" "$DEST/$base"
codesign -s - -f "$DEST/$base"
printf '%s\n' "$base" > "$DEST/manifest.txt"

# No import may resolve outside the OS itself (zlib/c++ are system libs).
if otool -L "$DEST/$base" | tail -n +2 | awk '{print $1}' \
    | grep -vE '^(/usr/lib/|/System/|@loader_path/)'; then
  echo "ERROR: $base links non-system libraries (above)"; exit 1
fi

cp "$SRC/COPYRIGHT" "$DEST/COPYRIGHT"
cp "$SRC/LICENSE.LGPL" "$DEST/LICENSE.LGPL"
cp "$SRC/LICENSE.CDDL" "$DEST/LICENSE.CDDL"
{
  echo "LibRaw $(sed -n 's/.*LIBRAW_VERSION_STR *"\([^"]*\)".*/\1/p' "$SRC/libraw/libraw_version.h" | head -1)"
  echo "built: $(date -u +%Y-%m-%dT%H:%M:%SZ) on $(uname -sm)"
  echo "source: https://www.libraw.org (unmodified)"
  echo "configure: shared-only, zlib (system), no lcms/jpeg/examples/openmp"
} > "$DEST/BUILD-INFO.txt"

echo "staged:"
ls -la "$DEST"
