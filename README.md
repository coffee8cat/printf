# My Printf

It is an simplified implementation of standard C functioin - printf. My version has 7 format specifiers:
| Format specifier | Argument | Output format |
|------------------|----------|---------------|
| %x | 32-bit unsigned integer | Unsigned hexadecimal integer; uses "ABCDEF" |
| %o | 32-bit unsigned integer | Unsigned octal integer |
| %b | 32-bit unsigned integer | Unsigned binary integer |
| %d | 32-bit signed integer | Signed decimal integer |
| %s | pointer to a string  ending with zero byte | Specifies a single-byte character string |
| %c | char (1 byte) | specifies a single-byte (ASCII) charactar|
| %% | None | prints '%' |

This version uses **lazy buffering** - the buffer is flushed only when:
 - Explicitly calling fflush(stdout).
 - The buffer is full (for blocking buffers).
 - The program terminates (exit() or main returns).

My printf implementation uses the System V ABI calling convention for Linux:

- The first 6 arguments are passed via registers (RDI, RSI, RDX, RCX, R8, R9 for integers/pointers).

 - Additional arguments are pushed onto the stack (right-to-left order).

 - Preserves the values of EBX, ESI, EDI, and EBP (non-volatile registers).

 - Returns the result via EAX.

 - Cleans up its own stack arguments upon return.
