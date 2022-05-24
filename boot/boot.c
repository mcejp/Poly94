#include <stdint.h>

#define TRACE_REG           (*(uint32_t volatile*)0x81000000)
#define BG_COLOR            (*(uint32_t volatile*)0x81000004)
#define UART_DATA           (*(uint32_t volatile*)0x81000008)

#define UART_TX_BUSY        1
#define UART_RX_NOT_EMPTY   2

#define message_sdram_x32   ((uint32_t volatile*)0x08000100)
#define message_sdram_x16   ((uint16_t volatile*)0x08000100)
#define sdram_x8            ((uint8_t volatile*)0x08000100)

struct Load_Info {
    uint32_t* source_begin;
    uint32_t* dest_begin;
    uint32_t* dest_end;
};

extern struct Load_Info __text_in_sdram_regions_array_start;

static const char message[] = "Hello world from SDRAM!\r\n";

#define MSG_LEN (sizeof(message) - 1)

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

    for (;;) {
        if (TRACE_REG & UART_RX_NOT_EMPTY) {
            int data_in = UART_DATA;
            if (data_in == '\n') {
                Puts("\n> ");
            }
            else {
                Putc(data_in);
            }
        }
    }
}
