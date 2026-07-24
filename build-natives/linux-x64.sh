#!/bin/sh
# Build LibRaw (shared, thread-safe libraw_r only) for linux-x64 and stage
# the .so into natives/src/main/resources/libraw-natives/linux-x64/.
#
# Run on an x86-64 Linux machine (gcc/g++, make, zlib1g-dev, patchelf):
#   build-natives/linux-x64.sh [path-to-LibRaw-source]   (default build/LibRaw-0.22.2)
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:-$ROOT/build/LibRaw-0.22.2}"
PREFIX="$ROOT/build/prefix-linux-x64"
DEST="$ROOT/natives/src/main/resources/libraw-natives/linux-x64"
BUILD="$SRC/build-linux-x64"

mkdir -p "$BUILD"
cd "$BUILD"

# zlib comes from the distro's zlib1g (deflate-compressed DNGs); lcms/jpeg/
# examples off — lossy-JPEG-compressed DNGs are out of scope for v1 (see
# README). ZLIB_* passed explicitly so configure does not depend on a zlib.pc.
../configure \
  --prefix="$PREFIX" \
  --enable-shared --disable-static \
  --enable-zlib ZLIB_CFLAGS=" " ZLIB_LIBS="-lz" \
  --disable-lcms --disable-jpeg --disable-examples --disable-openmp
make -j"$(nproc)"
make install

rm -rf "$DEST"
mkdir -p "$DEST"

# Only the thread-safe variant ships; staged under its soname.
so="$(readlink -f "$PREFIX/lib/libraw_r.so")"
base="$(patchelf --print-soname "$so")"        # e.g. libraw_r.so.23
cp "$so" "$DEST/$base"
chmod 644 "$DEST/$base"
# $ORIGIN keeps the lib self-contained wherever the loader extracts it.
patchelf --set-rpath '$ORIGIN' "$DEST/$base"
printf '%s\n' "$base" > "$DEST/manifest.txt"

# No import may resolve outside the base system (zlib/libstdc++ ship with
# every distro; zlib1g is Priority: required on Debian/Ubuntu).
if readelf -d "$DEST/$base" | awk '/NEEDED/ {print $NF}' | tr -d '[]' \
    | grep -vE '^(libc|libm|libpthread|libdl|librt|libz|libstdc\+\+|libgcc_s)\.so|^ld-linux'; then
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
