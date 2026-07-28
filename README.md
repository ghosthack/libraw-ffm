# libraw-ffm

Panama FFM (jextract) bindings for the **LibRaw** C API with bundled,
from-source **LibRaw** natives. One Maven coordinate, batteries included —
no user-installed LibRaw, no JNI.

Camera RAW (CR2/CR3/NEF/ARW/RAF/ORF/DNG/…) decoding for the JVM, with the
two fast paths that matter for browsing:

- `libraw_unpack_thumb` — the embedded preview (often a full-resolution
  baseline JPEG) extracted nearly free, ready for a shrink-on-load JPEG
  decoder such as [turbojpeg-ffm](https://github.com/ghosthack/turbojpeg-ffm);
- `params.half_size` — 1/2-resolution raw decode when real pixels are needed
  (some phone DNGs carry no preview at all).

```xml
<dependency>
  <groupId>io.github.ghosthack</groupId>
  <artifactId>libraw-ffm</artifactId>
  <version>0.22.2-0.2.1</version>
</dependency>
<dependency>
  <groupId>io.github.ghosthack</groupId>
  <artifactId>libraw-ffm-natives</artifactId>
  <version>0.22.2-0.2.1</version>
  <classifier>macos-arm64</classifier> <!-- or windows-x64 / linux-x64 -->
  <scope>runtime</scope>
</dependency>
```

```java
import io.github.ghosthack.librawffm.libraw.LibRaw;
import io.github.ghosthack.librawffm.libraw.libraw_data_t;

MemorySegment lr = LibRaw.libraw_init(0);
LibRaw.libraw_open_file(lr, cPath);          // or libraw_open_buffer
if (LibRaw.libraw_unpack_thumb(lr) == LibRaw.LIBRAW_SUCCESS()) {
    // imgdata.thumbnail: JPEG bytes for most cameras
}
LibRaw.libraw_unpack(lr);
// set params (half_size via libraw_output_params_t, bps via setters), then
LibRaw.libraw_dcraw_process(lr);
MemorySegment img = LibRaw.libraw_dcraw_make_mem_image(lr, errc);
// ... libraw_dcraw_clear_mem(img); libraw_close(lr);
```

When using the module path, declare `requires libraw.ffm;` and run with
`--enable-native-access=libraw.ffm`. When using the class path, run with
`--enable-native-access=ALL-UNNAMED` (JDK 22+).

## Library resolution

`LibRawLibs.lookup()` resolves, in order:

1. `-Dlibrawffm.libdir=<dir>` / `LIBRAW_FFM_LIBDIR` — bind a host LibRaw
   install instead of the bundled one (smallest footprint);
2. the platform's `libraw-ffm-natives` classifier jar, self-extracted once
   to `~/.cache/libraw-ffm/<version>-<platform>/`;
3. already-loaded libraries (loader/default lookup).

Classifier jars exist for **macos-arm64**, **windows-x64**, and **linux-x64**.

## Scope

The bundled LibRaw is built shared-only with zlib (deflate-compressed DNGs)
and **without** libjpeg, LCMS or RawSpeed. Consequences:

- lossy-JPEG-compressed DNGs are not decodable (`LIBRAW_FILE_UNSUPPORTED`);
  if that class of file matters, a follow-up build can statically absorb
  libjpeg-turbo — classic lossy-JPEG DNGs (DNG 1.4) only; JPEG-XL-compressed
  DNG 1.7 (recent Apple ProRAW) is stubbed in LibRaw 0.22.2 and would need
  the Adobe DNG SDK, which stays out of scope;
- embedded JPEG previews are still *extracted* fine (that's byte copying,
  not decoding) — decode them with your JPEG decoder of choice;
- color management is the caller's job (output is 8/16-bit RGB in the
  requested color space).

## Building

- `build-natives/macos-arm64.sh`, `build-natives/windows-x64.sh` (MSYS2
  MINGW64), and `build-natives/linux-x64.sh` build LibRaw from source
  (autotools) and stage the shared library under
  `natives/src/main/resources/libraw-natives/`.
- `jextract/gen-bindings.sh` regenerates the stubs from the built headers and
  re-points the symbol lookup at the runtime loader.
- Releases publish from a matching non-prerelease GitHub Release; see
  [PUBLISHING.md](PUBLISHING.md).

## Licensing

Binding code is MIT. The natives jars convey LibRaw binaries
(LGPL-2.1 or CDDL-1.0, at your option — see THIRD-PARTY.md and the license
files inside each jar).
