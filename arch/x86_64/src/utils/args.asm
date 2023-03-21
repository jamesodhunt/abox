;---------------------------------------------------------------------
; vim:set expandtab:
;---------------------------------------------------------------------
; Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
;
; SPDX-License-Identifier: Apache-2.0
;---------------------------------------------------------------------

%include "header.inc"

global alloc_args_buffer
global argv_bytes

extern asm_strlen

extern calloc
extern stpcpy

;---------------------------------------------------------------------
; Description: Count total number of bytes in argv array.
;
; C prototype equivalent:
;
;     size_t argv_bytes(int argc, const char *argv[]);
;
; Parameters:
;
; - Input: RDI (integer) - argc: number of actual arguments (excluding
;     the program name!).
; - Input: RSI (address) - argv.
; - Output: RAX (integer) - Total number of bytes in argv.
;
; Notes: Null bytes at the end of each argv element are not included
;   in the count.
; WARNING: The value returned does *not* include space for the
; terminating null byte ('\0')!
;---------------------------------------------------------------------
argv_bytes:
    prologue_with_vars 3

    ;--------------------
    ; Stack offsets.

    .argc       equ     0   ; size_t.
    .argv       equ     8   ; "char **"
    .bytes      equ     16  ; size_t.

    ;--------------------

    ; Save args
    mov     [rsp+.argc], rdi
    mov     [rsp+.argv], rsi

    ; Intialise bytes
    mov     qword [rsp+.bytes], 0

.next_arg:
    cmp     qword [rsp+.argc], 0
    je      .done

.count_arg_bytes:
    mov     rax, [rsp+.argv]
    mov     rdi, [rax]
    dcall   asm_strlen

    ; bytes += rax
    add     [rsp+.bytes], rax

    dec     qword [rsp+.argc]     ; argc--
    add     qword [rsp+.argv], 8  ; argv++

    jmp     .next_arg

.done:
    ; Return the byte count.
    mov     rax, [rsp+.bytes]

.out:
    epilogue_with_vars 3

    ret

;---------------------------------------------------------------------
; Description: Allocate space for the specified args, write the args
;   into the buffer (with a space character between each arg and a
;   newline character at the end) and return a pointer to it.
;
; C prototype equivalent:
;
;     void *alloc_args_buffer(int argc, char *argv[], size_t *bytes);
;
; Parameters:
;
; - Input: RDI (integer) - argc.
; - Input: RSI (address) - argv.
; - Input+Output: RDX (integer) - Number of bytes in argv args
;     (including the terminator).
; - Output: RAX (address) - Address of allocated buffer on success,
;     or 0 on error.
;
; Notes:
;
; - The caller is responsible for freeing the allocated bytes.
; - On success, the RDX register will contain an updated count of the
;   number of bytes in the returned buffer (including the separator
;   characters and the newline character (but not the trailing null
;   terminator (`\0`)).
;---------------------------------------------------------------------

; aka "args_to_string"
alloc_args_buffer:
    prologue_with_vars 5

    ;--------------------
    ; Stack offsets.

    ; variables for args.
    .argc       equ     0   ; size_t.
    .argv       equ     8   ; "char **"
    .bytes      equ     16  ; "size_t *".

    ; variables
    .buf        equ     24  ; "char *": dynamically allocated buffer.
    .p          equ     32  ; "char *": pointer into buf.

    ;--------------------
    ; separator character

    .sep        equ     ' '

    ;--------------------

    cmp     rdi, 0
    je      .error ; No args to save

    ; The amount of space required for the buffer is made up of the
    ; following components:
    ;
    ; (1) The byte count specified to this function in RDX.
    ; (2) The space for a 1 byte separator between each argument.
    ; (3) The space for a newline character after the final arg.
    ; (4) The space for a trailing null byte (`\0`) terminator.
    ;
    ; The number of separator bytes is obviously one less than the
    ; number of arguments (aka argc-1). However, conveniently,
    ; since we also need a newline char and a null terminator byte,
    ; the number of bytes required is:
    ;
    ; (1) = RDX (total bytes used in original argv vector).
    ; (2) = (argc-1).
    ; (3) = 1.
    ; (4) = 1.
    ;
    ; Hence, total bytes required = RDX   + (argc-1) + 1 + 1
    ;                             = RDX   + (argc-1+1) + 1
    ;                             = RDX   +  argc + 1
    ;                             = RDX   +  RDI  + 1
    ;                             = bytes +  argc + 1
    ;
    ; However, although the trailing null byte is required, it doesn't
    ; form part of the returned length (to be compatible with
    ; strlen(3), hence the actual total bytes returned by this
    ; function via RDX is:
    ;
    ; Hence, bytes returned       = (1)   + (2)      + (3)
    ;                             = RDX   + (argc-1) + 1
    ;                             = RDX   + RDI-1    + 1
    ;                             = RDX   + RDI
    ;                             = bytes + argc

    ;------------------------------
    ; Save args

    mov     [rsp+.argc], rdi
    mov     [rsp+.argv], rsi
    mov     [rsp+.bytes], rdx

    ;------------------------------
    ; Allocate buffer space.
    ; Calculate total bytes required.

    mov     rax, [rsp+.bytes]
    mov     rdi, [rax] ; Dereference int pointer.
    cmp     rdi, 0

    ; There are two possibilities:
    ;
    ; - All argv elements are NULL
    ;   (aka argc is wrong as it should be zero!).
    ; - All argv elements are set to "\0"
    ;   (more likely).
    je     .error

    add     rdi, [rsp+.argc]

    ; Update bytes count value returned to caller.
    mov     [rax], rdi

    inc     rdi ; Now, add space for the terminating byte.

    mov     rsi, 1 ; sizeof(char)
    dcall   calloc
    cmp     rax, 0
    je      .error

    mov     [rsp+.buf], rax ; Save address.
    mov     [rsp+.p], rax   ; Set p = address.

    ; Fill the buffer with spaces. This is inefficient as we
    ; only need a single space between each arg,
    ; but it keeps the logic simple.
    mov     eax, .sep

    mov     rax, [rsp+.bytes]
    mov     rcx, [rax] ; Dereference int pointer.

    ; Reduce the byte count to avoid overwriting the newline and
    ; the terminating null.
    sub     rcx, 2

    mov     rdi, [rsp+.p]
    rep     stosb

.next_arg:
    cmp     qword [rsp+.argc], 0 ; Any arguments remaining?
    je      .done  ; No, so exit.

    ; Set destination
    mov     rdi, [rsp+.p]

    ; Get next argv[n] value.
    mov     rax, [rsp+.argv]

    ; Set source
    mov     rsi, [rax]

    ; Copy the argument string from argv into the buffer
    ; that we've filled with spaces.
    dcall    stpcpy

    ; Overwrite the null with the separator.
    mov     byte [rax], .sep
    inc     rax ; Jump over the separator.

    ;------------------------------
    ; Update values

    ; stpcpy(3) returns the address of the trailing nul terminator,
    ; so set the pointer, to that value to move along the buffer.
    mov     [rsp+.p], rax

    dec     qword [rsp+.argc]     ; argc--
    add     qword [rsp+.argv], 8  ; argv++

    jmp     .next_arg

.done:
    ; Overwrite the final trailing separator char with a newline.
    mov     rax, [rsp+.p]
    dec     rax
    mov     byte [rax], NL

    mov     rdx, [rsp+.bytes]; Return total bytes through param.
    mov     rax, [rsp+.buf] ; Return address of buffer.

.out:
    epilogue_with_vars 5
    ret

.error:
    mov     rax, 0
    jmp     .out
