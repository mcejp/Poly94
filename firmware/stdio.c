#include <Poly94_hw.h>

#include <stdio.h>


int _write(int handle, char const* data, int size) {
    for (int count = 0; count < size; count++) {
        // wait while UART busy
        while (_HW.UART.STATUS & UART_STATUS_TX_BUSY) {
        }

        _HW.UART.DATA = data[count];
    }

    return size;
}
