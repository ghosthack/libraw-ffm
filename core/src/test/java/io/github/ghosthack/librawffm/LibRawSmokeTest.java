package io.github.ghosthack.librawffm;

import io.github.ghosthack.librawffm.libraw.LibRaw;
import io.github.ghosthack.librawffm.libraw.libraw_data_t;
import io.github.ghosthack.librawffm.libraw.libraw_processed_image_t;
import org.junit.jupiter.api.Test;

import java.lang.foreign.Arena;
import java.lang.foreign.MemorySegment;
import java.lang.foreign.ValueLayout;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** End-to-end: bundled native loads, and a minimal synthetic DNG decodes. */
class LibRawSmokeTest {

    @Test
    void nativeLoadsAndReportsVersion() {
        assertTrue(LibRaw.libraw_versionNumber() >= (0 << 16 | 22 << 8), "version at least 0.22");
        MemorySegment err = LibRaw.libraw_strerror(LibRaw.LIBRAW_FILE_UNSUPPORTED());
        assertNotEquals(MemorySegment.NULL, err);
        assertTrue(err.reinterpret(256).getString(0).length() > 0, "strerror text");
    }

    @Test
    void rejectsGarbageBuffer() {
        MemorySegment lr = LibRaw.libraw_init(0);
        assertNotEquals(MemorySegment.NULL, lr, "libraw_init");
        try (Arena arena = Arena.ofConfined()) {
            byte[] garbage = new byte[4096];
            for (int i = 0; i < garbage.length; i++) {
                garbage[i] = (byte) (i * 31);
            }
            MemorySegment buf = arena.allocate(garbage.length);
            MemorySegment.copy(garbage, 0, buf, ValueLayout.JAVA_BYTE, 0, garbage.length);
            int rc = LibRaw.libraw_open_buffer(lr, buf, garbage.length);
            assertEquals(LibRaw.LIBRAW_FILE_UNSUPPORTED(), rc, "garbage is rejected, not crashed on");
        } finally {
            LibRaw.libraw_close(lr);
        }
    }

    @Test
    void decodesMinimalSyntheticDng() {
        final int w = 32, h = 32;   // LibRaw rejects raws smaller than 22x22
        byte[] dng = minimalCfaDng(w, h);

        MemorySegment lr = LibRaw.libraw_init(0);
        assertNotEquals(MemorySegment.NULL, lr, "libraw_init");
        try (Arena arena = Arena.ofConfined()) {
            MemorySegment buf = arena.allocate(dng.length);
            MemorySegment.copy(dng, 0, buf, ValueLayout.JAVA_BYTE, 0, dng.length);

            assertEquals(LibRaw.LIBRAW_SUCCESS(), LibRaw.libraw_open_buffer(lr, buf, dng.length), "open");
            assertEquals(w, LibRaw.libraw_get_raw_width(lr), "raw width");
            assertEquals(h, LibRaw.libraw_get_raw_height(lr), "raw height");
            assertEquals(LibRaw.LIBRAW_NO_THUMBNAIL(), LibRaw.libraw_unpack_thumb(lr), "no thumb in fixture");

            assertEquals(LibRaw.LIBRAW_SUCCESS(), LibRaw.libraw_unpack(lr), "unpack");

            // Half-size decode: the params struct is the API for knobs without setters.
            MemorySegment data = lr.reinterpret(libraw_data_t.sizeof());
            libraw_data_t.params(data); // materialize slice path
            var params = libraw_data_t.params(data);
            io.github.ghosthack.librawffm.libraw.libraw_output_params_t.half_size(params, 1);
            LibRaw.libraw_set_output_bps(lr, 8);
            LibRaw.libraw_set_no_auto_bright(lr, 1);

            assertEquals(LibRaw.LIBRAW_SUCCESS(), LibRaw.libraw_dcraw_process(lr), "process");

            MemorySegment errc = arena.allocate(ValueLayout.JAVA_INT);
            MemorySegment img = LibRaw.libraw_dcraw_make_mem_image(lr, errc);
            assertNotEquals(MemorySegment.NULL, img, "make_mem_image");
            try {
                MemorySegment pi = img.reinterpret(libraw_processed_image_t.sizeof());
                assertEquals(LibRaw.LIBRAW_IMAGE_BITMAP(), libraw_processed_image_t.type(pi), "bitmap output");
                assertEquals(w / 2, Short.toUnsignedInt(libraw_processed_image_t.width(pi)), "half width");
                assertEquals(h / 2, Short.toUnsignedInt(libraw_processed_image_t.height(pi)), "half height");
                assertEquals(3, Short.toUnsignedInt(libraw_processed_image_t.colors(pi)), "rgb");
                assertEquals(8, Short.toUnsignedInt(libraw_processed_image_t.bits(pi)), "8-bit");
            } finally {
                LibRaw.libraw_dcraw_clear_mem(img);
            }
        } finally {
            LibRaw.libraw_close(lr);
        }
    }

