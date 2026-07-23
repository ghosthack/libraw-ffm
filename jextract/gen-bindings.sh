#!/bin/sh
# Generate the LibRaw C API FFM stubs from the headers of the from-source build,
# then re-point the generated SYMBOL_LOOKUP at the runtime loader (LibRawLibs).
#
# Run once, on macOS, after build-natives/macos-arm64.sh. The LibRaw C API is
# platform-portable (plain ints, size_t, and fixed-layout structs), so a single
# generation serves every platform.
#
# Prereq: a jextract-22 install; default taken from the sibling ffmpeg-ffm repo.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
JX="${JEXTRACT:-$ROOT/../ffmpeg-ffm/tools/jextract-22/bin/jextract}"
PREFIX="$ROOT/build/prefix-macos-arm64"
OUT="$ROOT/core/src/main/java"
PKG="io.github.ghosthack.librawffm.libraw"
SDK=$(xcrun --show-sdk-path)

[ -x "$JX" ] || { echo "jextract not found at $JX (set JEXTRACT=)"; exit 1; }
[ -d "$PREFIX/include" ] || { echo "run build-natives/macos-arm64.sh first"; exit 1; }

GEN_DIR="$OUT/$(echo "$PKG" | tr . /)"
rm -rf "$GEN_DIR"

