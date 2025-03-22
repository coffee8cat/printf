
//extern void itoa();
extern int my_printf_FASTCALL(...);

int main()
{
    const char* test_string = "Hello there";
    my_printf_FASTCALL("%%\nbin:%b\noct:%o\nhex:%x\nchar:%c\n%s\n", 25, 24, 31, 'j', test_string);
    //itoa();
    return 0;
}
