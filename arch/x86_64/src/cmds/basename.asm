;---------------------------------------------------------------------
; vim:set expandtab:
;---------------------------------------------------------------------
; Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
;
; SPDX-License-Identifier: Apache-2.0
;---------------------------------------------------------------------

global command_help_basename
global command_basename

extern free
extern puts
extern strdup

; Use the POSIX version of the libc function for compatibility
; with basename(1).
;
; XXX: See basename(3) for the gruesome details.
; XXX: Note: we could add an option to toggle between the two differnt
; implementations (which have slightly different behaviour)?
extern __xpg_basename

%include "header.inc"

section .rodata
command_help_basename:      db    "see basename(1)",0

section .text

command_basename:
    prologue_with_vars 1

    ;--------------------
    ; Stack offsets.

    .p          equ     0   ; "char *" pointer.

    ;--------------------

    consume_program_name

    cmp     rdi, 0
    je      .error_no_arg

    ; Get the first argument
    mov     rdi, [rsi]

    cmp     rdi, 0
    je      .error ; Something bad happened.

    mov     al, [rdi] ; Get 1st char of string
    cmp     al, 0
    je      .just_print_nl ; Empty string specified.

    dcall   strdup
    cmp     rax, 0
    je      .error

    mov     [rsp+.p], rax

    mov     rdi, rax

    dcall   __xpg_basename
    cmp     rax, 0
    je     .error

    mov     rdi, rax
    dcall   puts

    mov     rdi, [rsp+.p]
    dcall   free

.success:

    mov     rax, CMD_OK

.out:
    epilogue_with_vars 1

    ret

; Although the man page disagrees, it seems that the POSIX version of
; basename prints a period if the path is empty. However, basename(3)
; only prints a newline in that scenario so be compatible with
; basename(3).
.just_print_nl:
    dcall   puts
    jmp     .success

.error:
    mov     rax, CMD_FAILED
    jmp     .out

.error_no_arg:
    mov     rax, CMD_NO_ARG
    jmp     .out
