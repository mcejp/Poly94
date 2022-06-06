#ifndef POLY94_HW_H
#define POLY94_HW_H

#include <stdint.h>

#include "top.h"

/* memory map */

enum { SDRAM_START          = 0x04000000 };

/* Control/status registers (with cache bypass bit set) */

#define _HW (*(struct top volatile*)0x80000000)


/* RISC-V stuff */

#define read_csr(reg) ({ unsigned long __tmp; \
    asm volatile ("csrr %0, " #reg : "=r"(__tmp)); \
    __tmp; })

#endif
