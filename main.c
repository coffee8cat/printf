#include <stdio.h>
#include <stdlib.h>

extern int my_printf_FASTCALL(...);
extern void atexit_printf_buffer_flush();
//extern void itoa(int);

// check stdcall compatability -- done
// divide into functions       --done

int main()
{
    //itoa(-2);

    atexit(atexit_printf_buffer_flush);

    printf("Printf result = %d\n-----\n", my_printf_FASTCALL("\n%x %s %x %o %%%c %b %z\n", -1, "love", 3802, 80, 33, 126));
    my_printf_FASTCALL("lkmjhbvghjbskalm\n");
    return 0;
}
