# Third-party notices

## LibRaw

The `libraw-ffm-natives` classifier jars contain a shared library built
from **unmodified LibRaw source** (https://www.libraw.org), dual-licensed —
at your option — under (see `COPYRIGHT`, `LICENSE.LGPL` and `LICENSE.CDDL`
inside each jar):

- the **GNU Lesser General Public License v2.1**, or
- the **Common Development and Distribution License (CDDL) 1.0**.

LibRaw incorporates code derived from Dave Coffin's dcraw.c; all of it is
covered by the two licenses above in LibRaw's release tarballs.

The exact version and configure flags ship in each jar's `BUILD-INFO.txt`.
Corresponding source: `https://www.libraw.org/data/LibRaw-<version>.tar.gz`.

The library is dynamically loaded and user-replaceable (an LGPL relinking
requirement satisfied by construction): point `LIBRAW_FFM_LIBDIR` (or
`-Dlibrawffm.libdir`) at any directory containing a compatible LibRaw build
to substitute your own copy.

The macOS build links the operating system's zlib. The Windows build bundles
DLLs from the MSYS2 mingw-w64 distribution beside LibRaw: `zlib1.dll` (zlib
license), the GCC runtimes `libgcc_s_seh-1.dll` and `libstdc++-6.dll` (GPLv3
with the GCC Runtime Library Exception), and `libwinpthread-1.dll`
(MinGW-w64 winpthreads, MIT-style license).
