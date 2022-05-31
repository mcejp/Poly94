#include <Poly94_hw.h>

#define sdram_x8            ((uint8_t  volatile*)(SDRAM_START + 0x100))
#define framebuf_sdram_x16  ((uint16_t volatile*)(SDRAM_START + 16 * 1024 * 1024))

int main() {
    for (int y = 0; y < 240; y++) {
        for (int x = 0; x < 320; x++) {
            framebuf_sdram_x16[y * 320 + x] = y * 256 + x;
        }
    }

    VIDEO_CTRL = VIDEO_CTRL_FB_EN;

    // this is necessary to trigger the bug on hardware
    for (;;) {
        for (int y = 0; y < 240; y++) {
            for (int x = 0; x < 320; x++) {
                sdram_x8[y * 320 + x] = y + x;
                TRACE_REG;
            }
        }
    }
}
