# Poly94 computing platform

![snapshot](_img/snapshot.jpg)

## Connecting ULX3S

You need to connect to USB1 (US1) connector to the host computer in order to program the board.

<img src="https://raw.githubusercontent.com/ulx3s/quick-start/master/images/ulx3s-usb1.jpg?raw=true" width="400">

## Development environment

Highly recommended to use the YosysHQ [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build). It includes all of the necessary tools (and many more):
- Yosys
- nextpnr-ecp5
- Verilator
- Icarus Verilog
- Python & cocotb

## Build and program bitstream

```
make ulx3s.bit    # (optional)
make prog
```

## Testing

```
# Verilator (currently not working with SDRAM model)
make sim

# cocotb
make -f Makefile.coco
```
