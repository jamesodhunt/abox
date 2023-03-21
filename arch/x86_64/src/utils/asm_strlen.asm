;---------------------------------------------------------------------
; vim:set expandtab:
;---------------------------------------------------------------------
; Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
;
; SPDX-License-Identifier: Apache-2.0
;---------------------------------------------------------------------

%include "header.inc"

global asm_strlen

;---------------------------------------------------------------------
; Description: Calculate length of null-terminated string (naïve version).
;
; C prototype equivalent:
;
;     size_t asm_strlen(const char *msg)
;
; Parameters:
;
; - Input: RDI - Address of string.
; - Output: RAX - Length of string.
;
; Notes: The specified address is assumed to actually _be_ a string:
; it must have a '\0' at the end. If this is not true, calling this
; function may result in a SIGSEGV.
;
; See: strlen(3).
;---------------------------------------------------------------------
asm_strlen:
    prologue_with_vars 0

    cmp     rdi, 0
    je      .str_is_null

    mov     rbx, rdi        ; save address of start of string for later

.next_char:
    cmp     byte [rdi], 0   ; found null byte?
    jz      .finished       ; yes!
    inc     rdi             ; no, so move along the string.
    jmp     .next_char

.finished:
    mov     rax, rdi        ; end of string address -> rax.
    sub     rax, rbx        ; string length = end - start

.out:
    epilogue_with_vars 0
    ret

.str_is_null:
    mov     rax, 0
    jmp     .out

