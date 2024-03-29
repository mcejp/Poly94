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
    while (!(_HW.UART.STATUS & UART_STATUS_RX_NOT_EMPTY)) {
    }

    return _HW.UART.DATA;
}

static void Putc(char c) {
    // wait while UART busy
    while (_HW.UART.STATUS & UART_STATUS_TX_BUSY) {
    }

    _HW.UART.DATA = c;
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

// TODO: this should come from https://github.com/riscv-software-src/riscv-pk/blob/master/machine/encoding.h
#define MSTATUS_MIE         0x00000008

void __attribute__((interrupt)) interrupt_handler() {
    Putc('!');
    Puth(_HW.SYS.IP);
    _HW.SYS.IP = _HW.SYS.IP;        // ack all ... probably shouldn't do that
    Puth(_HW.SYS.IP);
    Puth(read_csr(mip));
    Putc('\n');
}

int main() {
    // TRACE_REG = 'H';
    // TRACE_REG = 'e';
    // TRACE_REG = 'l';
    // TRACE_REG = 'l';
    // TRACE_REG = 'o';
    // TRACE_REG = '\n';

    // write_csr(mtvec, (uint32_t)(&interrupt_handler) & ~3);
    // write_csr(mie, read_csr(mie) | (1 << 11));  // enable ext interrupts
    // write_csr(mstatus, read_csr(mstatus) | MSTATUS_MIE);  // enable interrupts

    // _HW.SYS.IE |= SYS_IE_VSYNC | SYS_IE_HSYNC;

    for (int i = 0; i < MSG_LEN; i++) {
        sdram_x8[i] = message[i];
    }

    // Copy functions marked .text_sdram to SDRAM
    for (int i = 0; i < __text_in_sdram_regions_array_start.dest_end - __text_in_sdram_regions_array_start.dest_begin; i++) {
        __text_in_sdram_regions_array_start.dest_begin[i] = __text_in_sdram_regions_array_start.source_begin[i];
    }

    message_sdram_x32[100] = 0x12345678;

    _HW.VIDEO.BG_COLOR = 0xffff00;

    for (;;) {
        Puth(message_sdram_x32[100]);
        Puts("\n\n");

        for (int i = 0; i < MSG_LEN; i++) {
            _HW.VIDEO.BG_COLOR = (i & 0xff00);

            Putc(sdram_x8[i % MSG_LEN]);
        }

        Puth(rdcyclel());
        Puts(" cycles\n");

        break;
    }

#define MIN(a, b) ((a) < (b) ? (a) : (b))

    uint32_t start = rdcyclel();

    for (int y = 0; y < 240; y++) {
        for (int x = 0; x < 320; x++) {
            int r = 16 + (x / 8) * 16 / 40;
            int g = 32 + MIN(x, y) / 8 * 16 / 30;
            int b = 16 + (y / 8) * 16 / 30;
            framebuf_sdram_x16[y * 320 + x] = (r << 11) | (g << 5) | b;
        }
    }

    uint32_t end = rdcyclel();
    Puth(end - start);
    Puts(" cycles to fill framebuffer.\n");

    _HW.VIDEO.CTRL = VIDEO_CTRL_FB_EN;      // bug: enabling fb_en in the middle of the frame leaves it with wrong SDRAM read ptr

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

            // flush all caches + insert 5 NOPs as per https://github.com/SpinalHDL/VexRiscv/issues/137#issuecomment-695762747
            __asm__ volatile ("fence");
            __asm__ volatile ("fence.i");
            __asm__ volatile ("nop");
            __asm__ volatile ("nop");
            __asm__ volatile ("nop");
            __asm__ volatile ("nop");
            __asm__ volatile ("nop");

            // wait while UART busy
            while (_HW.UART.STATUS & UART_STATUS_TX_BUSY) {
            }

            ((void (*)())(INIT_ADDR))();
        }
    }
}
