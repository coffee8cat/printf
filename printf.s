; nasm -f elf64 -l 1-nasm.lst 1-nasm.s  ;  ld -s -o 1-nasm 1-nasm.o
section .note.GNU-stack noexec nowrite progbits

section .text

global my_printf
global my_printf_FASTCALL
global atexit_printf_buffer_flush

%macro printf_buffer_flush 0

            push rdi

            mov rax, 0x01                               ; write64 (rdi, rsi, rdx) ... r10, r8, r9
            mov rdi, 1                                  ; stdout
            lea rsi, [rel printf_buffer]
            syscall

            xor rdx, rdx
            pop rdi

%endmacro

;========================================================================================================
; Entry:    params in stack: format string and args
; Exit:     rdx - number of characters printed
; Dstr:     rax, rbx, rcx, rdx, rsi, rdi
;========================================================================================================
my_printf:  ; in this function the following registered used for
            ; rdi - adress of format string
            ; rsi - pointer to first free byte in buffer
            ; rdx - counter of bytes written in buffer
            ; rcx - end of format string - for end condition of while

            call prepare_for_processing
.while:
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
            call process_bin_spec
            jmp .switch_end

.chr_spec:  pop rax                         ; getarg
            mov [rsi], al
            inc rsi
            inc rdx
            jmp .switch_end

.dec_spec:  pop rax
            call process_dec_spec
            jmp .switch_end

.oct_spec:  pop rax                         ; getarg for itoa
            call process_oct_spec
            jmp .switch_end

.str_spec:  pop rbx                         ; getarg - pointer to a string
            call process_str_spec
            jmp .switch_end

.hex_spec:  pop rax                         ; getarg for itoa
            call process_hex_spec
            jmp .switch_end

.default:   call show_default_opt_error_message; error message

.switch_end:

            inc rdi
            jmp .while

.printf_end:

            call prepare_for_end
            ret

;========================================================================================================
; adds to buffer bytes of rbx starting from the highest until zero byte is met
; Entry:    rbx - pointer to a string for adding to buffer
;           rcx - length of string
; Exit:     None
; Dstr:     rax, rbx, rdx, rsi
;========================================================================================================
prepare_for_processing:
            pop rbx                         ; save ret adress for prepare_for_processing

            lea rsi, [rel printf_ret_address]
            pop rax                         ; save ret adress for printf_FASTCALL
            mov qword [rsi], rax

            xor rdx, rdx
            lea rsi, [rel printf_result]
            mov dword [rsi], edx

            lea rsi, [rel printf_buffer_charge]
            mov dl, [rsi]                   ; load number of bytes in buffer

            lea rsi, [rel printf_buffer]
            add rsi, rdx

            pop rdi                         ; assuming last pushed arg is a format string
            call strlen                     ; rcx = strlen(rdi)
            add rcx, rdi                    ; rcx = end of format string

            push rbx                        ; restore ret adress for prepare_for_processing
            ret

;========================================================================================================
; adds to buffer bytes of rbx starting from the highest until zero byte is met
; Entry:    rbx - pointer to a string for adding to buffer
;           rcx - length of string
; Exit:     None
; Dstr:     rax, rbx, rdx, rsi
;========================================================================================================
prepare_for_end:
            pop rbx                                     ; save ret adress for prepare_for_end
            lea rsi, [rel printf_ret_address]
            mov rax, qword [rsi]
            push rax                                    ; restore ret adress for printf
            push rbx                                    ; restore ret adress for prepare_for_end

            lea rsi, [rel printf_buffer_charge]         ; save number of bytes in buffer for atexit or further calls
            mov dh, [rsi]                               ; dh = buffer_charge
            mov [rsi], dl                               ; buffer_charge = dl
            sub dl, dh                                  ; dl = dh -dl
            xor dh, dh

            lea rsi, [rel printf_result]                ; update printf result
            mov eax, dword [rsi]                        ; load result value
            add eax, edx                                ; add num of bytes written in buffer, but not flushed yet

            lea rsi, [rel rbx_saved]                    ; load saved rbx, rsi, rdi for FASTCALL compatability
            mov rbx, [rsi]

            lea rsi, [rel rdi_saved]
            mov rdi, [rsi]

            lea rsi, [rel rsi_saved]
            mov rsi, [rsi]

            ret

