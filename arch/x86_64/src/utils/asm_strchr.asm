;---------------------------------------------------------------------
; vim:set expandtab:
;---------------------------------------------------------------------
; Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
;
; SPDX-License-Identifier: Apache-2.0
;---------------------------------------------------------------------

%include "header.inc"

global asm_strchr

extern asm_strlen

;---------------------------------------------------------------------
; Description: Search for the specified byte in the specified string.
;
; C prototype equivalent:
;
;     char *asm_strchr(const char *s, int c);
;
; Parameters:
;
; - Input: RDI (char *) - string.
; - Input: RSI (integer) - byte to search for.
; - Output: RAX (char *) - address of byte 'c' in string 's', or 0 if
;   not found.
;
; Notes:
;
; Limitations:
;
; See: strchr(3).
;---------------------------------------------------------------------

asm_strchr:
    prologue_with_vars 4

    ;--------------------
    ; Stack offsets.

    .string      equ     0   ; "char *"
    .byte        equ     8   ; char

    .len         equ    16   ; size_t
    .end         equ    24   ; "char *": Address of end of string.

    ;--------------------
    ; Checks

    cmp     rdi, 0
    je      .err_not_found

    ;--------------------
    ; Save args

    mov     [rsp+.string], rdi

    ; Save a single byte in the 64-bit space
    xor     rbx, rbx
    mov     bl, sil
    mov     [rsp+.byte], rbx

    ;--------------------

    xor     rcx, rcx

.loop:
    lea     rax, [rdi+rcx] ; Get address of byte
    mov     byte bl, [rax] ; Load byte

    cmp     bl, 0 ; Look for end of string
    jne     .not_end_of_string

    ; Got end of string. Since it is valid to search for the trailing
    ; nul byte ('\0'), we now need to check if that was the requested
    ; byte.

    cmp     byte [rsp+.byte], 0
    je      .out

    ; Requested byte was not 0, so fail.

    mov     rax, 0
    jmp     .out

.not_end_of_string:

    cmp     bl, [rsp+.byte] ; Look for requested byte
    jne     .no_match

    jmp     .out

.no_match:

    inc     rcx
    jmp     .loop

    ;--------------------

.out:
    epilogue_with_vars 4
    ret

.err_not_found:
    mov     rax, 0
    jmp     .out
