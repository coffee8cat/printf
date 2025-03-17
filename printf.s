; nasm -f elf64 -l 1-nasm.lst 1-nasm.s  ;  ld -s -o 1-nasm 1-nasm.o

section .text

global _start                   ; predefined entry point name for ld

_start:     mov rax, 0x01       ; write64 (rdi, rsi, rdx) ... r10, r8, r9
            mov rdi, 1          ; stdout
            mov rsi, Msg
            mov rdx, MsgLen     ; strlen (Msg)
            syscall

            call my_printf

            mov rax, 0x3C       ; exit64 (rdi)
            xor rdi, rdi
            syscall

;========================================================================================================
;========================================================================================================
my_printf:  pop rsi             ; assuming last pushed arg is a format string
            mov rdi, printf_buffer
.loop
            cmp [rsi], '%'
            je  @@specification_switch

            mov eax, [rsi]
            mov [rdi], eax
            inc rdi
            inc rsi
            jmp .loop

.specification_switch
            inc rsi
            cmp [rsi], '%'
            je  .perc                   ; in this case '%' will be added to buff

            call getarg

            mov rax, [rsi]
            sub rax, 'b'                ; sub 'b'
            cmp rax, 'x' - 'b'
            ja  .default
            jmp .spec_jt(, rax, 8)

.perc       mov byte ptr eax, '%'
            mov byte ptr [rdi], eax
            inc rdi
            jmp .loop

.bin        call d2bin
            jmp .switch_end

.char
            jmp .switch_end
.dec
            jmp .switch_end

.oct        call d2oct
            jmp .switch_end

.str
            jmp .switch_end

.hex        call d2hex
            jmp .switch_end

.default

.switch_end call add_to_buffer
            jmp .loop

            ret

;========================================================================================================
; adds to buffer bytes of rbx starting from the highest until zero byte is met
; Entry:    rbx - string for adding to buffer
;           rdi - pointer to buffer
; Exit:     None
; Dstr:     rbx
;========================================================================================================
add_to_buffer:
            mov cl, 8
            xor ch, ch

.loop       cmp cl, ch
            je .loop_end

            cmp bl, ch
            je .loop_end

            mov [rdi], bl
            inc rdi
            shl rbx, 8

            dec cl

.loop_end
            ret

;========================================================================================================
;
; Entry: rax - dec number to translate
; Exit:
; Dstr:
;========================================================================================================
itoa_bin:
            mov rsi, temp_buffer
            mov byte ptr cl, [rsi]
            xor ch, ch

.loop
            cmp ch, cl
            je .loop_end

            mov rbx, rax
            and rbx, 10000000
            shr rbx, 1
            shl rbx, 1
            sub rax, rbx

            add rax, '0'
            mov [rsi], rax
            inc rsi

            mov rax, rbx
            shr rax, 1

            inc ch
.loop_end
            mov rsi, temp_buffer
            inc rsi
            mov byte ptr [rsi], ch
            ret

section     .data

printf_buffer:  dq 0, 0, 0, 0, 0, 0, 0, 0
temp_buffer:    dq 0, 0, 0, 0, 0, 0, 0, 0

section     .rodata

.spec_jt:
    .quad   .bin
    .quad   .char
    .quad   .dec
    .quad   0
    .quad   0
    .quad   0
    .quad   0
    .quad   0
    .quad   0
    .quad   0
    .quad   0
    .quad   0
    .quad   0
    .quad   .oct
    .quad   0
    .quad   0
    .quad   0
    .quad   .str
    .quad   0
    .quad   0
    .quad   0
    .quad   0
    .quad   .hex
