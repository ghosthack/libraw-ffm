package io.github.ghosthack.librawffm;

import io.github.ghosthack.librawffm.libraw.LibRaw;
import io.github.ghosthack.librawffm.libraw.libraw_data_t;
import io.github.ghosthack.librawffm.libraw.libraw_output_params_t;
import io.github.ghosthack.librawffm.libraw.libraw_processed_image_t;
import io.github.ghosthack.librawffm.libraw.libraw_thumbnail_t;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfSystemProperty;

import java.lang.foreign.Arena;
import java.lang.foreign.MemorySegment;
import java.lang.foreign.ValueLayout;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Opt-in check against a real camera file:
 * {@code mvn test -Dlibraw.test.raw=/path/to/file.dng}
 */
class RealRawFileTest {

    @Test
    @EnabledIfSystemProperty(named = "libraw.test.raw", matches = ".+")
    void decodesRealRaw() {
        String path = System.getProperty("libraw.test.raw");
        MemorySegment lr = LibRaw.libraw_init(0);
        assertNotEquals(MemorySegment.NULL, lr, "libraw_init");
        try (Arena arena = Arena.ofConfined()) {
            MemorySegment cpath = arena.allocateFrom(path);
            assertEquals(LibRaw.LIBRAW_SUCCESS(), LibRaw.libraw_open_file(lr, cpath), "open " + path);

            int rawW = LibRaw.libraw_get_raw_width(lr);
            int rawH = LibRaw.libraw_get_raw_height(lr);
            assertTrue(rawW > 100 && rawH > 100, "plausible raw dims " + rawW + "x" + rawH);

            // Embedded preview, if any: JPEG bytes reachable without a raw decode.
            MemorySegment data = lr.reinterpret(libraw_data_t.sizeof());
            int trc = LibRaw.libraw_unpack_thumb(lr);
            if (trc == LibRaw.LIBRAW_SUCCESS()) {
                MemorySegment thumb = libraw_data_t.thumbnail(data);
                int tformat = libraw_thumbnail_t.tformat(thumb);
                int tlength = libraw_thumbnail_t.tlength(thumb);
                assertTrue(tlength > 0, "thumb has bytes");
                System.out.printf("thumb: format=%d %dx%d %d bytes%n", tformat,
                        Short.toUnsignedInt(libraw_thumbnail_t.twidth(thumb)),
                        Short.toUnsignedInt(libraw_thumbnail_t.theight(thumb)), tlength);
                if (tformat == LibRaw.LIBRAW_THUMBNAIL_JPEG()) {
                    MemorySegment tdata = libraw_thumbnail_t.thumb(thumb).reinterpret(2);
                    assertEquals((byte) 0xFF, tdata.get(ValueLayout.JAVA_BYTE, 0), "JPEG SOI");
                }
            } else {
                System.out.println("no embedded thumb (rc=" + trc + ")");
            }

            // Half-size raw decode to 8-bit RGB.
            assertEquals(LibRaw.LIBRAW_SUCCESS(), LibRaw.libraw_unpack(lr), "unpack");
            libraw_output_params_t.half_size(libraw_data_t.params(data), 1);
            LibRaw.libraw_set_output_bps(lr, 8);
            assertEquals(LibRaw.LIBRAW_SUCCESS(), LibRaw.libraw_dcraw_process(lr), "process");

            MemorySegment errc = arena.allocate(ValueLayout.JAVA_INT);
            MemorySegment img = LibRaw.libraw_dcraw_make_mem_image(lr, errc);
            assertNotEquals(MemorySegment.NULL, img, "make_mem_image errc=" + errc.get(ValueLayout.JAVA_INT, 0));
            try {
                MemorySegment pi = img.reinterpret(libraw_processed_image_t.sizeof());
                int w = Short.toUnsignedInt(libraw_processed_image_t.width(pi));
                int h = Short.toUnsignedInt(libraw_processed_image_t.height(pi));
                System.out.printf("processed: %dx%d colors=%d bits=%d%n", w, h,
                        Short.toUnsignedInt(libraw_processed_image_t.colors(pi)),
                        Short.toUnsignedInt(libraw_processed_image_t.bits(pi)));
                assertTrue(w >= rawW / 2 - 16 && w <= rawW / 2 + 16, "half-size width " + w + " vs raw " + rawW);
            } finally {
                LibRaw.libraw_dcraw_clear_mem(img);
            }
        } finally {
            LibRaw.libraw_close(lr);
        }
    }
}
