;---------------------------------------------------------------------
; vim:set expandtab:
;---------------------------------------------------------------------
; Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
;
; SPDX-License-Identifier: Apache-2.0
;---------------------------------------------------------------------

%include "header.inc"

global read_block

extern read

;---------------------------------------------------------------------
; Description: Read a block of data from the specified file descriptor
;   into the specified buffer.
;
;   This is a wrapper around read(2) that avoids the caller needing
;   to retry reading on EINTR or EAGAIN.
;
; C prototype equivalent:
;
;     ssize_t read_block(int fd, void *buffer, size_t count);
;
; Parameters:
;
; - Input: RDI (integer) - file descriptor.
; - Output: RSI (string) - "void *" / "char *" pointer.
; - Input: RDX (integer) - number of bytes to read (which must be <= size of buffer).
; - Output: RAX (integer) - number of bytes read on success, or -1 on error.
;
; Notes:
;
; Limitations:
;
; See:
;---------------------------------------------------------------------

read_block:
    prologue_with_vars 5

    ;--------------------
    ; Stack offsets.

    .fd          equ     0   ; 32-bit int (but consuming 8 bytes).
    .buffer      equ     8   ; "void *"
    .count       equ     16  ; ssize_t

    .p           equ     24  ; "void *" pointer.
    .bytes_read  equ     32  ; ssize_t

    ;------------------------------
    ; Save args

    mov     qword [rsp+.fd], 0 ; clear all 64-bits
    mov     [rsp+.fd], edi     ; copy 32-bits
    mov     [rsp+.buffer], rsi
    mov     [rsp+.count], rdx

    ;------------------------------
    ; Initialise

    ; bytes_read = 0
    mov     qword [rsp+.bytes_read], 0

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

.read_again:
    mov     edi, [rsp+.fd]
    mov     rsi, [rsp+.p]
    mov     rdx, [rsp+.count]

    cmp     rdx, 0
    je      .success ; No more space available in buffer

    dcall   read

    cmp     rax, 0 ; Check EOF
    je      .success
    jl      .check_read_error

    ; Read was successful

    add     [rsp+.bytes_read], rax ; Save byte count.
    add     [rsp+.p], rax          ; Move the pointer along the buffer.
    sub     [rsp+.count], rax      ; Update amount of space available in the buffer

    jmp     .read_again

.check_read_error:
    cmp     rax, EAGAIN
    je      .read_again
    cmp     rax, EINTR
    je      .read_again
    jmp     .error

.success:
    mov     rax, [rsp+.bytes_read]

.out:
    epilogue_with_vars 5
    ret

.error:
    mov     rax, -1
    jmp     .out

