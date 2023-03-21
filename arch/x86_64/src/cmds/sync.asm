;---------------------------------------------------------------------
; vim:set expandtab:
;---------------------------------------------------------------------
; Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
;
; SPDX-License-Identifier: Apache-2.0
;---------------------------------------------------------------------

global command_help_sync
global command_sync

extern sync

section .rodata
command_help_sync:  db  "see sync(1)",0

%include "header.inc"

section .text

;---------------------------------------------------------------------
;
;---------------------------------------------------------------------

command_sync:
    prologue_with_vars 0

    dcall  sync

.out:
    epilogue_with_vars 0

    ; sync(2) cannot fail
    mov    rax, CMD_OK

    ret
