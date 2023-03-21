;---------------------------------------------------------------------
; vim:set expandtab:
;---------------------------------------------------------------------
; Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
;
; SPDX-License-Identifier: Apache-2.0
;---------------------------------------------------------------------

global command_clear
global command_help_clear

extern close
extern write

section .rodata
command_help_clear: db  "see clear(1)",0

%include "header.inc"

section .text

;---------------------------------------------------------------------
;
;---------------------------------------------------------------------

command_clear:
section .rodata
    ; H: Goto (H)ome (top left).
    ; J: (J)ump to end of screen (bottom right).
    .clear_cmd      db   CONSOLE_ESC, "[H", CONSOLE_ESC, "[J"
    .clear_cmd_len  equ  $-.clear_cmd
section .text
    prologue_with_vars 0

    consume_program_name

    mov     rdi, STDOUT_FD
    mov     rsi, .clear_cmd
    mov     rdx, .clear_cmd_len

    dcall   write

    cmp     rax, -1
    je      .error

.success:
    mov     rax, CMD_OK

.out:
    epilogue_with_vars 0

    ret

.error:
    mov     rax, CMD_FAILED
    jmp     .out
