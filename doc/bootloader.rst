==========
Bootloader
==========

The boot ROM contains a very crappy UART bootloader. Use it like this::

    make ulx3s.bit
    make prog
    ./firmware/boot.py /dev/ttyUSB0 firmware/build/demo_memory_latency.bin
