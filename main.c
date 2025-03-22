
//extern void itoa();
extern int my_printf_FASTCALL(...);

int main()
{
    my_printf_FASTCALL("bin:%b\noct:%o\nhex:%x\n", 25, 24, 31);
    //itoa();
    return 0;
}
