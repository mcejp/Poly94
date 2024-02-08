// BOOTROM=firmware/build/boot_sdram.bin NUM_CYCLES=2000000000 SDRAM_PRELOAD=firmware/build/demo_memory_latency.bin make sim
// (2e9 cycles)

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <math.h>
#include <sys/time.h>
#include <unistd.h>

#include <errno.h>

#include <Poly94_hw.h>

#define CACHELINE_SIZE 32

static int const default_test_sizes[] = { 2, 4, 8, 12, 16, 24, 32, 48, 64, 96, 128, 192, 256, 384, 512, 600, 768, 1024, 1536, 2048,
                               3072, 4096, 5120, 6144, 8192, 10240, 12288, 16384, 24567 };

extern void preplatencyarr(uint32_t *arr, uint32_t len);
extern void preplatencyarr16(uint16_t *arr, uint32_t len);
extern uint32_t latencytest(uint32_t iterations, uint32_t *arr);
extern uint32_t latencytest16(uint32_t iterations, uint16_t *arr);

extern void test_latency_ld16(uint16_t* arr, uint32_t iterations);
extern void test_latency_ld32(uint16_t* arr, uint32_t iterations);
extern void test_latency_st16(uint16_t* arr, uint32_t iterations);
extern void test_latency_st32(uint16_t* arr, uint32_t iterations);

float RunAsmTest(uint32_t size_kb);
float RunAsmTest16(uint32_t size_kb);
void RunLatencyTest();

float (*testFunc)(uint32_t) = RunAsmTest;

int main(int argc, char* argv[]) {
    uint32_t maxTestSizeMb = 0;
    uint32_t singleSize = 0;
    uint32_t testSizeCount = sizeof(default_test_sizes) / sizeof(int);

    RunLatencyTest();

    printf("Size (kB),Latency (cycles)\n");
    for (int i = 0; i < testSizeCount; i++) {
        if ((maxTestSizeMb == 0) || (default_test_sizes[i] <= maxTestSizeMb * 1024))
            printf("%d,%f\n", default_test_sizes[i], testFunc(default_test_sizes[i]));
        else {
            fprintf(stderr, "Test size %u KB exceeds max test size of %u KB\n", default_test_sizes[i], maxTestSizeMb * 1024);
            break;
        }
    }

    return 0;
}

/// <summary>
/// Heuristic to make sure test runs for enough time but not too long
/// </summary>
/// <param name="size_kb">Region size</param>
/// <param name="iterations">base iterations</param>
uint64_t scale_iterations(uint32_t size_kb) {
    if (size_kb <= 4) {
        return 500000;
    }
    else {
        return 10000;
    }
}

// Fills an array using Sattolo's algo
void FillPatternArr(uint32_t *pattern_arr, uint32_t list_size, uint32_t byte_increment) {
    uint32_t increment = byte_increment / sizeof(uint32_t);
    uint32_t element_count = list_size / increment;
    for (int i = 0; i < element_count; i++) {
        pattern_arr[i * increment] = i * increment;
    }

    int iter = element_count;
    while (iter > 1) {
        iter -= 1;
        int j = iter - 1 == 0 ? 0 : rand() % (iter - 1);
        uint32_t tmp = pattern_arr[iter * increment];
        pattern_arr[iter * increment] = pattern_arr[j * increment];
        pattern_arr[j * increment] = tmp;
    }
}

void FillPatternArr16(uint16_t *pattern_arr, uint32_t list_size, uint32_t byte_increment) {
    uint32_t increment = byte_increment / sizeof(uint16_t);
    uint32_t element_count = list_size / increment;
    for (int i = 0; i < element_count; i++) {
        pattern_arr[i * increment] = i * increment;
    }

    int iter = element_count;
    while (iter > 1) {
        iter -= 1;
        int j = iter - 1 == 0 ? 0 : rand() % (iter - 1);
        uint16_t tmp = pattern_arr[iter * increment];
        pattern_arr[iter * increment] = pattern_arr[j * increment];
        pattern_arr[j * increment] = tmp;
    }
}

#define POINTER_SIZE 4
#define POINTER_INT uint32_t

float RunAsmTest(uint32_t size_kb) {
    uint32_t start, end;
    uint32_t list_size = size_kb * 1024 / POINTER_SIZE; // using 32-bit pointers
    uint32_t sum = 0, current;

    // Fill list to create random access pattern
    POINTER_INT *A;
    A = (POINTER_INT *)malloc(POINTER_SIZE * list_size);
    if (!A) {
        fprintf(stderr, "Failed to allocate memory for %u KB test\n", size_kb);
        return 0;
    }

    memset(A, 0, POINTER_SIZE * list_size);

    FillPatternArr(A, list_size, CACHELINE_SIZE);

    preplatencyarr(A, list_size);

    uint32_t scaled_iterations = scale_iterations(size_kb);

    // Run test
    start = rdcyclel();
    sum = latencytest(scaled_iterations, A);
    end = rdcyclel();
    float latency = (float)(end - start) / (float)scaled_iterations;
    free(A);

    if (sum == 0) printf("sum == 0 (?)\n");
    return latency;
}

float RunAsmTest16(uint32_t size_kb) {
    uint32_t start, end;
    uint32_t list_size = size_kb * 1024 / sizeof(uint16_t);
    uint32_t sum = 0, current;

    // Fill list to create random access pattern
    uint16_t *A;
    A = (uint16_t *)malloc(sizeof(uint16_t) * list_size);
    if (!A) {
        fprintf(stderr, "Failed to allocate memory for %u KB test\n", size_kb);
        return 0;
    }

    memset(A, 0, sizeof(uint16_t) * list_size);

    FillPatternArr16(A, list_size, CACHELINE_SIZE);

    preplatencyarr16(A, list_size);

    uint32_t scaled_iterations = scale_iterations(size_kb);

    // Run test
    start = rdcyclel();
    sum = latencytest16(scaled_iterations, A);
    end = rdcyclel();
    float latency = (float)(end - start) / (float)scaled_iterations;
    free(A);

    if (sum == 0) printf("sum == 0 (?)\n");
    return latency;
}

#define UNCACHED(expr) ((uintptr_t)(expr) | 0x80000000)

void RunLatencyTest() {
    uint32_t start, end, iterations;

    void* buf = malloc(1024);

    iterations = 100*1000;

    start = rdcyclel();
    test_latency_ld16((uint16_t*)UNCACHED(buf), iterations);
    end = rdcyclel();
    printf("16-bit uncached read latency: %f cycles\n", (float)(end - start) / iterations);

    start = rdcyclel();
    test_latency_ld32((uint16_t*)UNCACHED(buf), iterations);
    end = rdcyclel();
    printf("32-bit uncached read latency: %f cycles\n", (float)(end - start) / iterations);

    start = rdcyclel();
    test_latency_st16(buf, iterations);
    end = rdcyclel();
    printf("16-bit write latency: %f cycles\n", (float)(end - start) / iterations);

    start = rdcyclel();
    test_latency_st32(buf, iterations);
    end = rdcyclel();
    printf("32-bit write latency: %f cycles\n", (float)(end - start) / iterations);

    free(buf);
}
