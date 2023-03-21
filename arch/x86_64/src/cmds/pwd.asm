;---------------------------------------------------------------------
; vim:set expandtab:
;---------------------------------------------------------------------
; Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
;
; SPDX-License-Identifier: Apache-2.0
;---------------------------------------------------------------------

global command_help_pwd
global command_pwd

extern free
extern write

extern asm_strlen
extern get_current_dir_name
extern print_nl

section .rodata
command_help_pwd:  db  "see pwd(1)",0

%include "header.inc"

section .text

;---------------------------------------------------------------------
;
;---------------------------------------------------------------------

command_pwd:
    prologue_with_vars 2

    ;--------------------
    ; Stack offsets

    .cwd        equ     0   ; "char *"
    .len        equ     8   ; size_t

    ;--------------------

    consume_program_name

    dcall   get_current_dir_name
    cmp     rax, 0
    je      .error

    mov     [rsp+.cwd], rax ; Save path

    mov     rdi, rax
    dcall   asm_strlen

    mov     [rsp+.len], rax ; Save length

    mov     rdi, STDOUT_FD
    mov     rsi, [rsp+.cwd]
    mov     rdx, [rsp+.len]
    dcall   write

    dcall   print_nl

    mov     rdi, [rsp+.cwd]
    dcall   free

.success:
    mov     rax, CMD_OK

.out:
    epilogue_with_vars 2

    ret

.error:
    mov     rax, CMD_FAILED
    jmp     .out
