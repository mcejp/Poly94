
MEMORY
{
  RAM (xrw) : ORIGIN = 0x04000000, LENGTH = 32768K
}

__stack = ORIGIN(RAM) + LENGTH(RAM);

ENTRY(_boot)

SECTIONS
{
    .init : ALIGN(4)
    {
        KEEP(*(.init))

        __data_regions_array_start = .;
        
        LONG(LOADADDR(.data));
        LONG(ADDR(.data));
        LONG(ADDR(.data)+SIZEOF(.data));

        __data_regions_array_end = .;
        
        __bss_regions_array_start = .;
        
        LONG(ADDR(.bss));
        LONG(ADDR(.bss)+SIZEOF(.bss));
        
        __bss_regions_array_end = .;

        KEEP(*(.fini))

        . = ALIGN(4);
    } >RAM

    .text : ALIGN(4)
    {
        *(.text .text.*)            /* all remaining code */
 
        *(.rdata)
        *(.rodata .rodata.*)
        . = ALIGN(8);
        *(.srodata.cst16)
        *(.srodata.cst8)
        *(.srodata.cst4)
        *(.srodata.cst2)
        *(.srodata .srodata.*)
    } >RAM

    .data : ALIGN(4)
    {
        FILL(0xFF)

        __data_start__ = . ;
        *(.data_begin .data_begin.*)

        *(.data .data.*)
        *(.sdata .sdata.* .sdata2.*)
        
        *(.data_end .data_end.*)
        . = ALIGN(4);

        __data_end__ = . ;

    } >RAM
    

    /* The primary uninitialised data section. */
    .bss (NOLOAD) : ALIGN(4)
    {
        __bss_start__ = .;      /* standard newlib definition */
        *(.bss_begin .bss_begin.*)

        *(.sbss*)
        *(.bss .bss.*)
        *(COMMON)
        
        *(.bss_end .bss_end.*)
        . = ALIGN(4);
        __bss_end__ = .;        /* standard newlib definition */
    } >RAM

    . = ALIGN(4);

    end = .;
}