;========================================================================================================
; adds to buffer bytes of rbx starting from the highest until zero byte is met
; Entry:    rbx - pointer to a string for adding to buffer
;           rcx - length of string
; Exit:     None
; Dstr:     rax, rbx, rdx, rsi
;========================================================================================================
process_bin_spec:
            push rcx
            push rdi
            push rdx
            call itoa_bin
            pop rdx
            pop rdi

            lea rbx, [rsi]
            call add_to_buffer
            pop rcx

            ret

;========================================================================================================
; adds to buffer bytes of rbx starting from the highest until zero byte is met
; Entry:    rbx - pointer to a string for adding to buffer
;           rcx - length of string
; Exit:     None
; Dstr:     rax, rbx, rdx, rsi
;========================================================================================================
process_oct_spec:
            push rcx
            push rdi
            push rdx
            call itoa_oct
            pop rdx
            pop rdi

            lea rbx, [rsi]
            call add_to_buffer
            pop rcx

            ret

;========================================================================================================
; adds to buffer bytes of rbx starting from the highest until zero byte is met
; Entry:    rbx - pointer to a string for adding to buffer
;           rcx - length of string
; Exit:     None
; Dstr:     rax, rbx, rdx, rsi
;========================================================================================================
process_dec_spec:
            push rcx
            push rdi
            push rdx
            call itoa_dec
            pop rdx
            pop rdi

            lea rbx, [rsi]
            call add_to_buffer
            pop rcx

            ret

;========================================================================================================
; adds to buffer bytes of rbx starting from the highest until zero byte is met
; Entry:    rbx - pointer to a string for adding to buffer
;           rcx - length of string
; Exit:     None
; Dstr:     rax, rbx, rdx, rsi
;========================================================================================================
process_str_spec:
            push rcx
            push rdi

            lea rdi, [rbx]
            call strlen                     ; rcx = strlen(rbx)

            pop rdi
            call add_to_buffer
            pop rcx

            ret

;========================================================================================================
; adds to buffer bytes of rbx starting from the highest until zero byte is met
; Entry:    rbx - pointer to a string for adding to buffer
;           rcx - length of string
; Exit:     None
; Dstr:     rax, rbx, rdx, rsi
;========================================================================================================
process_hex_spec:
            push rcx
            push rdi
            push rdx
            call itoa_hex
            pop rdx
            pop rdi

            lea rbx, [rsi]
            call add_to_buffer
            pop rcx

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
            call buffer_flush
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
; adds to buffer bytes of rbx starting from the highest until zero byte is met
; Entry:    rbx - pointer to a string for adding to buffer
;           rcx - length of string
; Exit:     None
; Dstr:     rax, rbx, rdx, rsi
;========================================================================================================
buffer_flush:
            push rdi

            ; rdx - length of string to print
            push rdx
            lea rsi, [rel printf_buffer]
            mov rax, 0x01                               ; write64 (rdi, rsi, rdx) ... r10, r8, r9
            mov rdi, 1                                  ; stdout
            syscall
            pop rdx
            pop rdi

            push rsi
            push rax

            lea rsi, [rel printf_buffer_charge]         ; buffer could be filled after previous printf
            mov dh, [rsi]
            sub dl, dh
            xor dh, dh
            mov [rsi], dh                               ; buffer charge will be 0 after flush

            lea rsi, [rel printf_result]                ; update printf result
            mov eax, dword [rsi]
            add eax, edx
            mov [rsi], eax

            pop rax
            pop rsi

            xor rdx, rdx                                ; buffer is empty

            ret

;========================================================================================================
; adds to buffer bytes of rbx starting from the highest until zero byte is met
; Entry:    rbx - pointer to a string for adding to buffer
;           rcx - length of string
; Exit:     None
; Dstr:     rax, rbx, rdx, rsi
;========================================================================================================
atexit_printf_buffer_flush:

            mov rax, 0x01                               ; write64 (rdi, rsi, rdx) ... r10, r8, r9
            mov rdi, 1                                  ; stdout
            lea rsi, [rel printf_buffer]
            movzx rdx, byte [rel printf_buffer_charge]
            syscall

            ret

