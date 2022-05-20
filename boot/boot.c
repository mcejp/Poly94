#include <stdint.h>

#define TRACE_REG           (*(uint32_t volatile*)0x81000000)
#define BG_COLOR            (*(uint32_t volatile*)0x81000004)

#define message_sdram_x32   ((uint32_t volatile*)0x08000000)
#define message_sdram_x16   ((uint16_t volatile*)0x08000000)
#define sdram_x8            ((uint8_t volatile*)0x08000000)

static const char message[] = "Hello world from SDRAM!\r\n";

#define MSG_LEN (sizeof(message) - 1)

static void Putc(char c) {
    // wait while UART busy
    while (TRACE_REG & 1) {
    }

    TRACE_REG = c;
}

static const char hex[] = "0123456789ABCDEF";

static void Puth(uint32_t value) {
    Putc(hex[value >> 28]);
    Putc(hex[(value >> 24) & 0xf]);
    Putc(hex[(value >> 20) & 0xf]);
    Putc(hex[(value >> 16) & 0xf]);
    Putc(hex[(value >> 12) & 0xf]);
    Putc(hex[(value >> 8) & 0xf]);
    Putc(hex[(value >> 4) & 0xf]);
    Putc(hex[value & 0xf]);
}

static void Puts(const char* str) {
    while (*str) {
        Putc(*str++);
    }
}

void bootldr() {
    // TRACE_REG = 'H';
    // TRACE_REG = 'e';
    // TRACE_REG = 'l';
    // TRACE_REG = 'l';
    // TRACE_REG = 'o';
    // TRACE_REG = '\n';

    for (int i = 0; i < MSG_LEN; i++) {
        sdram_x8[i] = message[i];
    }

    message_sdram_x32[100] = 0x12345678;

    BG_COLOR = 0xffff00;

    for (int i = 0; ; i++) {
        BG_COLOR = (i & 0xff00);

        if ((i % MSG_LEN) == 0) {
            Puth(message_sdram_x32[100]);
            Puts("\n\n");
        }

        Putc(sdram_x8[i % MSG_LEN]);
    }
}
