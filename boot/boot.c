#include <stdint.h>

#include <Poly94_hw.h>

#define message_sdram_x32   ((uint32_t volatile*)(SDRAM_START + 0x100))
#define message_sdram_x16   ((uint16_t volatile*)(SDRAM_START + 0x100))
#define sdram_x8            ((uint8_t  volatile*)(SDRAM_START + 0x100))

#define framebuf_sdram_x16  ((uint16_t volatile*)(SDRAM_START + 16 * 1024 * 1024))

struct Load_Info {
    uint32_t* source_begin;
    uint32_t* dest_begin;
    uint32_t* dest_end;
};

extern struct Load_Info __text_in_sdram_regions_array_start;

static const char message[] = "Hello world from SDRAM!\r\n";

#define MSG_LEN (sizeof(message) - 1)

static int Getc(void) {
    while (!(TRACE_REG & UART_RX_NOT_EMPTY)) {
    }

    return UART_DATA;
}

static void Putc(char c) {
    // wait while UART busy
    while (TRACE_REG & UART_TX_BUSY) {
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

// This function ends up in SDRAM to test that we can execution code there
// Must NOT be static, otherwise ends up helpfully inlined
__attribute__((section(".text_sdram")))
void Puts(const char* str) {
    while (*str) {
        Putc(*str++);
    }
}

static uint32_t rdcyclel() {
    uint32_t val;
    __asm__ volatile ("rdcycle %0" : "=r" (val));
    return val;
}

void UART_Echo(void) {
    Puts("\n> ");

    for (;;) {
        int data_in = Getc();

        if (data_in == 0x04) {
            // Ctrl-D
            Putc('\n');
            return;
        }
        else if (data_in == '\n') {
            Puts("\n> ");
        }
        else {
            Putc(data_in);
        }
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

    // Copy functions marked .text_sdram to SDRAM
    for (int i = 0; i < __text_in_sdram_regions_array_start.dest_end - __text_in_sdram_regions_array_start.dest_begin; i++) {
        __text_in_sdram_regions_array_start.dest_begin[i] = __text_in_sdram_regions_array_start.source_begin[i];
    }

    message_sdram_x32[100] = 0x12345678;

    BG_COLOR = 0xffff00;

    for (int y = 0; y < 480; y++) {
        for (int x = 0; x < 640; x++) {
            framebuf_sdram_x16[y * 640 + x] = y + x;
        }
    }

    VIDEO_CTRL = VIDEO_CTRL_FB_EN;      // bug: enabling fb_en in the middle of the frame leaves it with wrong SDRAM read ptr

    for (int i = 0; i < 100; i++) { BG_COLOR = i; }

    for (;;) {
        Puth(message_sdram_x32[100]);
        Puts("\n\n");

        for (int i = 0; i < MSG_LEN; i++) {
            BG_COLOR = (i & 0xff00);

            Putc(sdram_x8[i % MSG_LEN]);
        }

        Puth(rdcyclel());
        Puts(" cycles\n");

        break;
    }

    void* INIT_ADDR = (void*) SDRAM_START;      // this kills code that we put in SDRAM!
    uint8_t* addr = (uint8_t*) INIT_ADDR;

    for (;;) {
        char c = Getc();
        const int BS = 1024;

        if (c == '\n') {
            UART_Echo();
        }
        else if (c == '\xAA') {
            Putc('a');
            addr = (uint8_t*) INIT_ADDR;
        }
        else if (c == '\xAD') {
            for (int i = 0; i < BS; i++) {
                *addr = Getc();
                addr++;
            }

            Putc('d');
        }
        else if (c == '\xAE') {
            Putc('e');

            // flush all caches
            __asm__ volatile ("fence");
            __asm__ volatile ("fence.i");

            // wait while UART busy
            while (TRACE_REG & UART_TX_BUSY) {
            }

            ((void (*)())(INIT_ADDR))();
        }
    }
}
