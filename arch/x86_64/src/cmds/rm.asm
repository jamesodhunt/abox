;---------------------------------------------------------------------
; vim:set expandtab:
;---------------------------------------------------------------------
; Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
;
; SPDX-License-Identifier: Apache-2.0
;---------------------------------------------------------------------

global command_help_rm
global command_rm

extern unlink

section .rodata
command_help_rm:   db  "see rm(1)",0

%include "header.inc"

section .text

;---------------------------------------------------------------------
;
;---------------------------------------------------------------------

command_rm:
section .text
    prologue_with_vars 2

    ;--------------------
    ; Stack offsets.

    .argc       equ     0   ; size_t.
    .argv       equ     8   ; "char **"

    ;--------------------
    ; Setup

    consume_program_name

    ;--------------------
    ; Save args

    mov     [rsp+.argc], rdi
    mov     [rsp+.argv], rsi

    ;--------------------

    cmp     rdi, 0
    je      .err_no_arg

.next_file:
    mov     rdi, [rsi] ; Grab the next filename.

    dcall   unlink
    cmp     rax, 0
    jne     .error

    ; Update on the stack
    add     qword [rsp+.argv], 8 ; argv++
    dec     qword [rsp+.argc]    ; argc--

    ; Reload the values
    mov     rdi, [rsp+.argc]
    mov     rsi, [rsp+.argv]

    cmp     rdi, 0
    je      .success
    jmp     .next_file

.success:
    mov     rax, CMD_OK

.out:
    epilogue_with_vars 2

    ret

.error:
    mov     rax, CMD_FAILED
    jmp     .out

.err_no_arg:
    mov     rax, CMD_NO_ARG
    jmp     .out

