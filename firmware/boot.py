#!/usr/bin/env python3

# behold the world's crappiest UART boot tool

import serial
import sys
import time

PORT, FILE = sys.argv[1:]
BAUD = 115200

verbose = False

with serial.Serial(PORT, BAUD) as ser, open(FILE, "rb") as f:
    def expect(what):
        resp = ser.read(1)

        if verbose: print("rx", resp)
        assert resp == what

    ser.write(b"\xAA")
    expect(b"a")
    print("handshake OK")

    BS = 1024

    num_sent = 0
    start = time.time()
    last_report = 0

    while True:
        data = f.read(BS)
        if not data: break

        if verbose: print("send", data)
        ser.write(b"\xAD")
        ser.write(data)
        ser.write(b"\0" * (BS - len(data)))    # pad

        expect(b"d")

        num_sent += BS
        if num_sent >= last_report + (BAUD // 8):
            now = time.time()
            speed = num_sent / (now - start)
            print(num_sent, f"bytes sent ({speed / 1000:.1f} kB/s)", file=sys.stderr)
            last_report = num_sent

    ser.write(b"\xAE")

    expect(b"e")
    print("done, booting", end="\n\n")

    while True:
        sys.stdout.write(ser.read(1).decode(errors="replace"))
        sys.stdout.flush()
