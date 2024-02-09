.text

.global latencytest
.global latencytest16
.global preplatencyarr
.global preplatencyarr16
.global test_latency_st16
.global test_latency_st32
.global test_latency_ld16
.global test_latency_ld32

.balign 4096

/* a0 = ptr to arr
   a1 = arr len
   convert values in array from array indexes to pointers */
preplatencyarr:
  # t0 = ptr
  # t1 = end
  mv t0, a0
  slli t1, a1, 2
  add t1, t0, t1
preplatencyarr_loop:
  lw t2, 0(t0)
  slli t2, t2, 2
  add t2, t2, a0
  sw t2, 0(t0)
  addi t0, t0, 4
  bne t0, t1, preplatencyarr_loop

  ret

/* a0 = iteration count
   a1 = ptr to arr
   do pointer chasing for specified iteration count */
.balign 32
latencytest:
  # t0 = iteration counter
  li t0, 0
latencytest_loop:
  # Setting this to 32 gives better results for sizes <= 4 kB, but seems to hang for larger sizes
  .rept 16
  lw a1, 0(a1)
  .endr
  addi t0, t0, 16
  bne t0, a0, latencytest_loop

  ret

/* a0 = ptr to arr
   a1 = arr len
   convert values in array from array indexes to pointers */
preplatencyarr16:
  # t0 = ptr
  # t1 = end
  mv t0, a0
  slli t1, a1, 1
  add t1, t0, t1
preplatencyarr16_loop:
  lhu t2, 0(t0)
  slli t2, t2, 1
  sh t2, 0(t0)
  addi t0, t0, 2
  bne t0, t1, preplatencyarr16_loop

  ret

/* a0 = iteration count
   a1 = ptr to arr
   do pointer chasing for specified iteration count */
.balign 32
latencytest16:
  # t0 = iteration counter
  # t1 = current position (in bytes)
  li t0, 0
  li t1, 0
latencytest16_loop:
  .rept 1
  add t2, a1, t1    # t2 = &array[curr_pos]
  lh t1, 0(t2)      # curr_pos = array[curr_pos] -- array values are already pre-scaled
  .endr
  addi t0, t0, 1
  bne t0, a0, latencytest16_loop

  ret


# write a bunch of addresses, spaced by cache line size
# a0 = 512-byte buffer
# a1 = num. iterations
.balign 32
test_latency_st16:

test_latency_st16_loop:
  sh zero, 0(a0)
  sh zero, 32(a0)
  sh zero, 64(a0)
  sh zero, 96(a0)
  sh zero, 128(a0)
  sh zero, 160(a0)
  sh zero, 192(a0)
  sh zero, 224(a0)

  sh zero, 256(a0)
  sh zero, 288(a0)
  sh zero, 320(a0)
  sh zero, 352(a0)
  sh zero, 384(a0)
  sh zero, 416(a0)
  sh zero, 448(a0)
  sh zero, 480(a0)

  sh zero, 512(a0)
  sh zero, 544(a0)
  sh zero, 576(a0)
  sh zero, 608(a0)
  sh zero, 640(a0)
  sh zero, 672(a0)
  sh zero, 704(a0)
  sh zero, 736(a0)

  sh zero, 768(a0)
  sh zero, 800(a0)
  sh zero, 832(a0)
  sh zero, 864(a0)
  sh zero, 896(a0)
  sh zero, 928(a0)
  sh zero, 960(a0)
  sh zero, 992(a0)

  # 32 reps per loop
  addi a1, a1, -32
  blt zero, a1, test_latency_st16_loop

  ret


# write a bunch of addresses, spaced by cache line size
# a0 = 512-byte buffer
# a1 = num. iterations
.balign 32
test_latency_st32:

test_latency_st32_loop:
  sw zero, 0(a0)
  sw zero, 32(a0)
  sw zero, 64(a0)
  sw zero, 96(a0)
  sw zero, 128(a0)
  sw zero, 160(a0)
  sw zero, 192(a0)
  sw zero, 224(a0)

  sw zero, 256(a0)
  sw zero, 288(a0)
  sw zero, 320(a0)
  sw zero, 352(a0)
  sw zero, 384(a0)
  sw zero, 416(a0)
  sw zero, 448(a0)
  sw zero, 480(a0)

  sw zero, 512(a0)
  sw zero, 544(a0)
  sw zero, 576(a0)
  sw zero, 608(a0)
  sw zero, 640(a0)
  sw zero, 672(a0)
  sw zero, 704(a0)
  sw zero, 736(a0)

  sw zero, 768(a0)
  sw zero, 800(a0)
  sw zero, 832(a0)
  sw zero, 864(a0)
  sw zero, 896(a0)
  sw zero, 928(a0)
  sw zero, 960(a0)
  sw zero, 992(a0)

  # 32 reps per loop
  addi a1, a1, -32
  blt zero, a1, test_latency_st32_loop

  ret


# read a bunch of addresses, spaced by cache line size
# a0 = 512-byte buffer
# a1 = num. iterations
.balign 32
test_latency_ld16:

test_latency_ld16_loop:
  lhu t0, 0(a0)
  lhu t0, 32(a0)
  lhu t0, 64(a0)
  lhu t0, 96(a0)
  lhu t0, 128(a0)
  lhu t0, 160(a0)
  lhu t0, 192(a0)
  lhu t0, 224(a0)

  lhu t0, 256(a0)
  lhu t0, 288(a0)
  lhu t0, 320(a0)
  lhu t0, 352(a0)
  lhu t0, 384(a0)
  lhu t0, 416(a0)
  lhu t0, 448(a0)
  lhu t0, 480(a0)

  lhu t0, 512(a0)
  lhu t0, 544(a0)
  lhu t0, 576(a0)
  lhu t0, 608(a0)
  lhu t0, 640(a0)
  lhu t0, 672(a0)
  lhu t0, 704(a0)
  lhu t0, 736(a0)

  lhu t0, 768(a0)
  lhu t0, 800(a0)
  lhu t0, 832(a0)
  lhu t0, 864(a0)
  lhu t0, 896(a0)
  lhu t0, 928(a0)
  lhu t0, 960(a0)
  lhu t0, 992(a0)

  # 32 reps per loop
  addi a1, a1, -32
  blt zero, a1, test_latency_ld16_loop

  ret


# read a bunch of addresses, spaced by cache line size
# a0 = 512-byte buffer
# a1 = num. iterations
.balign 32
test_latency_ld32:

test_latency_ld32_loop:
  lw t0, 0(a0)
  lw t0, 32(a0)
  lw t0, 64(a0)
  lw t0, 96(a0)
  lw t0, 128(a0)
  lw t0, 160(a0)
  lw t0, 192(a0)
  lw t0, 224(a0)

  lw t0, 256(a0)
  lw t0, 288(a0)
  lw t0, 320(a0)
  lw t0, 352(a0)
  lw t0, 384(a0)
  lw t0, 416(a0)
  lw t0, 448(a0)
  lw t0, 480(a0)

  lw t0, 512(a0)
  lw t0, 544(a0)
  lw t0, 576(a0)
  lw t0, 608(a0)
  lw t0, 640(a0)
  lw t0, 672(a0)
  lw t0, 704(a0)
  lw t0, 736(a0)

  lw t0, 768(a0)
  lw t0, 800(a0)
  lw t0, 832(a0)
  lw t0, 864(a0)
  lw t0, 896(a0)
  lw t0, 928(a0)
  lw t0, 960(a0)
  lw t0, 992(a0)

  # 32 reps per loop
  addi a1, a1, -32
  blt zero, a1, test_latency_ld32_loop

  ret
