.text
.global _start

_start:
    MOV     r0, #0

RP_loop:
    CMP     r0, #6
    BGE     END_SIMULATION
    MOV     r12, #0
    MOV     r1, #0
    LDR     r2, =CSIZE
    LDRB    r3, [r2]

reset_cache_loop:
    CMP     r1, r3
    BGE     reset_status_loop
    LDR     r4, =CACHE
    MOV     r5, #-1
    STRB    r5, [r4, r1]
    ADD     r1, r1, #1
    B       reset_cache_loop

reset_status_loop:
    MOV     r1, #0

reset_status_inner_loop:
    CMP     r1, r3
    BGE     reset_done
    LDR     r6, =STATUS
    MOV     r5, #0
    STRB    r5, [r6, r1]
    ADD     r1, r1, #1
    B       reset_status_inner_loop

reset_done:
    MOV     r7, #0
    MOV     r8, #0
    MOV     r14, #0
    CMP     r0, #0
    BEQ     FIFO_Policy
    CMP     r0, #1
    BEQ     LRU_Policy
    CMP     r0, #2
    BEQ     MRU_Policy
    CMP     r0, #3
    BEQ     LFU_Policy
    CMP     r0, #4
    BEQ     MFU_Policy
    CMP     r0, #5
    BEQ     RANDOM_Policy
    B       policy_finished

FIFO_Policy:
    PUSH    {r4-r11, lr}

fifo_loop:
    LDR     r9, =A_COUNT
    LDRB    r10, [r9]
    CMP     r12, r10
    BGE     fifo_exit
    LDR     r11, =ADDRESSES
    LDRB    r1, [r11, r12]
    ADD     r12, r12, #1
    AND     r5, r1, #3
    MOV     r6, r5, LSL #1
    LDR     r2, =CACHE
    LDRB    r3, [r2, r6]
    ADD     r4, r6, #1
    LDRB    r4, [r2, r4]
    CMP     r3, r1
    BEQ     fifo_hit
    CMP     r4, r1
    BEQ     fifo_hit
    ADD     r8, r8, #1
    CMP     r3, #0xFF
    BEQ     fifo_miss_empty0
    CMP     r4, #0xFF
    BEQ     fifo_miss_empty1
    LDR     r2, =STATUS
    ADD     r9, r2, r5
    LDRB    r10, [r9]
    CMP     r10, #0
    MOVEQ   r11, r6
    MOVNE   r11, r6
    ADDNE   r11, r11, #1
    LDR     r2, =CACHE
    STRB    r1, [r2, r11]
    EOR     r10, r10, #1
    STRB    r10, [r9]
    B       fifo_next_addr

fifo_miss_empty0:
    LDR     r2, =CACHE
    STRB    r1, [r2, r6]
    LDR     r2, =STATUS
    ADD     r9, r2, r5
    MOV     r10, #1
    STRB    r10, [r9]
    B       fifo_next_addr

fifo_miss_empty1:
    LDR     r2, =CACHE
    ADD     r11, r6, #1
    STRB    r1, [r2, r11]
    LDR     r2, =STATUS
    ADD     r9, r2, r5
    MOV     r10, #0
    STRB    r10, [r9]
    B       fifo_next_addr

fifo_hit:
    ADD     r7, r7, #1

fifo_next_addr:
    B       fifo_loop

fifo_exit:
    POP     {r4-r11}
    B       policy_finished

LRU_Policy:
    PUSH    {r4-r11, lr}

lru_loop:
    LDR     r9, =A_COUNT
    LDRB    r10, [r9]
    CMP     r12, r10
    BGE     lru_exit
    LDR     r11, =ADDRESSES
    LDRB    r1, [r11, r12]
    ADD     r12, r12, #1
    AND     r5, r1, #3
    MOV     r6, r5, LSL #1
    LDR     r2, =CACHE
    LDRB    r3, [r2, r6]
    ADD     r4, r6, #1
    LDRB    r4, [r2, r4]
    CMP     r3, r1
    BEQ     lru_hit_first
    CMP     r4, r1
    BEQ     lru_hit_second
    ADD     r8, r8, #1
    CMP     r3, #0xFF
    BEQ     lru_miss_empty_first
    CMP     r4, #0xFF
    BEQ     lru_miss_empty_second
    LDR     r2, =STATUS
    ADD     r9, r2, r5
    LDRB    r10, [r9]
    CMP     r10, #0
    MOVEQ   r11, r6
    MOVNE   r11, r6
    ADDNE   r11, r11, #1
    LDR     r2, =CACHE
    STRB    r1, [r2, r11]
    EOR     r10, r10, #1
    STRB    r10, [r9]
    B       lru_next_address

lru_miss_empty_first:
    LDR     r2, =CACHE
    STRB    r1, [r2, r6]
    LDR     r2, =STATUS
    ADD     r9, r2, r5
    MOV     r10, #1
    STRB    r10, [r9]
    B       lru_next_address

lru_miss_empty_second:
    LDR     r2, =CACHE
    ADD     r11, r6, #1
    STRB    r1, [r2, r11]
    LDR     r2, =STATUS
    ADD     r9, r2, r5
    MOV     r10, #0
    STRB    r10, [r9]
    B       lru_next_address

