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

# libtool does not pass -static-libgcc/-static-libstdc++ through to the link,
# so the gcc/stdc++ runtimes stay dynamic, like zlib (libtool refuses static
# archives in shared links); every such DLL is staged below.
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
cp "$dll" "$DEST/$base"

# Stage every DLL the library needs, transitively: a DLL from /mingw64/bin is
# bundled, one Windows itself provides (System32) is not, anything else is an
# error. Following imports only one level missed libgcc_s_seh-1.dll's own
# libwinpthread-1.dll, which then loaded only where some other copy happened
# to be on PATH (MSYS2, Git for Windows) and failed on a clean machine. The
# manifest lists each DLL after its dependencies.
SYSTEM32="$(cygpath -u "${SYSTEMROOT:-C:/Windows}")/System32"
visited=""
visit() {
  case " $visited " in *" $1 "*) return ;; esac
  visited="$visited $1"
  for dep in $(objdump -p "$DEST/$1" | awk '/DLL Name:/{print $3}'); do
    if [ -f "$DEST/$dep" ]; then
      :
    elif [ -f "/mingw64/bin/$dep" ]; then
      cp "/mingw64/bin/$dep" "$DEST/$dep"
    elif [ -f "$SYSTEM32/$dep" ] || case "$dep" in api-ms-*|API-MS-*) true ;; *) false ;; esac; then
      continue
    else
      echo "ERROR: $1 imports $dep, which is neither in /mingw64/bin nor a Windows DLL"
      exit 1
    fi
    visit "$dep"
  done
  echo "$1" >> "$DEST/manifest.txt"
}
visit "$base"
echo "Bundled DLLs, dependencies first:"; sed 's/^/  /' "$DEST/manifest.txt"

cp "$SRC/COPYRIGHT" "$DEST/COPYRIGHT"
cp "$SRC/LICENSE.LGPL" "$DEST/LICENSE.LGPL"
cp "$SRC/LICENSE.CDDL" "$DEST/LICENSE.CDDL"
{
  echo "LibRaw $(sed -n 's/.*LIBRAW_VERSION_STR *"\([^"]*\)".*/\1/p' "$SRC/libraw/libraw_version.h" | head -1) (windows-x64), built from unmodified source with MSYS2 mingw-w64"
  echo "built: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "source: https://www.libraw.org (unmodified)"
  echo "configure: shared-only, mingw zlib (staged), no lcms/jpeg/examples/openmp, mingw gcc/stdc++/winpthread runtimes (staged)"
} > "$DEST/BUILD-INFO.txt"

echo "Staged $(ls "$DEST" | wc -l) files into $DEST"
