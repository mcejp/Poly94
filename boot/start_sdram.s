
.section .init
.global _boot

_boot:
    # init stack pointer
	la x2, __stack

    # call SDRAM entry point
    la t0, 0x04000000
    jalr ra, t0

    # loop indefinitely if callee returns
1:  j 1b
