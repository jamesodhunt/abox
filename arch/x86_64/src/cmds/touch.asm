;---------------------------------------------------------------------
; vim:set expandtab:
;---------------------------------------------------------------------
; Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
;
; SPDX-License-Identifier: Apache-2.0
;---------------------------------------------------------------------

global command_help_touch
global command_touch

extern close
extern open
extern utimensat
extern write

extern get_errno

section .rodata
command_help_touch:  db  "see touch(1)",0

%include "header.inc"

section .text

;---------------------------------------------------------------------
;
;---------------------------------------------------------------------

command_touch:
    prologue_with_vars 3

    ;--------------------
    ; Stack offsets.

    .argc       equ     0   ; size_t.
    .argv       equ     8   ; "char **"
    .no_create  equ     16  ; size_t: bool

    ;--------------------
    ; Save args

    mov     [rsp+.argc], rdi
    mov     [rsp+.argv], rsi

    ; Clear no_create initially
    mov     qword [rsp+.no_create], 0

    ;--------------------

    consume_program_name

    cmp     rdi, 0
    je     .err_no_arg

    ; Check if an option was specified

    mov     rax, [rsi]
    mov     rbx, [rax]
    cmp     bx, '-c'
    jne     .next_file

    mov     qword [rsp+.no_create], 1

.next_file:
    mov     rdi, [rsi] ; Grab the next filename.
    mov     rsi, [rsp+.no_create]

    dcall   touch
    cmp     rax, 0
    jne     .error

    ; Update on the stack
    add     qword [rsp+.argv], 8 ; argv++
    dec     qword [rsp+.argc]    ; argc--

    ; Reload the values
    mov     rdi, [rsp+.argc]
    mov     rsi, [rsp+.argv]

    cmp     rdi, 0
    je      .success
    jmp     .next_file

.success:
    mov     rax, CMD_OK

.out:
    epilogue_with_vars 3

    ret

.error:
    mov     rax, CMD_FAILED
    jmp     .out

.err_no_arg:
    mov     rax, CMD_NO_ARG
    jmp     .out

;---------------------------------------------------------------------
; Description: Update timestamps on the specified file and create it
;   if necessary.
;
; C prototype equivalent:
;
;     int touch(const char *path);
;
; Parameters:
;
; - Input: RDI (address) - File whose timestamps are to updated.
; - Input: RSI (bool) - true if file should *not* be created.
; - Output: RAX (integer) - 0 on success, or -1 on error.
;
; Notes:
;
;   If path is "-", read from stdin.
;
; Limitations:
;
; See:
;
;---------------------------------------------------------------------

touch:
    .create_flags  equ     (O_RDWR|O_CREAT|O_NONBLOCK|O_NOCTTY)
    .create_perms  equ     666o

    prologue_with_vars 2

    ;--------------------
    ; Stack offsets.

    .path       equ     0   ; "char *".
    .no_create  equ     8   ; size_t: bool.

    ;--------------------
    ; Save args

    mov     [rsp+.path], rdi
    mov     [rsp+.no_create], rsi

    ;--------------------

    mov     rdi, AT_FDCWD
    mov     rsi, [rsp+.path]
    mov     rdx, 0 ; FIXME: timespecs current not specifed, meaning "now".
    mov     rcx, 0 ; No flags.

    dcall   utimensat
    cmp     rax, 0
    je      .success

    ; Call failed
    dcall   get_errno
    cmp     rax, ENOENT
    jne     .error

    cmp     qword [rsp+.no_create], 1

    ; File doesn't exist, but we're not allowed to create it. Oddly,
    ; this is considered success in touch(1).
    je      .success

    ; The file didn't exist, so just create it.
    mov     rdi, [rsp+.path]
    mov     rsi, .create_flags
    mov     rdx, .create_perms
    dcall   open
    cmp     rax, 0
    jl      .error

    mov     rdi, rax ; fd
    dcall   close

.success:
    mov     rax, CMD_OK

.out:
    epilogue_with_vars 2

    ret

.error:
    mov     rax, CMD_FAILED
    jmp     .out