;========================================================================================================
;========================================================================================================
my_printf_FASTCALL:

            push rsi
            mov rax, rsi                            ; save rbx, rsi, rdi for FASTCALL compatability
            lea rsi, [rel rsi_saved]
            mov qword[rsi], rax

            lea rsi, [rel rbx_saved]
            mov qword[rsi], rbx

            lea rsi, [rel rdi_saved]
            mov qword[rsi], rdi
            pop rsi

            push rdi
            call count_printf_specificators
            pop rdi

            pop rbx                                 ; save ret adress

            ; rax = al for this moment
            mov ah, 5
            cmp al, ah
            ja .6args

            sub al, ah
            neg al                                 ; al = 5 - al
            xor ah, ah

            push rbx
            lea rbx, [rel printf_args_jt]          ; load switch option
            mov eax, [rbx + rax * 4]
            lea rbx, [rel my_printf_FASTCALL]
            lea rax, [rbx + rax]
            pop rbx
            jmp rax

.6args:     push r9
.5args:     push r8
.4args:     push rcx
.3args:     push rdx
.2args:     push rsi
.1args:     push rdi

            push rbx                                ; restore ret adress
            jmp my_printf

;========================================================================================================
; Entry:    rdi - format string for printf
; Exit:     rax - numbet of specificators in format string
; Dstr:     rax, rbx, rdi
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
; Returns length of the string ending with zero byte
; Entry:    rdi - pointer to a string
; Exit:     rcx - length of the string
; Dstr:     al, rcx
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

;========================================================================================================
; Translates number to 2-degree based system and saves to temp_buffer in direct order
; Entry:    rax - dec number to translate
; Exit:     rcx - length of string containig translated number
; Dstr:     rax, rbx, rcx, rdx, rsi, rdi
;========================================================================================================
%macro itoa 2
            lea rsi, [rel temp_buffer + buffer_size - 1]
            lea rdi, [rel digits_string]
            mov rcx, %2
            xor rdx, rdx

.loop:      test rax, rax
            jz .loop_end

            mov rbx, rax
            and rbx, rcx

            mov bl, [rdi, rbx]
            mov [rsi], byte bl

            dec rsi
            inc dl
            shr rax, %1
            jmp .loop

.loop_end:  inc rsi
            mov rcx, rdx

%endmacro

itoa_bin:   itoa 1, 1
            ret

itoa_oct:   itoa 3, 7
            ret

itoa_hex:   itoa 4, 15
            ret

;========================================================================================================
;
; Entry:    rax - dec number to translate
; Exit:
; Dstr:     rax, rbx, rcx, rdx, rsi, rdi
;========================================================================================================
itoa_dec:
            ; 0x80000000 - sign bit mask for int
            xor rbx, rbx
            mov rcx, 0x80000000
            mov rdx, rax
            and rdx, rcx
            test rdx, rdx
            jz .positive

            inc bh                                  ; for adding minus at the end
            not rcx                                 ; rax = - rax
            neg rax
            and rax, rcx
            mov eax, eax

.positive:  lea rsi, [rel temp_buffer + buffer_size - 1]
            lea rdi, [rel digits_string]
            mov rcx, 10

.loop:      test eax, eax
            jz .loop_end

            xor rdx, rdx
            div rcx                 ; rax = rax // 10, rdx = rax % 10

            mov dl, [rdi, rdx]
            mov [rsi], byte dl

            dec rsi
            inc bl
            jmp .loop

.loop_end:  test bh, bh
            jz .no_minus

            mov dl, '-'
            mov [rsi], byte dl
            dec rsi
            inc bl
            xor bh, bh

.no_minus:  mov rcx, rbx
            inc rsi

            ret

;========================================================================================================
; Translates number to 2-degree based system and saves to temp_buffer in direct order
; Entry:    rax - dec number to translate
; Exit:     rax - length of string containig translated number
; Dstr:     rax, rbx, rcx, rdx, rsi, rdi
;========================================================================================================
show_default_opt_error_message:
            push rsi
            push rdi
            push rdx
            push rax
            push rcx

            mov rdx, def_opt_mess_length
            lea rsi, [rel default_opt_message]
            mov rax, 0x01                               ; write64 (rdi, rsi, rdx) ... r10, r8, r9
            mov rdi, 1                                  ; stdout
            syscall

            pop rcx
            pop rax
            pop rdx
            pop rdi
            pop rsi
            ret

section     .data

rbx_saved: dq 0
rdi_saved: dq 0
rsi_saved: dq 0

printf_ret_address: dq 0
printf_result:  dd 0
printf_buffer_charge:   db 0
buffer_size     equ 255

section .bss

printf_buffer   resb buffer_size
temp_buffer     resb buffer_size

section     .rodata

default_opt_message: db '!DEFAULT OPTION REACHED! Specification ignored', 0Ah, 0Dh, 0Ah, 0Dh
def_opt_mess_length  equ $ - default_opt_message
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
