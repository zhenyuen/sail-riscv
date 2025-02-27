int main(void) {
    volatile unsigned int *gDebugLedsMemoryMappedRegister =
        (unsigned int *)0x2000;  //
    // volatile unsigned int *gDebugLedsMemoryMappedRegister = (unsigned int
    // *)0x8000000;

    *gDebugLedsMemoryMappedRegister = 0x00;
    for (int j = 0; j < 1600000; j++)
        ;
    *gDebugLedsMemoryMappedRegister = 0xFF;

    for (int j = 0; j < 100000; j++) {
        // Benchmark more complex logical and arithmetic operations.
        int A = 1062;
        float B = 2653;
        int result;
        float fpresult;

        result = A * B;            // integer multiplication
        fpresult = result * B;     // floating point multiplication
        fpresult = A / B;          // floating point division
        fpresult = 12 * fpresult;  // fp multiplication with immediate
    }

    *gDebugLedsMemoryMappedRegister = 0x00;
    return 0;
}
