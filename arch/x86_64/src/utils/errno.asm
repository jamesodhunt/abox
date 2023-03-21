;---------------------------------------------------------------------
; vim:set expandtab:
;---------------------------------------------------------------------
; Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
;
; SPDX-License-Identifier: Apache-2.0
;---------------------------------------------------------------------

%include "header.inc"

global get_errno
global set_errno

;---------------------------------------------------------------------
; Magic glibc symbol that provides access to errno(3).
;
; Note that this symbol has become semi-standardised as most libc
; implemenations provide it (although I certainly haven't tested
; them all):
;
; cosmopolitan, dietlibc, glibc, musl, picolibc, uClibc
;
; The ones that don't seem to support it are:
;
; bionic (Android) and newlib-cygwin.
;
; See /usr/include/errno.h
extern  __errno_location

;---------------------------------------------------------------------
; Description: Get the value of the errno global variable.
;
; C prototype equivalent:
;
;     int get_errno();
;
; Parameters:
;
; - Output: RAX - value of errno.
;---------------------------------------------------------------------

get_errno:
    prologue_with_vars 0

    ; XXX: Call magic glibc function to get the errno address.
    dcall    __errno_location

    ; the function returns the address, so deference it
    mov     rcx, [rax]
    mov     rax, rcx

    epilogue_with_vars 0
    ret

;---------------------------------------------------------------------
; Description: Set the value of the errno global variable.
;
; C prototype equivalent:
;
;     void set_errno(int value);
;
; Parameters:
;
; - Input: RDI - value for errno.
;---------------------------------------------------------------------

set_errno:
    prologue_with_vars 1

    ;--------------------
    ; Stack offsets.

    .value      equ     0   ; 32-bit int

    ;--------------------
    ; Save args

    mov     [rsp+.value], rdi

    ; XXX: Call magic glibc function to get the *address*
    ; of the errno variable, returned in rax.
    dcall    __errno_location

    mov     rcx, [rsp+.value]

    ; *errno_address = value
    mov     [rax], rcx

    epilogue_with_vars 1
    ret
