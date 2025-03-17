section .text

global _start                   ; predefined entry point name for ld

;========================================================================================================
;
; Entry:    rax - dec number to translate
; Exit:
; Dstr:     rax, rbx, rcx, rdx, rsi, rdi
;========================================================================================================
%macro itoa_bin 2
            mov rsi, temp_buffer
            mov rdi, digits_string
            mov cl, [rsi]
            inc rsi
            inc rsi
            xor ch, ch

.loop       cmp ch, cl
            je .loop_end

            cmp rax, 0
            je .loop_end

            mov rbx, rax
            and rbx, %2

            mov dl, [rdi, rbx]
            mov [rsi], byte dl
            inc rsi

            shr rax, %1
            inc ch

            jmp .loop

.loop_end   mov rsi, temp_buffer
            inc rsi
            mov [rsi], ch

%endmacro

_start:     mov rsi, temp_buffer
            mov al, 128
            mov [rsi], al
            mov rax, 31
            itoa_bin 4, 15

            mov rax, 0x01       ; write64 (rdi, rsi, rdx) ... r10, r8, r9
            mov rdi, 1          ; stdout
            mov rsi, temp_buffer
            inc rsi
            xor rdx, rdx
            mov dl, [rsi]        ; strlen (Msg)
            inc rsi
            syscall

            mov rax, 0x3C       ; exit64 (rdi)
            xor rdi, rdi
            syscall


section     .data

temp_buffer:    dq 0, 0, 0, 0, 0, 0, 0, 0


section     .rodata

digits_string:  db '0123456789ABCDEF'
