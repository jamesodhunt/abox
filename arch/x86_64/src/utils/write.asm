;---------------------------------------------------------------------
; vim:set expandtab:
;---------------------------------------------------------------------
; Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
;
; SPDX-License-Identifier: Apache-2.0
;---------------------------------------------------------------------

%include "header.inc"

global write_block

extern write

;---------------------------------------------------------------------
; Description: Write a block of data to the specified file descriptor
;   from the specified buffer.
;
;   This is a wrapper around write(2) that avoids the caller needing
;   to retry reading on EINTR or EAGAIN.
;
; C prototype equivalent:
;
;     ssize_t write_block(int fd, const void *buffer, size_t count);
;
; Parameters:
;
; - Input/Output: RDI (integer) - file descriptor.
; - Input: RSI (string) - "void *" / "char *" pointer.
; - Input: RDX (integer) - size of buffer.
; - Output: RAX (integer) - -1 on error, or bytes written on success.
;
; Notes:
;
; Limitations:
;
; See:
;---------------------------------------------------------------------

write_block:
    prologue_with_vars 5

    ;--------------------
    ; Stack offsets.

    .fd             equ     0   ; 32-bit int (but consuming 8 bytes).
    .buffer         equ     8   ; "void *"
    .count          equ     16  ; ssize_t

    .p              equ     24  ; "const void *" pointer.
    .bytes_written  equ     32  ; ssize_t

    ;------------------------------
    ; Save args

    mov     qword [rsp+.fd], 0 ; clear all 64-bits
    mov     [rsp+.fd], edi     ; copy 32-bits
    mov     [rsp+.buffer], rsi
    mov     [rsp+.count], rdx

    ;------------------------------
    ; Initialise

    ; bytes_written = 0
    mov     qword [rsp+.bytes_written], 0

    ; void *p = .buffer
    mov     [rsp+.p], rsi

    ;------------------------------
    ; Check args

    ; XXX: fd's are 32-bit signed values, hence edi, not rdi!
    cmp     edi, 0
    jl      .error

    cmp     rsi, 0
    je      .error

    cmp     rdx, 0   ; Do nothing, successfully.
    je      .success

    ;------------------------------

.write_again:
    mov     edi, [rsp+.fd]
    mov     rsi, [rsp+.p]
    mov     rdx, [rsp+.count]

    cmp     rdx, 0
    je      .success ; Nothing more to do

    dcall   write

    cmp     rax, 0 ; Check EOF
    je      .success
    jl      .check_write_error

    ; Write was successful

    add     [rsp+.bytes_written], rax   ; Save bytes count.
    add     [rsp+.p], rax          ; Move the pointer along the buffer.
    sub     [rsp+.count], rax      ; Update remaining bytes to handle.

    jmp     .write_again

.check_write_error:
    cmp     rax, EAGAIN
    je      .write_again
    cmp     rax, EINTR
    je      .write_again
    jmp     .error

.success:
    mov     rax, [rsp+.bytes_written]

.out:
    epilogue_with_vars 5
    ret

.error:
    mov     rax, -1
    jmp     .out
