## Building it

```
cmake -DCMAKE_TOOLCHAIN_FILE=../toolchain.cmake -DCMAKE_BUILD_TYPE=MinSizeRel -S firmware -B firmware/build
cmake --build firmware/build
```

## Targets

- `boot`: Default UART ROM bootloader
- `boot_sdram`: Stub to jump to program in SDRAM (mainly for simulation with program pre-loaded)
- `test_dhrystone`
- `test_framebuffer`
