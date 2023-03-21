;---------------------------------------------------------------------
; vim:set expandtab:
;---------------------------------------------------------------------
; Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
;
; SPDX-License-Identifier: Apache-2.0
;---------------------------------------------------------------------

global command_help_echo
global command_echo

extern free
extern write

extern alloc_args_buffer
extern argv_bytes
extern print_nl

%include "header.inc"

section .rodata
command_help_echo:  db  "see echo(1)",0

section .text

command_echo:
    prologue_with_vars 4

    ;--------------------
    ; Stack offsets

    .argc       equ     0   ; size_t.
    .argv       equ     8   ; "char **"

    .bytes      equ     16  ; size_t: Number of bytes to display.
    .buf        equ     24  ; "char *"

    ;--------------------

    consume_program_name

    cmp     rdi, 0
    je     .show_blank_line

    ; Save arguments
    mov     [rsp+.argc], rdi
    mov     [rsp+.argv], rsi

    dcall    argv_bytes

    cmp     rax, 0
    je      .show_blank_line

    ; Save byte count
    mov     [rsp+.bytes], rax

    ; Allocate a buffer for the args and write them into it.
    mov     rdi, [rsp+.argc]
    mov     rsi, [rsp+.argv]

    ; Put *address* of .bytes into register.
    lea     rdx, [rsp+.bytes]

    dcall   alloc_args_buffer

    cmp     rax, 0
    je      .error

    ; Save allocated args buffer data
    mov     [rsp+.buf], rax

    ; Display allocated buffer
    mov     rdi, STDOUT_FD
    mov     rsi, [rsp+.buf]
    mov     rdx, [rsp+.bytes]
    dcall    write

    mov     rdi, [rsp+.buf]
    dcall   free

    mov     rax, CMD_OK
    jmp     .done

.show_blank_line:
    dcall   print_nl

    mov     rax, CMD_OK

.done:
    epilogue_with_vars 4

    ret

.error:
    mov     rax, CMD_FAILED
    jmp     .done
