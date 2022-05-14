#include <stdint.h>

#define TRACE_REG (*(uint32_t volatile*)0x1000)
#define BG_COLOR (*(uint32_t volatile*)0x1004)

#define message_sdram ((uint32_t volatile*)0x40000000)

static const char message[] = "Hello world from SDRAM!\r\n";

#define MSG_LEN (sizeof(message) - 1)

// WATCH OUT: Don't have any stack yet! (only 16-bit access to SDRAM works)

__attribute__((naked))
void bootldr() {
    // TRACE_REG = 'H';
    // TRACE_REG = 'e';
    // TRACE_REG = 'l';
    // TRACE_REG = 'l';
    // TRACE_REG = 'o';
    // TRACE_REG = '\n';

    for (int i = 0; i < MSG_LEN; i++) {
        message_sdram[i] = message[i];
    }

    for (int i = 0; ; i++) {
        BG_COLOR = (i & 0xff00);

        // wait while UART busy
        while (TRACE_REG & 1) {
        }

        TRACE_REG = message_sdram[i % MSG_LEN];
    }
}
