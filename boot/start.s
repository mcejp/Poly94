
.section .init
.global _boot

_boot:
	la x2, __stack
	j bootldr
