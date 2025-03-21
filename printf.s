; nasm -f elf64 -l 1-nasm.lst 1-nasm.s  ;  ld -s -o 1-nasm 1-nasm.o
section .note.GNU-stack noexec nowrite progbits

section .text

global my_printf
global my_printf_FASTCALL
;global buffer_flush
extern atexit

%macro printf_buffer_flush 0

            push rdi

            mov rax, 0x01                               ; write64 (rdi, rsi, rdx) ... r10, r8, r9
            mov rdi, 1                                  ; stdout
            lea rsi, [rel printf_buffer]
            syscall

            xor rdx, rdx
            pop rdi

%endmacro

atexit_printf_buffer_flush:

            mov rax, 0x01                               ; write64 (rdi, rsi, rdx) ... r10, r8, r9
            mov rdi, 1                                  ; stdout
            lea rsi, [rel printf_buffer]
            movzx rdx, byte [rel printf_buffer_charge]
            syscall

            ret

;========================================================================================================
; Translates number to 2-degree based system and saves to temp_buffer in direct order
; Entry:    rax - dec number to translate
; Exit:     rax - length of string containig translated number
; Dstr:     rax, rbx, rcx, rdx, rsi, rdi
;========================================================================================================
%macro itoa 2
            lea rsi, [rel temp_buffer]
            lea rdi, [rel digits_string]
            mov rcx, %2
            shl rcx, 36 - %1

.while:     mov rbx, rax
            and rbx, rcx
            cmp rbx, 0
            jne .while_end

            shl rax, %1

            jmp .while

.while_end:
            mov ch, buffer_size

.loop:      cmp ch, cl
            je .loop_end

            cmp rax, 0
            je .loop_end

            mov rbx, rax
            and rbx, rcx
            shr rbx, 64 - %1

            mov dl, [rdi, rbx]
            mov [rsi], byte dl
            inc rsi

            shl rax, %1
            inc cl

            jmp .loop

.loop_end:  movzx rcx, cl

%endmacro


itoa_bin:   itoa 1, 0x10000000
            ret

itoa_oct:   itoa 3, 0x70000000
            ret

itoa_hex:   itoa 4, 0xF0000000
            ret

;========================================================================================================
;========================================================================================================
my_printf_FASTCALL:
            push r9
            push r8
            push rcx
            push rdx
            push rsi
            push rdi

            jmp my_printf

;========================================================================================================
; Entry:
; Exit:     rdx - number of characters printed
; Dstr:     rax, rbx, rcx, rdx, rsi, rdi
;========================================================================================================
my_printf:  ; in this function the following registered used for
            ; rdi - adress of format string
            ; rsi - pointer to first free byte in buffer
            ; rdx - counter of bytes written in buffer

            mov rdi, atexit_printf_buffer_flush  ; Pass exit function pointer to atexit
            call atexit

            pop rdi                         ; assuming last pushed arg is a format string
            call strlen                     ; rcx = strlen(rdi)
            add rcx, rdi                    ; rcx = end of format string

            lea rsi, [rel printf_buffer]
            xor rdx, rdx
.while:
            cmp rcx, rdi
            je .printf_end

            cmp rdx, buffer_size
            je  .buffer_flush

            cmp byte [rdi], '%'
            je  .specification_switch

            mov al, [rdi]                   ; just a character => put to printf buffer
            mov [rsi], al                   ; while ([rdi] != '%')[rsi++] = [rdi++]; rdx++;
            inc rdi
            inc rsi
            inc rdx
            jmp .while

.buffer_flush:
            printf_buffer_flush
            jmp .while

.specification_switch:

            inc rdi
            cmp byte [rdi], '%'
            je  .perc_spec                  ; in this case '%' will be added to buff

            movzx rax, byte [rdi]           ; check if byte in range of switch cases
            sub rax, 'b'
            cmp rax, 'x' - 'b'
            ja  .default

            inc rdi
            lea rbx, [rel spec_jt]          ; load switch option
            mov eax, [rbx + rax * 4]
            lea rbx, [rel my_printf]
            lea rax, [rbx + rax]
            jmp rax