# The -l path only seeds the generated SYMBOL_LOOKUP, which is replaced below —
# the loader owns library resolution at runtime.
"$JX" --output "$OUT" -t "$PKG" \
  --header-class-name LibRaw \
  -I "$SDK/usr/include" \
  -I "$PREFIX/include" \
  -l ":$PREFIX/lib/libraw_r.dylib" \
  --include-function libraw_init \
  --include-function libraw_close \
  --include-function libraw_recycle \
  --include-function libraw_open_file \
  --include-function libraw_open_buffer \
  --include-function libraw_unpack \
  --include-function libraw_unpack_thumb \
  --include-function libraw_unpack_thumb_ex \
  --include-function libraw_dcraw_process \
  --include-function libraw_dcraw_make_mem_image \
  --include-function libraw_dcraw_make_mem_thumb \
  --include-function libraw_dcraw_clear_mem \
  --include-function libraw_strerror \
  --include-function libraw_version \
  --include-function libraw_versionNumber \
  --include-function libraw_capabilities \
  --include-function libraw_get_iwidth \
  --include-function libraw_get_iheight \
  --include-function libraw_get_raw_width \
  --include-function libraw_get_raw_height \
  --include-function libraw_get_iparams \
  --include-function libraw_get_imgother \
  --include-function libraw_set_output_bps \
  --include-function libraw_set_output_color \
  --include-function libraw_set_no_auto_bright \
  --include-function libraw_set_gamma \
  --include-function libraw_set_demosaic \
  --include-function libraw_set_output_tif \
  --include-struct ph1_t \
  --include-struct fuji_compressed_params \
  --include-struct fuji_q_table \
  --include-typedef libraw_P1_color_t \
  --include-typedef libraw_afinfo_item_t \
  --include-typedef libraw_area_t \
  --include-typedef libraw_canon_makernotes_t \
  --include-typedef libraw_colordata_t \
  --include-typedef libraw_data_t \
  --include-typedef libraw_decoder_info_t \
  --include-typedef libraw_dng_color_t \
  --include-typedef libraw_dng_levels_t \
  --include-typedef libraw_dng_rawopcode_t \
  --include-typedef libraw_dnglens_t \
  --include-typedef libraw_fuji_info_t \
  --include-typedef libraw_gps_info_t \
  --include-typedef libraw_hasselblad_makernotes_t \
  --include-typedef libraw_image_sizes_t \
  --include-typedef libraw_imgother_t \
  --include-typedef libraw_internal_output_params_t \
  --include-typedef libraw_iparams_t \
  --include-typedef libraw_kodak_makernotes_t \
  --include-typedef libraw_lensinfo_t \
  --include-typedef libraw_makernotes_lens_t \
  --include-typedef libraw_makernotes_t \
  --include-typedef libraw_metadata_common_t \
  --include-typedef libraw_nikon_makernotes_t \
  --include-typedef libraw_nikonlens_t \
  --include-typedef libraw_olympus_makernotes_t \
  --include-typedef libraw_output_params_t \
  --include-typedef libraw_p1_makernotes_t \
  --include-typedef libraw_panasonic_makernotes_t \
  --include-typedef libraw_pentax_makernotes_t \
  --include-typedef libraw_processed_image_t \
  --include-typedef libraw_raw_inset_crop_t \
  --include-typedef libraw_raw_unpack_params_t \
  --include-typedef libraw_rawdata_t \
  --include-typedef libraw_ricoh_makernotes_t \
  --include-typedef libraw_samsung_makernotes_t \
  --include-typedef libraw_sensor_highspeed_crop_t \
  --include-typedef libraw_shootinginfo_t \
  --include-typedef libraw_sony_info_t \
  --include-typedef libraw_thumbnail_t \
  --include-typedef libraw_thumbnail_item_t \
  --include-typedef libraw_thumbnail_list_t \
  --include-constant LIBRAW_SUCCESS \
  --include-constant LIBRAW_UNSPECIFIED_ERROR \
  --include-constant LIBRAW_FILE_UNSUPPORTED \
  --include-constant LIBRAW_REQUEST_FOR_NONEXISTENT_IMAGE \
  --include-constant LIBRAW_OUT_OF_ORDER_CALL \
  --include-constant LIBRAW_NO_THUMBNAIL \
  --include-constant LIBRAW_UNSUPPORTED_THUMBNAIL \
  --include-constant LIBRAW_INPUT_CLOSED \
  --include-constant LIBRAW_NOT_IMPLEMENTED \
  --include-constant LIBRAW_REQUEST_FOR_NONEXISTENT_THUMBNAIL \
  --include-constant LIBRAW_UNSUFFICIENT_MEMORY \
  --include-constant LIBRAW_DATA_ERROR \
  --include-constant LIBRAW_IO_ERROR \
  --include-constant LIBRAW_CANCELLED_BY_CALLBACK \
  --include-constant LIBRAW_BAD_CROP \
  --include-constant LIBRAW_TOO_BIG \
  --include-constant LIBRAW_MEMPOOL_OVERFLOW \
  --include-constant LIBRAW_THUMBNAIL_UNKNOWN \
  --include-constant LIBRAW_THUMBNAIL_JPEG \
  --include-constant LIBRAW_THUMBNAIL_BITMAP \
  --include-constant LIBRAW_THUMBNAIL_BITMAP16 \
  --include-constant LIBRAW_THUMBNAIL_LAYER \
  --include-constant LIBRAW_THUMBNAIL_ROLLEI \
  --include-constant LIBRAW_THUMBNAIL_H265 \
  --include-constant LIBRAW_THUMBNAIL_JPEGXL \
  --include-constant LIBRAW_IMAGE_JPEG \
  --include-constant LIBRAW_IMAGE_BITMAP \
  --include-constant LIBRAW_THUMBNAIL_MAXCOUNT \
  "$ROOT/jextract/libraw_api.h"

# Replace the baked absolute-path lookup chain with the runtime loader.
perl -0777 -pi -e \
  's/static final SymbolLookup SYMBOL_LOOKUP = .*?;/static final SymbolLookup SYMBOL_LOOKUP = io.github.ghosthack.librawffm.LibRawLibs.lookup();/s' \
  "$GEN_DIR/LibRaw.java"

if grep -rn "$PREFIX" "$GEN_DIR" >/dev/null; then
  echo "ERROR: build-prefix paths survived in generated stubs"; exit 1
fi
grep -q "LibRawLibs.lookup()" "$GEN_DIR/LibRaw.java" || { echo "ERROR: lookup patch did not apply"; exit 1; }

echo "Generated $(ls "$GEN_DIR" | wc -l | tr -d ' ') files into $GEN_DIR"
