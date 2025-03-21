section .text

global itoa
;========================================================================================================
;
; Entry:    rax - dec number to translate
; Exit:
; Dstr:     rax, rbx, rcx, rdx, rsi, rdi
;========================================================================================================
%macro itoa_macro 2
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

            mov ch, [rsi]
            inc rsi
            inc rsi

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

.loop_end:  lea rsi, [rel temp_buffer]
            inc rsi
            mov [rsi], ch

%endmacro


itoa:       lea rsi, [rel temp_buffer]
            mov al, 128
            mov [rsi], al
            mov rax, 31
            itoa_macro 1, 0x10000000

            mov rax, 0x01       ; write64 (rdi, rsi, rdx) ... r10, r8, r9
            mov rdi, 1          ; stdout
            lea rsi, [rel temp_buffer]
            inc rsi
            xor rdx, rdx
            mov dl, [rsi]        ; strlen (Msg)
            inc rsi
            syscall

            ret

section     .data

temp_buffer:    dq 0, 0, 0, 0, 0, 0, 0, 0


section     .rodata

digits_string:  db '0123456789ABCDEF'

section .note.GNU-stack noexec nowrite progbits
