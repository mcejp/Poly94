#include <Poly94_hw.h>

#include <stdio.h>


int _write(int handle, char const* data, int size) {
    for (int count = 0; count < size; count++) {
        // wait while UART busy
        while (TRACE_REG & 1) {
        }

        TRACE_REG = data[count];
    }

    return size;
}
