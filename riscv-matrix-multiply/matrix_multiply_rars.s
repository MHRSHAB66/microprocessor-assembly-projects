.data
# Example:
# A: 2x3  (M=2, N=3)
# [ 1 2 3 ]
# [ 4 5 6 ]
#
# B: 3x2  (N=3, P=2)
# [ 7  8 ]
# [ 9 10 ]
# [11 12 ]
#
# C: 2x2  (M=2, P=2) - result
# [ 0 0 ]
# [ 0 0 ]

M:  .word 2
N:  .word 3
P:  .word 2

A:  .word 1, 2, 3, 4, 5, 6
B:  .word 7, 8, 9, 10, 11, 12
C:  .word 0, 0, 0, 0

.text
.globl main
main:
    # Load M, N, P
    la t0, M
    lw t1, 0(t0)    # t1 = M
    la t0, N
    lw t2, 0(t0)    # t2 = N
    la t0, P
    lw t3, 0(t0)    # t3 = P

    la t4, A        # t4 = &A
    la t5, B        # t5 = &B
    la t6, C        # t6 = &C

    li s0, 0        # i = 0 (row of C)

row_loop:
    bge s0, t1, end

    li s1, 0        # j = 0 (col of C)
col_loop:
    bge s1, t3, next_row

    # offset = (i * P + j) * 4
    mul a0, s0, t3
    add a0, a0, s1
    slli a0, a0, 2
    add a1, t6, a0
    sw zero, 0(a1)      # C[i*P + j] = 0

    li s2, 0            # k = 0 (sum index)
inner_loop:
    bge s2, t2, next_col

    # a2 = (i*N + k) * 4 + &A
    mul a3, s0, t2
    add a3, a3, s2
    slli a3, a3, 2
    add a3, t4, a3
    lw a4, 0(a3)        # a4 = A[i*N + k]

    # a5 = (k*P + j) * 4 + &B
    mul a3, s2, t3
    add a3, a3, s1
    slli a3, a3, 2
    add a3, t5, a3
    lw a5, 0(a3)        # a5 = B[k*P + j]

    # Multiply and accumulate
    mul a3, a4, a5      # a3 = A[i*N + k] * B[k*P + j]

    # Load C[i*P + j]
    mul a0, s0, t3
    add a0, a0, s1
    slli a0, a0, 2
    add a1, t6, a0
    lw a6, 0(a1)        # a6 = C[i*P + j]

    add a6, a6, a3      # a6 += a3
    sw a6, 0(a1)        # C[i*P + j] = a6

    addi s2, s2, 1      # k++
    j inner_loop

next_col:
    addi s1, s1, 1      # j++
    j col_loop

next_row:
    addi s0, s0, 1      # i++
    j row_loop

end:
    # Print the four result words, then exit in RARS.
    la t0, C
    li t1, 4
print_result:
    lw a0, 0(t0)
    li a7, 1
    ecall
    li a0, 32
    li a7, 11
    ecall
    addi t0, t0, 4
    addi t1, t1, -1
    bnez t1, print_result
    li a0, 10
    li a7, 11
    ecall
    li a7, 10
    ecall
