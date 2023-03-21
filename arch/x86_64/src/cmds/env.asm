;---------------------------------------------------------------------
; vim:set expandtab:
;---------------------------------------------------------------------
; Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
;
; SPDX-License-Identifier: Apache-2.0
;---------------------------------------------------------------------

global command_help_env
global command_env

extern abox_environ
extern puts

section .rodata
command_help_env:  db  "see env(1)",0

%include "header.inc"

section .text

;---------------------------------------------------------------------
;
;---------------------------------------------------------------------

command_env:
    prologue_with_vars 1

    ;--------------------
    ; Stack offsets.

    .p          equ     0   ; "char **"

    ; Read the "char **" value from the variable.
    mov     rax, [abox_environ]

    ; Get the 1st string pointer
    mov     [rsp+.p], rax

.next_env_var:

    ; Check if we're at the end of the env block.
    cmp     qword [rsp+.p], 0
    je      .out

    mov     rax, [rsp+.p]

    ; Deference to access the "char *" value.
    mov     rdi, [rax]

    cmp     rdi, 0
    je      .out

    dcall   puts

    ; Move to the next variable
    add     qword [rsp+.p], 8

    jmp     .next_env_var

.out:
    mov     rax, CMD_OK

    epilogue_with_vars 1
    ret
