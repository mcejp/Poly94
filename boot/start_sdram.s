
.section .init
.global _boot

_boot:
	la x2, __stack
    la t0, 1
    la t1, 0x8100000c
    sw t0, (t1)
    la t0, 0x04000000
	jr t0
