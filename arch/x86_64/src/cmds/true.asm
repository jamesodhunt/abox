;---------------------------------------------------------------------
; vim:set expandtab:
;---------------------------------------------------------------------
; Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
;
; SPDX-License-Identifier: Apache-2.0
;---------------------------------------------------------------------

global command_true
global command_help_true

%include "header.inc"

extern exit

section .rodata
command_help_true:  db  "see true(1)",0

section .text

command_true:
    prologue_with_vars 0

.out:
    mov    rax, EXIT_SUCCESS

    epilogue_with_vars 0

    ret