lru_hit_first:
    ADD     r7, r7, #1
    LDR     r2, =STATUS
    ADD     r9, r2, r5
    MOV     r10, #1
    STRB    r10, [r9]
    B       lru_next_address

lru_hit_second:
    ADD     r7, r7, #1
    LDR     r2, =STATUS
    ADD     r9, r2, r5
    MOV     r10, #0
    STRB    r10, [r9]
    B       lru_next_address

lru_next_address:
    B       lru_loop

lru_exit:
    POP     {r4-r11}
    B       policy_finished

MRU_Policy:
    PUSH    {r4-r11, lr}

mru_loop:
    LDR     r9, =A_COUNT
    LDRB    r10, [r9]
    CMP     r12, r10
    BGE     mru_exit
    LDR     r11, =ADDRESSES
    LDRB    r1, [r11, r12]
    ADD     r12, r12, #1
    AND     r5, r1, #3
    MOV     r6, r5, LSL #1
    LDR     r2, =CACHE
    LDRB    r3, [r2, r6]
    ADD     r4, r6, #1
    LDRB    r4, [r2, r4]
    CMP     r3, r1
    BEQ     mru_hit_first
    CMP     r4, r1
    BEQ     mru_hit_second
    ADD     r8, r8, #1
    CMP     r3, #0xFF
    BEQ     mru_miss_empty_first
    CMP     r4, #0xFF
    BEQ     mru_miss_empty_second
    LDR     r2, =STATUS
    ADD     r9, r2, r5
    LDRB    r10, [r9]
    CMP     r10, #0
    MOVEQ   r11, r6
    MOVNE   r11, r6
    ADDNE   r11, r11, #1
    LDR     r2, =CACHE
    STRB    r1, [r2, r11]
    B       mru_next_address

mru_miss_empty_first:
    LDR     r2, =CACHE
    STRB    r1, [r2, r6]
    LDR     r2, =STATUS
    ADD     r9, r2, r5
    MOV     r10, #0
    STRB    r10, [r9]
    B       mru_next_address

mru_miss_empty_second:
    LDR     r2, =CACHE
    ADD     r11, r6, #1
    STRB    r1, [r2, r11]
    LDR     r2, =STATUS
    ADD     r9, r2, r5
    MOV     r10, #1
    STRB    r10, [r9]
    B       mru_next_address

mru_hit_first:
    ADD     r7, r7, #1
    LDR     r2, =STATUS
    ADD     r9, r2, r5
    MOV     r10, #0
    STRB    r10, [r9]
    B       mru_next_address

mru_hit_second:
    ADD     r7, r7, #1
    LDR     r2, =STATUS
    ADD     r9, r2, r5
    MOV     r10, #1
    STRB    r10, [r9]
    B       mru_next_address

mru_next_address:
    B       mru_loop

mru_exit:
    POP     {r4-r11}
    B       policy_finished

LFU_Policy:
    PUSH    {r4-r11, lr}

lfu_loop:
    LDR     r9, =A_COUNT
    LDRB    r10, [r9]
    CMP     r12, r10
    BGE     lfu_exit
    LDR     r11, =ADDRESSES
    LDRB    r1, [r11, r12]
    ADD     r12, r12, #1
    AND     r5, r1, #3
    MOV     r6, r5, LSL #1
    LDR     r2, =CACHE
    LDRB    r3, [r2, r6]
    ADD     r4, r6, #1
    LDRB    r4, [r2, r4]
    CMP     r3, r1
    BEQ     lfu_hit_0
    CMP     r4, r1
    BEQ     lfu_hit_1
    ADD     r8, r8, #1
    CMP     r3, #0xFF
    BEQ     lfu_miss_empty0
    CMP     r4, #0xFF
    BEQ     lfu_miss_empty1
    LDR     r2, =STATUS
    LDRB    r3, [r2, r6]
    LDRB    r4, [r2, r4]
    CMP     r3, r4
    MOVLT   r9, r6
    MOVGT   r9, r6
    ADDGT   r9, r6, #1
    MOVEQ   r9, r6
    B       lfu_replace

lfu_replace:
    LDR     r2, =CACHE
    STRB    r1, [r2, r9]
    LDR     r2, =STATUS
    MOV     r10, #1
    STRB    r10, [r2, r9]
    B       lfu_next_addr

lfu_miss_empty0:
    LDR     r2, =CACHE
    STRB    r1, [r2, r6]
    LDR     r2, =STATUS
    MOV     r10, #1
    STRB    r10, [r2, r6]
    B       lfu_next_addr

lfu_miss_empty1:
    LDR     r2, =CACHE
    ADD     r9, r6, #1
    STRB    r1, [r2, r9]
    LDR     r2, =STATUS
    MOV     r10, #1
    STRB    r10, [r2, r9]
    B       lfu_next_addr

lfu_hit_0:
    ADD     r7, r7, #1
    LDR     r2, =STATUS
    LDRB    r10, [r2, r6]
    ADD     r10, r10, #1
    STRB    r10, [r2, r6]
    B       lfu_next_addr

