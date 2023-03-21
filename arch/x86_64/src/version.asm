;---------------------------------------------------------------------
; vim:set expandtab:
;---------------------------------------------------------------------
; Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
;
; SPDX-License-Identifier: Apache-2.0
;---------------------------------------------------------------------

global show_version
global handle_version

extern version
extern multicall_name

extern printf
extern strcmp

%include "header.inc"

;---------------------------------------------------------------------
; Description: Handle the version options.
;
; C prototype equivalent:
;
;     int handle_version(const char *argv1);
;
; Parameters:
;
; - Input: RDI (address) - address of first actual string argument
;   (which might be a short or long version option).
; - Output: RAX (integer) - 0 on success (denoting that the string argument
;   was a version option), -1 on error.
;
; Notes:
;
; On success show_version() will have been called so the caller of
; this function can immediately exit.
;---------------------------------------------------------------------

handle_version:
section .rodata
    .short_version_opt      equ '-v'
    .long_version_opt       db  "--version",0
section .text
    prologue_with_vars 0

    ; Load the *value* of the argument.
    mov     rbx, [rdi]

    ; Check if it's the short option.
    cmp     bx, .short_version_opt

    je      .show_version

    ; Not a short option so check if the long option
    ; equivalent was specified.

.try_long_opt:
    mov     rsi, .long_version_opt
    dcall   strcmp
    jz      .show_version

    mov     rax, -1 ; Failure.

.out:
    epilogue_with_vars 0

    ret

.show_version:
    dcall    show_version
    mov      rax, CMD_OK
    jmp      .out

;---------------------------------------------------------------------
; Description: Show the version string.
;
; C prototype equivalent:
;
;     void show_version();
;
; Parameters: none.
;---------------------------------------------------------------------

show_version:
section .rodata
    .fmt               db  "%s version %s",10,0
section .text
    prologue_with_vars 0

    mov     rdi, .fmt
    mov     rsi, multicall_name
    mov     rdx, version

    xor     rax, rax
    dcall   printf

.out:
    epilogue_with_vars 0

    ret
