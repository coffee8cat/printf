#include <stdio.h>
#include <stdlib.h>

extern int my_printf_FASTCALL(...);
extern void atexit_printf_buffer_flush();

int main()
{
    atexit(atexit_printf_buffer_flush);

    printf("Printf result = %d\n-----\n", my_printf_FASTCALL("\n%x %s %x %o %% %c %b\n", -1, "love", 3802, 80, 33, 126));
    /*
    const char* test_string = "Hello there";
    size_t n_tests = 6;
    int results[n_tests] = {};

    results[0] = my_printf_FASTCALL("\n%x %s %x %o %% %c %b\n", -1, "love", 3802, 80, 33, 126);
    results[1] = my_printf_FASTCALL("ssssssssssssss       %b\n", 126);
    results[2] = my_printf_FASTCALL("oct:%o\n", 24);
    results[3] = my_printf_FASTCALL("hex:%x\n", 31);
    results[4] = my_printf_FASTCALL("char:%c\n", 'j');
    results[5] = my_printf_FASTCALL("%s\n", test_string);

    printf("\n---Testing results---\n");
    for (size_t i = 0; i < n_tests; i++) {
        printf("%d\n", results[i]);
    }
    */

    return 0;
}
