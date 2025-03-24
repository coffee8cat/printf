all:
	make compile
	make run

compile:
	nasm -f elf64 -l printf.lst printf.s
	gcc -c main.c -o main.o
	gcc main.o printf.o -o main

run:
	gdb main

debug:
	edb --run main