    /**
     * Minimal little-endian uncompressed CFA (RGGB) DNG: one IFD, 16-bit
     * samples, identity ColorMatrix1 — just enough for LibRaw's DNG parser.
     */
    static byte[] minimalCfaDng(int w, int h) {
        final int entries = 17;
        final int ifdStart = 8;
        final int dataStart = ifdStart + 2 + entries * 12 + 4;
        final int matrixOff = dataStart;            // ColorMatrix1: 9 SRATIONALs, 72 bytes
        final int pixelOff = matrixOff + 72;
        final int pixelBytes = w * h * 2;

        ByteBuffer b = ByteBuffer.allocate(pixelOff + pixelBytes).order(ByteOrder.LITTLE_ENDIAN);
        b.put((byte) 'I').put((byte) 'I').putShort((short) 42).putInt(ifdStart);

        b.putShort((short) entries);
        ifd(b, 254, 4, 1, 0);                        // NewSubfileType: primary image
        ifd(b, 256, 4, 1, w);                        // ImageWidth
        ifd(b, 257, 4, 1, h);                        // ImageLength
        ifd(b, 258, 3, 1, 16);                       // BitsPerSample
        ifd(b, 259, 3, 1, 1);                        // Compression: none
        ifd(b, 262, 3, 1, 32803);                    // Photometric: CFA
        ifd(b, 271, 2, 4, ascii4("Tst"));            // Make (inline)
        ifd(b, 272, 2, 4, ascii4("Tst"));            // Model (inline)
        ifd(b, 273, 4, 1, pixelOff);                 // StripOffsets
        ifd(b, 277, 3, 1, 1);                        // SamplesPerPixel
        ifd(b, 278, 4, 1, h);                        // RowsPerStrip
        ifd(b, 279, 4, 1, pixelBytes);               // StripByteCounts
        ifd(b, 33421, 3, 2, 2 | 2 << 16);            // CFARepeatPatternDim: 2x2 (inline)
        ifd(b, 33422, 1, 4, 0 | 1 << 8 | 1 << 16 | 2 << 24); // CFAPattern: RGGB (inline)
        ifd(b, 50706, 1, 4, 1 | 4 << 8);             // DNGVersion: 1.4.0.0 (inline)
        ifd(b, 50708, 2, 4, ascii4("Tst"));          // UniqueCameraModel (inline)
        ifd(b, 50721, 10, 9, matrixOff);             // ColorMatrix1
        b.putInt(0);                                 // next IFD: none

        for (int i = 0; i < 9; i++) {                // identity XYZ->cam matrix
            b.putInt(i % 4 == 0 ? 1 : 0).putInt(1);
        }

        for (int y = 0; y < h; y++) {                // mid-gray-ish gradient CFA
            for (int x = 0; x < w; x++) {
                b.putShort((short) (8192 + x * 256 + y * 128));
            }
        }
        return b.array();
    }

    private static void ifd(ByteBuffer b, int tag, int type, int count, int value) {
        b.putShort((short) tag).putShort((short) type).putInt(count).putInt(value);
    }

    private static int ascii4(String s3) {
        byte[] a = s3.getBytes(java.nio.charset.StandardCharsets.US_ASCII);
        return a[0] & 0xFF | (a[1] & 0xFF) << 8 | (a[2] & 0xFF) << 16;
    }
}
