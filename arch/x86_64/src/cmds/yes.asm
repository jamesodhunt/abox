;---------------------------------------------------------------------
; vim:set expandtab:
;---------------------------------------------------------------------
; Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
;
; SPDX-License-Identifier: Apache-2.0
;---------------------------------------------------------------------

global command_help_yes
global command_yes

extern close
extern free
extern write

extern alloc_args_buffer
extern argv_bytes
extern print_nl

%include "header.inc"

section .rodata
command_help_yes:   db  "see yes(1)",0

section .text

;---------------------------------------------------------------------
; Notes:
;
; - Command never exits.
;
; Discussion:
;
; This is a superficially simple command but the implementation options
; for supporting the non-standard (user-specified) output are interesting.
;
; Option 1: The naïve way is to repeatedly loop over the 'n' entries in
;           the argv array making 'n'*2 write calls (one call for the entry
;           and another for the space delimiter). An optimisation is to
;           change the paired write calls to a single printf(3) call for
;           the argument and the space delimiter. However, this approach
;           is going to perform badly.
;
; Option 2: Iterate over the argv array and write each value into a space
;           separated static buffer. But how big should the buffer be?
;           Whatever sized buffer is chosen is potentially going to be
;           too small.
;
; Option 3: Iterate over the argv array and write each value into a space
;           separated dynamic buffer. The buffer size can be calculated
;           by traversing all the argv options once and summing up the
;           total bytes required, allocating the buffer, then writing the
;           arguments into it with the delimiters.
;
; Option 4: Iterate over the argv array and build up a buffer dynamically
;           using asprintf(3). This implementation uses this approach.
;---------------------------------------------------------------------

command_yes:
section .rodata
    .default_msg:      db   "y",0xa
    .default_msg_len:  equ  $-.default_msg
    .field_delim       db  " "

section .text
    prologue_with_vars 5

    ;--------------------
    ; Stack offsets

    .argc       equ     0   ; size_t.
    .argv       equ     8   ; "char **"

    .bytes      equ     16  ; size_t.
    .buf        equ     24  ; "char *"

    .ret        equ     32  ; return value.

    ;--------------------
    ; Setup

    ; Assume failure. Pessimistic but safe.
    mov     qword [rsp+.ret], CMD_FAILED

    ;--------------------
    consume_program_name

    cmp     rdi, 0
    je      .write_default_output

    ; Save arguments
    mov     [rsp+.argc], rdi
    mov     [rsp+.argv], rsi

    dcall   argv_bytes

    cmp     rax, 0
    je      .write_newline_only

    ; Save byte count
    mov     [rsp+.bytes], rax

    ; Allocate a buffer for the args and write them into it.
    mov     rdi, [rsp+.argc]
    mov     rsi, [rsp+.argv]

    ; Put *address* of .bytes into register.
    lea     rdx, [rsp+.bytes]

    dcall   alloc_args_buffer

    cmp     rax, 0
    je      .error

    ; Save allocated args buffer data
    mov     [rsp+.buf], rax

    ; Display allocated buffer
.write_custom_output:
    mov     rdi, STDOUT_FD
    mov     rsi, [rsp+.buf]
    mov     rdx, [rsp+.bytes]

    dcall   write
    jmp     .write_custom_output

    ; Deallocate
    ; TODO: FIXME: never called - use atexit/sigaction to clean up on signal?
    mov     rdi, [rsp+.buf]
    dcall   free

.write_default_output:
    mov     rdi, STDOUT_FD
    mov     rsi, .default_msg
    mov     rdx, .default_msg_len

    dcall   write
    jmp     .write_default_output

.write_newline_only:
    dcall   print_nl

    jmp     .write_newline_only

; @NOT_REACHED@
.success:
    mov     qword [rsp+.ret], CMD_OK

.out:
    ; Display a trailing new line
    mov     rdi, STDOUT_FD
    mov     rsi, NL
    mov     rdx, 1
    dcall   write

    mov     rax, [rsp+.ret]

.done:
    epilogue_with_vars 5

    ret

.error:
    mov     qword [rsp+.ret], CMD_FAILED
    jmp     .out