.perc_spec: mov al, '%'
            mov [rsi], al
            inc rsi
            inc rdx
            jmp .while

.bin_spec:  pop rax
            push rcx
            push rdi
            push rdx
            call itoa_bin
            pop rdx
            pop rdi

            lea rbx, [rel temp_buffer]
            call add_to_buffer
            pop rcx
            jmp .switch_end

.chr_spec:
            jmp .switch_end
.dec_spec:
            jmp .switch_end

.oct_spec:  pop rax
            push rcx
            push rdi
            push rdx
            call itoa_oct
            pop rdx
            pop rdi

            lea rbx, [rel temp_buffer]
            call add_to_buffer
            pop rcx
            jmp .switch_end

.str_spec:  pop rbx
            jmp .switch_end

.hex_spec:  pop rax
            push rcx
            push rdi
            push rdx
            call itoa_hex
            pop rdx
            pop rdi

            lea rbx, [rel temp_buffer]
            call add_to_buffer
            pop rcx
            jmp .switch_end

.default:

.switch_end:
            jmp .while

.printf_end:

            lea rsi, [rel printf_result]
            mov rax, [rsi]
            add rax, rdx                                ; printf return value

            lea rsi, [rel printf_buffer_charge]
            mov [rsi], dl                               ; save number of bytes in buffer for atexit or further calls

            pop rdx
            pop rcx
            pop r8
            pop r9
            ret

;========================================================================================================
; adds to buffer bytes of rbx starting from the highest until zero byte is met
; Entry:    rbx - pointer to a string for adding to buffer
;           rcx - length of string
;           rdi - pointer to buffer
; Exit:     None
; Dstr:     rbx
;========================================================================================================
add_to_buffer:

            lea rsi, [rel printf_buffer]
            mov rax, rcx
            add rax, rdx                                ; + длина добавлемой строки
            cmp rax, buffer_size                        ; 0FD - длина буфера
            jb .add

            cmp rdx, 0
            jne .buffer_flush

            ;

.buffer_flush:
            push rdi

            mov rax, 0x01                               ; write64 (rdi, rsi, rdx) ... r10, r8, r9
            mov rdi, 1                                  ; stdout
            syscall

            xor rdx, rdx
            pop rdi

            jmp add_to_buffer

.add:       mov al, [rbx]
            mov [rsi], al
            inc rbx
            inc rsi
            inc rdx

            loop .add

            ret

;========================================================================================================
; Returns length of the string ending with zero byte
; Entry:    rdi - pointer to a string
; Exit:     rcx - length of the string
; Dstr:     rcx
;========================================================================================================
strlen:     push rdi
            xor rcx, rcx
            xor al, al

.loop:      cmp al, byte [rdi]
            je .loop_end

            inc rdi
            inc rcx
            jmp .loop

.loop_end:
            pop rdi
            ret

section     .data

printf_result:  dq 0
printf_buffer_charge:   db 0
printf_buffer:  dq 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
buffer_size     equ 255
temp_buffer:    dq 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

section     .rodata

digits_string:  db '0123456789ABCDEF'

spec_jt:
    dd my_printf.bin_spec - my_printf
    dd my_printf.chr_spec - my_printf
    dd my_printf.dec_spec - my_printf
    dd my_printf.dec_spec - my_printf
    dd my_printf.dec_spec - my_printf
    dd my_printf.dec_spec - my_printf
    dd my_printf.dec_spec - my_printf
    dd my_printf.dec_spec - my_printf
    dd my_printf.dec_spec - my_printf
    dd my_printf.dec_spec - my_printf
    dd my_printf.dec_spec - my_printf
    dd my_printf.dec_spec - my_printf
    dd my_printf.dec_spec - my_printf
    dd my_printf.oct_spec - my_printf
    dd my_printf.oct_spec - my_printf
    dd my_printf.oct_spec - my_printf
    dd my_printf.oct_spec - my_printf
    dd my_printf.str_spec - my_printf
    dd my_printf.str_spec - my_printf
    dd my_printf.str_spec - my_printf
    dd my_printf.str_spec - my_printf
    dd my_printf.str_spec - my_printf
    dd my_printf.hex_spec - my_printf
