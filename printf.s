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
            mov rdx, rcx
            shl rdx, 31

.while:     inc dh
            cmp rdx, rcx
            jb  .while_end

            mov rbx, rax
            and rbx, rcx
            test rbx, rbx
            jz .skip

            mov dl, dh
.skip:
            shl rcx, %1

            jmp .while

.while_end:
            movzx rdx, dl
            mov rcx, rdx
            push rcx
            mov rcx, %2
            dec rdx
            add rsi, rdx
            lea rdx, [rel temp_buffer]
            dec rdx

.loop:      cmp rdx, rsi
            je .loop_end

            mov rbx, rax
            and rbx, rcx

            mov bl, [rdi, rbx]
            mov [rsi], byte bl

            dec rsi
            shr rax, %1
            jmp .loop

.loop_end:  pop rcx

%endmacro


itoa_bin:   itoa 1, 1
            ret

itoa_oct:   itoa 3, 7
            ret

itoa_hex:   itoa 4, 15
            ret

;========================================================================================================
;========================================================================================================
my_printf_FASTCALL:
            push rdi
            call count_printf_specificators
            pop rdi

            ; rax = al for this moment
            mov bl, 5
            cmp al, bl
            ja .6args

            sub al, bl
            neg al                                     ; rax = 5 - rax

            lea rbx, [rel printf_args_jt]          ; load switch option
            mov eax, [rbx + rax * 4]
            lea rbx, [rel my_printf_FASTCALL]
            lea rax, [rbx + rax]
            jmp rax

.6args:     push r9
.5args:     push r8
.4args:     push rcx
.3args:     push rdx
.2args:     push rsi
.1args:     push rdi

            jmp my_printf

;========================================================================================================
; Entry:    rdi - format string for printf
; Exit:     rax - numbet of specificators in format string
; Dstr:
;========================================================================================================
count_printf_specificators:
            xor rax, rax
            mov bh, '%'

.while:     mov bl, [rdi]
            cmp bl, ah                                  ; if ([rdi] == 0 <=> EOS met) { break }
            je .while_end

            cmp bl, bh                                  ; if ([rdi] == '%') { check_spec }
            je .check_spec

            inc rdi
            jmp .while

.check_spec:
            inc rdi
            ; Here I make use of fact that '%' is less than any of my specificators ASCII
            ; if ([rdi] > '%') { al++ }
            cmp bh, [rdi]                               ; check %%, CF = 1 if (bh < [rdi]), 0 otherwise
            adc al, ah                                  ; al = al + ah + CF, ah set as 0 after xor
            inc rdi
            jmp .while

.while_end:

            ret

;========================================================================================================
; Entry:
; Exit:     rdx - number of characters printed
; Dstr:     rax, rbx, rcx, rdx, rsi, rdi
;========================================================================================================
my_printf:  ; in this function the following registered used for
            ; rdi - adress of format string
            ; rsi - pointer to first free byte in buffer
            ; rdx - counter of bytes written in buffer
            ; rcx - end of format string - for end condition of while

            mov rdi, atexit_printf_buffer_flush  ; Pass exit function pointer to atexit
            call atexit

            pop rdi                         ; assuming last pushed arg is a format string
            call strlen                     ; rcx = strlen(rdi)
            add rcx, rdi                    ; rcx = end of format string

            lea rsi, [rel printf_buffer]
            xor rdx, rdx
.while:
            ; maybe rax = [rdi] ???


            cmp rcx, rdi                    ; eos met => break
            je .printf_end

            cmp rdx, buffer_size            ; check buffer overflow
            je  .buffer_flush

            movzx rax, byte [rdi]           ; read character from format string
            cmp al, '%'                     ; check for specifications
            je  .specification_switch

            ; if ([rdi] != '%') { [rsi++] = [rdi++]; rdx++; }
            mov [rsi], al                   ; not a special character => put to printf buffer
            inc rdi
            inc rsi
            inc rdx
            jmp .while

.buffer_flush:
            printf_buffer_flush             ; print buffer to consol
            jmp .while

.specification_switch:

            inc rdi                         ; check character after '%'
            movzx rax, byte [rdi]           ; read character from format string
            cmp rax, '%'
            je  .perc_spec                  ; in this case '%' will be added to buff

            sub rax, 'b'
            cmp rax, 'x' - 'b'
            ja  .default

            lea rbx, [rel spec_jt]          ; load switch option
            mov eax, [rbx + rax * 4]
            lea rbx, [rel my_printf]
            lea rax, [rbx + rax]
            jmp rax

.perc_spec: mov al, '%'
            mov [rsi], al
            inc rsi
            inc rdx
            jmp .switch_end

.bin_spec:  pop rax                         ; getarg for itoa

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

.chr_spec:  pop rax                         ; getarg
            mov [rsi], al
            inc rsi
            inc rdx
            jmp .switch_end
.dec_spec:
            jmp .switch_end

.oct_spec:  pop rax                         ; getarg for itoa
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

.str_spec:  pop rbx                         ; getarg - pointer to a string
            push rcx
            push rdi

            lea rdi, [rbx]
            call strlen                     ; rcx = strlen(rbx)

            pop rdi
            call add_to_buffer
            pop rcx
            jmp .switch_end

.hex_spec:  pop rax                         ; getarg for itoa
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

            inc rdi
            jmp .while

.printf_end:

            lea rsi, [rel printf_result]
            mov rax, [rsi]
            add rax, rdx                                ; printf return value

            lea rsi, [rel printf_buffer_charge]
            mov [rsi], dl                               ; save number of bytes in buffer for atexit or further calls

            ret

;========================================================================================================
; adds to buffer bytes of rbx starting from the highest until zero byte is met
; Entry:    rbx - pointer to a string for adding to buffer
;           rcx - length of string
; Exit:     None
; Dstr:     rax, rbx, rdx, rsi
;========================================================================================================
add_to_buffer:

            lea rsi, [rel printf_buffer]
            lea rsi, [rsi + rdx]

            mov rax, rcx
            add rax, rdx                                ; + длина добавлемой строки
            cmp rax, buffer_size                        ; 0FD - длина буфера
            jb .add

            cmp rdx, 0
            jne .buffer_flush

            ; buffer is empty && string is too large for buffer => print string by syscall without bufferization

            push rdi

            mov rdx, rcx                                ; rcx - length of string to print
            lea rsi, [rbx]
            mov rax, 0x01                               ; write64 (rdi, rsi, rdx) ... r10, r8, r9
            mov rdi, 1                                  ; stdout
            syscall

            xor rdx, rdx                                ; buffer is empty
            pop rdi
            jmp .EOF

.buffer_flush:
            push rdi

            ; rdx - length of string to print
            lea rsi, [rel printf_buffer]
            mov rax, 0x01                               ; write64 (rdi, rsi, rdx) ... r10, r8, r9
            mov rdi, 1                                  ; stdout
            syscall

            xor rdx, rdx                                ; buffer is empty
            pop rdi

            jmp add_to_buffer

.add:       mov al, [rbx]
            mov [rsi], al
            inc rbx
            inc rsi
            inc rdx

            loop .add
.EOF:
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

printf_args_jt:
    dd my_printf_FASTCALL.6args - my_printf_FASTCALL
    dd my_printf_FASTCALL.5args - my_printf_FASTCALL
    dd my_printf_FASTCALL.4args - my_printf_FASTCALL
    dd my_printf_FASTCALL.3args - my_printf_FASTCALL
    dd my_printf_FASTCALL.2args - my_printf_FASTCALL
    dd my_printf_FASTCALL.1args - my_printf_FASTCALL

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
