#include <stdio.h>
#include <stdint.h>
#include <inttypes.h>

#define ROW 3
#define STRIDE 4 // تعداد ستون‌های A و سطرهای B
#define COL 2

#define INPUT_A_SIZE (ROW * STRIDE)
#define INPUT_B_SIZE (STRIDE * COL)
#define OUTPUT_SIZE (ROW * COL)

// --- داده‌های جدید ماتریس‌ها ---
// ماتریس A: 3x4
int32_t inputMatrixA[INPUT_A_SIZE] = {
    1, 2, 3, 4,
    6, 6, 7, 8,
    9, 10, 11, 12
};

// ماتریس B: 4x2
int32_t inputMatrixB[INPUT_B_SIZE] = {
    2, 1,
    -1, 3,
    4, -2,
    5, 0
};

int32_t outputMatrix[OUTPUT_SIZE];

int main() {
    uintptr_t inA_base = (uintptr_t)&inputMatrixA[0];
    uintptr_t inB_base = (uintptr_t)&inputMatrixB[0];
    uintptr_t out_base = (uintptr_t)&outputMatrix[0];

    __asm__ volatile (
        "mv t5, %[inA]\n\t"
        "mv t6, %[inB]\n\t"
        "mv a3, %[out]\n\t"
        "li t3, %[stride]\n\t"      // STRIDE
        "li t4, %[row]\n\t"         // ROW
        "li a5, %[col]\n\t"         // COL

        "li t0, 0\n\t"              // i = 0
    "1:\n\t"
        "bge t0, t4, 4f\n\t"        // if i >= ROW → exit
        "li t1, 0\n\t"              // j = 0
    "2:\n\t"
        "bge t1, a5, 3f\n\t"        // if j >= COL → next row

        "li a4, 0\n\t"              // acc = 0
        "li t2, 0\n\t"              // k = 0
    "5:\n\t"
        "bge t2, t3, 6f\n\t"        // if k >= STRIDE → end k

        // A[i*STRIDE + k]
        "mul a6, t0, t3\n\t"
        "add a6, a6, t2\n\t"
        "slli a6, a6, 2\n\t"
        "add a1, t5, a6\n\t"
        "lw a1, 0(a1)\n\t"

        // B[k*COL + j]
        "mul a6, t2, a5\n\t"
        "add a6, a6, t1\n\t"
        "slli a6, a6, 2\n\t"
        "add a2, t6, a6\n\t"
        "lw a2, 0(a2)\n\t"

        // === START: FIX ===
        // acc += a1 * a2
        "mul a0, a1, a2\n\t"        // a0 = a1 * a2
        "add a4, a4, a0\n\t"        // acc (a4) += a0
        // === END: FIX ===

        "addi t2, t2, 1\n\t"        // k++
        "j 5b\n\t"

    "6:\n\t"
        "sw a4, 0(a3)\n\t"
        "addi a3, a3, 4\n\t"
        "addi t1, t1, 1\n\t"        // j++
        "j 2b\n\t"

    "3:\n\t"
        "addi t0, t0, 1\n\t"        // i++
        "j 1b\n\t"

    "4:\n\t"
        :
        : [inA]"r"(inA_base),
          [inB]"r"(inB_base),
          [out]"r"(out_base),
          [stride]"i"(STRIDE),
          [row]"i"(ROW),
          [col]"i"(COL)
        // 'a0' is now added to the clobber list
        : "t0","t1","t2","t3","t4","t5","t6",
          "a0","a1","a2","a3","a4","a5","a6","memory"
    );

    for (int i = 0; i < OUTPUT_SIZE; i++) {
        printf("%" PRId32 " ", outputMatrix[i]);
        if ((i+1) % COL == 0) printf("\n");
    }

    return 0;
}
