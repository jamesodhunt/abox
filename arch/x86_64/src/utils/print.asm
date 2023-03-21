;---------------------------------------------------------------------
; vim:set expandtab:
;---------------------------------------------------------------------
; Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
;
; SPDX-License-Identifier: Apache-2.0
;---------------------------------------------------------------------

%include "header.inc"

global print
global print_nl
global print_stderr
global print_stdout

extern asm_strlen
extern write_block

extern write

;---------------------------------------------------------------------
; Description: Write null-terminated string to a fd.
; Note: Only slightly more helpful than write(2) ;-)
;
; C prototype equivalent:
;
;     int print(int fd, const char *msg)
;
; Parameters:
;
; - Input: RDI (fd) - File descriptor to write to.
; - Input: RSI (msg) - Address of string.
; - Output: RAX - number of bytes written.
;---------------------------------------------------------------------
print:
    prologue_with_vars 2

    ;--------------------
    ; Stack offsets.

    .fd         equ     0   ; 32-bit int
    .msg        equ     8   ; "char *"

    ;--------------------
    ; Save args

    mov     [rsp+.fd], rdi
    mov     [rsp+.msg], rsi

    ;--------------------

    mov     rdi, rsi

    dcall   asm_strlen

    mov     rdx, rax ; save string length

    mov     rdi, [rsp+.fd]
    mov     rsi, [rsp+.msg]

    dcall   write_block

    epilogue_with_vars 2
    ret

;---------------------------------------------------------------------
; Description: Write newline to stdout.
;
; C prototype equivalent:
;
;     void print_nl(void);
;
; Parameters:
;
; - Input: RDI (fd) - File descriptor to write to.
; - Input: RSI (msg) - Address of string.
; - Output: RAX - number of bytes written.
;---------------------------------------------------------------------

print_nl:
section .text
    prologue_with_vars 1

    ;--------------------
    ; Stack offsets

    .nl         equ     0   ; newline character.

    ;--------------------
    ; Setup

    ; Required as we need the symbol to have an address.
    mov     qword [rsp+.nl], NL

    ;--------------------

    mov     rdi, STDOUT_FD
    lea     rsi, [rsp+.nl]
    mov     rdx, 1
    dcall   write

.out:
    epilogue_with_vars 1
    ret

;---------------------------------------------------------------------
; Description: Write null-terminated string to standard output.
;
; C prototype equivalent:
;
;     int print_stdout(const char *msg)
;
; Parameters:
;
; - Input: RDI - Address of string.
; - Output: RAX - number of bytes written.
;---------------------------------------------------------------------

print_stout:
    prologue_with_vars 0

    mov     r10, rdi    ; Save buffer to print.
    mov     rdi, STDOUT_FD
    mov     rsi, r10

    dcall   print

    epilogue_with_vars 0
    ret

;---------------------------------------------------------------------
; Description: Write null-terminated string to standard error.
;
; C prototype equivalent:
;
;     int print_stderr(const char *msg)
;
; Parameters:
;
; - Input: RDI - Address of string.
; - Output: RAX - number of bytes written.
;---------------------------------------------------------------------

print_stderr:
    prologue_with_vars 0

    mov     r10, rdi    ; Save buffer to print.
    mov     rdi, STDERR_FD
    mov     rsi, r10

    dcall   print

    epilogue_with_vars 0
    ret
