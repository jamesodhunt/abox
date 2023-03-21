;---------------------------------------------------------------------
; vim:set expandtab:
;---------------------------------------------------------------------
; Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
;
; SPDX-License-Identifier: Apache-2.0
;---------------------------------------------------------------------

%include "header.inc"

global asm_memcmp

;---------------------------------------------------------------------
; Description: .
;
; C prototype equivalent:
;
;     int asm_memcmp(const void *s1, const void *s2, size_t n);
;
; Parameters:
;
; - Input: RDI (integer) - 1st memory address.
; - Input: RSI (integer) - 2nd memory address.
; - Input: RDX (integer) - Number of bytes to consider.
; - Output: RAX (integer) - 0 on success, or -1 or +1 on error.
;
; Notes:
;
; Limitations:
;
; See:
;
;---------------------------------------------------------------------

asm_memcmp:
    prologue_with_vars 0

    mov     rcx, [rsp+rdx]

    cld     ; ensure we count "up"

    repe    cmpsb

    ; ZF should be set if the comparision was successful. If not, the
    ; strings differ.
    ;
    ; FIX ME: This seems wrong?
    jnz     .not_equal

    ; Now check to ensure we checked all the bytes requested.
    cmp     rcx, 0
    jne     .not_equal

    je      .equal

.not_equal:
    ; cmpsb always increments rdi and rsi. So if the values are
    ; different, we need to move back one byte to access the first
    ; differing bytes and calculate the difference between the
    ; differing bytes.
    ;
    ; Equivalent to the following C code:
    ;
    ;   int rax = *(rdi-1); /* get first differing byte in s1 */
    ;   int rcx = *(rsi-1); /* get first differing byte in s2 */
    ;   int result = rax - rcx;

    movzx   rax, byte [rdi-1]
    movzx   rcx, byte [rsi-1]
    sub     rax, rcx
    jmp     .out

.equal:
    xor     rax, rax
    jmp     .out

    ;--------------------

.out:
    epilogue_with_vars 0
    ret
