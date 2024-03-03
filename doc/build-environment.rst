=================
Build environment
=================

In CI, a Docker container with the `poly94-buildenv <https://gitlab.com/mcejp/poly94-buildenv/-/blob/master/Dockerfile>`_ image is used.

This contains:

- Ubuntu 22.04
- `oss-cad-suite 2022-05-20 <https://github.com/YosysHQ/oss-cad-suite-build/releases/tag/2022-05-20>`_
    - Verilator 4.223 devel rev v4.222-31-g9edccfdf
    - Icarus Verilog version 12.0 (devel) (s20150603-1507-g5d9740572)
    - Yosys 0.17+30 (git sha1 015ca4dda)
    - nextpnr-0.3-25-g4ecbf6c6
    - cocotb 1.7.0. dev0
    - Python 3.8.6
- xpack-riscv-none-embed-gcc 10.2.0-1.2
- additional packages:
    - CMake 3.22.1
    - GCC 11.2.0
    - curl, bsdmainutils, make, perl


Generating VexRiscV
===================

Separate repo: https://github.com/mcejp/vexriscv-docker

.. code-block::

    build.sh
    make


Simulation environments
=======================

- Verilator (~1.58 Mcycles/sec on i7-8565U @ 1.80 GHz)
- cocotb (~833 cycles/sec)