lfu_hit_1:
    ADD     r7, r7, #1
    LDR     r2, =STATUS
    ADD     r9, r6, #1
    LDRB    r10, [r2, r9]
    ADD     r10, r10, #1
    STRB    r10, [r2, r9]
    B       lfu_next_addr

lfu_next_addr:
    B       lfu_loop

lfu_exit:
    POP     {r4-r11}
    B       policy_finished

MFU_Policy:
    PUSH    {r4-r11, lr}

mfu_loop:
    LDR     r9, =A_COUNT
    LDRB    r10, [r9]
    CMP     r12, r10
    BGE     mfu_exit
    LDR     r11, =ADDRESSES
    LDRB    r1, [r11, r12]
    ADD     r12, r12, #1
    AND     r5, r1, #3
    MOV     r6, r5, LSL #1
    LDR     r2, =CACHE
    LDRB    r3, [r2, r6]
    ADD     r4, r6, #1
    LDRB    r4, [r2, r4]
    CMP     r3, r1
    BEQ     mfu_hit_0
    CMP     r4, r1
    BEQ     mfu_hit_1
    ADD     r8, r8, #1
    CMP     r3, #0xFF
    BEQ     mfu_miss_empty0
    CMP     r4, #0xFF
    BEQ     mfu_miss_empty1
    LDR     r2, =STATUS
    LDRB    r3, [r2, r6]
    LDRB    r4, [r2, r4]
    CMP     r3, r4
    MOVGT   r9, r6
    MOVLT   r9, r6
    ADDLT   r9, r6, #1
    MOVEQ   r9, r6
    B       mfu_replace

mfu_replace:
    LDR     r2, =CACHE
    STRB    r1, [r2, r9]
    LDR     r2, =STATUS
    MOV     r10, #1
    STRB    r10, [r2, r9]
    B       mfu_next_addr

mfu_miss_empty0:
    LDR     r2, =CACHE
    STRB    r1, [r2, r6]
    LDR     r2, =STATUS
    MOV     r10, #1
    STRB    r10, [r2, r6]
    B       mfu_next_addr

mfu_miss_empty1:
    LDR     r2, =CACHE
    ADD     r9, r6, #1
    STRB    r1, [r2, r9]
    LDR     r2, =STATUS
    MOV     r10, #1
    STRB    r10, [r2, r9]
    B       mfu_next_addr

mfu_hit_0:
    ADD     r7, r7, #1
    LDR     r2, =STATUS
    LDRB    r10, [r2, r6]
    ADD     r10, r10, #1
    STRB    r10, [r2, r6]
    B       mfu_next_addr

mfu_hit_1:
    ADD     r7, r7, #1
    LDR     r2, =STATUS
    ADD     r9, r6, #1
    LDRB    r10, [r2, r9]
    ADD     r10, r10, #1
    STRB    r10, [r2, r9]
    B       mfu_next_addr

mfu_next_addr:
    B       mfu_loop

mfu_exit:
    POP     {r4-r11}
    B       policy_finished

RANDOM_Policy:
random_loop:
    LDR     r9, =A_COUNT
    LDRB    r10, [r9]
    CMP     r12, r10
    BGE     random_exit
    LDR     r11, =ADDRESSES
    LDRB    r1, [r11, r12]
    ADD     r12, r12, #1
    AND     r5, r1, #3
    LSL     r6, r5, #1
    LDR     r2, =CACHE
    LDRB    r3, [r2, r6]
    ADD     r6, r6, #1
    LDRB    r4, [r2, r6]
    CMP     r3, r1
    BEQ     random_hit
    CMP     r4, r1
    BEQ     random_hit
    ADD     r8, r8, #1
    CMP     r3, #0xFF
    BEQ     random_miss_empty0
    CMP     r4, #0xFF
    BEQ     random_miss_empty1
    BL      PRNG
    AND     r0, r0, #1
    ADD     r9, r6, r0
    LDR     r2, =CACHE
    STRB    r1, [r2, r9]
    B       random_loop

random_miss_empty0:
    LDR     r2, =CACHE
    STRB    r1, [r2, r6]
    B       random_loop

random_miss_empty1:
    LDR     r2, =CACHE
    ADD     r6, r6, #1
    STRB    r1, [r2, r6]
    B       random_loop

random_hit:
    ADD     r7, r7, #1
    B       random_loop

random_exit:
    POP     {r4-r11}
    B       policy_finished

PRNG:
    LDR     r1, =rand_seed
    LDR     r0, [r1]
    ADD     r0, r0, r12
    ADD     r0, r0, r8
    LDR     r2, =69069
    MUL     r0, r0, r2
    ADD     r0, r0, #1
    STR     r0, [r1]
    BX      lr

policy_finished:
    ADD     r0, r0, #1
    B       RP_loop

END_SIMULATION:
    B       END

END:
    B       END

.data
.align 4

CSIZE:          .byte 8
A_COUNT:        .byte 16
ADDRESSES:      .byte 12,10,12,10,14,10,10,10,6,10,8,6,10,14,14,12
CACHE:          .space 8
STATUS:         .space 8
rand_seed:      .word 12345