
MEMORY
{
  RAM (xrw) : ORIGIN = 0x04000000, LENGTH = 32768K
}

__stack = ORIGIN(RAM) + LENGTH(RAM);

PROVIDE ( _Heap_Begin = _end_noinit ) ;
PROVIDE ( _Heap_Limit = __stack - __Main_Stack_Size ) ;
PROVIDE ( end = __stack ) ;

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
 
        /* read-only data (constants) */
        *(.rodata .rodata.* .constdata .constdata.*)        

        *(vtable)                   /* C++ virtual tables */

        KEEP(*(.eh_frame*))
    } >RAM

    .data : ALIGN(4)
    {
        FILL(0xFF)

        __data_start__ = . ;
        *(.data_begin .data_begin.*)

        *(.data .data.*)
        
        *(.data_end .data_end.*)
        . = ALIGN(4);

        __data_end__ = . ;

    } >RAM
    

    /* The primary uninitialised data section. */
    .bss (NOLOAD) : ALIGN(4)
    {
        __bss_start__ = .;      /* standard newlib definition */
        *(.bss_begin .bss_begin.*)

        *(.bss .bss.*)
        *(COMMON)
        
        *(.bss_end .bss_end.*)
        . = ALIGN(4);
        __bss_end__ = .;        /* standard newlib definition */
    } >RAM

    . = ALIGN(4);
}
