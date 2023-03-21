;---------------------------------------------------------------------
; vim:set expandtab:
;---------------------------------------------------------------------
; Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
;
; SPDX-License-Identifier: Apache-2.0
;---------------------------------------------------------------------

global command_false
global command_help_false

%include "header.inc"

extern exit

section .rodata
command_help_false:  db  "see false(1)",0

section .text

;---------------------------------------------------------------------
; This command is the odd one out - we can't return success to the
; caller and then make the caller return 1, so just short-circuit the
; problem ;)
;---------------------------------------------------------------------
command_false:
    prologue_with_vars 0

.out:
    mov     rdi, EXIT_FAILURE
    dcall   exit

    epilogue_with_vars 0

    ret
