;---------------------------------------------------------------------
; vim:set expandtab:
;---------------------------------------------------------------------
; Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
;
; SPDX-License-Identifier: Apache-2.0
;---------------------------------------------------------------------

global command_help_sleep
global command_sleep

extern get_errno
extern libc_strtod
extern num_to_timespec
extern strcasestr

extern nanosleep
extern printf

section .rodata
command_help_sleep:  db  "see sleep(1)",0

%include "header.inc"

section .text

;---------------------------------------------------------------------
; Extensions:
;
; - Provides a '-n' (no-act or dry-run) option that displays the number
;   of seconds that would be slept, but does not sleep. This option is
;   useful for debugging and testing.
;---------------------------------------------------------------------

command_sleep:
section .rodata
    .forever_prefix   db "inf",0
    .max_nanoseconds  equ 999999999

%ifdef NASM
    ; Integer value: 18446744073709551615
    ; Note that YASM seemingly only supports 32-bit literal values so
    ; we have to waste some instructions to handle this for YASM ;(
    .max_seconds      equ 0xffffffffffffffff
%endif
section .bss
    .delay          resb Timespec_size
    .remainder      resb Timespec_size

section .text
    prologue_with_vars 4

    ;--------------------
    ; Stack offsets.

    .str_value  equ     0   ; "char *"
    .fp_value   equ     8   ; 8 byte double floating point.
    .forever    equ     16  ; bool: if true, sleep forever

    ; bool: if true, do not sleep: just display how long command would
    ; normally sleep for.
    .no_act     equ     24

    ;--------------------

    consume_program_name

    cmp     rdi, 0
    je     .err_need_arg

    ;--------------------
    ; Set defaults

    mov     qword [rsp+.no_act], 0

    ;--------------------

    mov     rax, [rsi]

    ; Look for the dry-run option
    mov     rbx, [rax]
    cmp     bx, '-n'

    jne     .no_arg

    mov     byte [rsp+.no_act], 1

    ; Consume the argument
    dec     rdi    ; argc--
    add     rsi, 8 ; argv++

.no_arg:
    mov     rax, [rsi]
    mov     [rsp+.str_value], rax ; Save value

    ;------------------------------
.check_for_infinity:
    mov     rdi, [rsp+.str_value]
    mov     rsi, .forever_prefix

    dcall   strcasestr

    ; reload arg value
    mov     rdi, [rsp+.str_value]
    cmp     rax, rdi
    jne     .not_infinity

    ; Found the infinity marker
    mov     qword [rsp+.forever], 1

.setup_for_infinity_sleep:
    ; Max out the timespec
%ifdef NASM
    mov     qword [.delay+Timespec.tv_sec], .max_seconds
%elifdef YASM
    ; YASM can't load a 64-bit literal directly it seems ;(
    mov     rax, qword 0
    not     rax ; flip bits
    mov     qword [.delay+Timespec.tv_sec], rax
%else
    %error Unknown assembler
%endif
    mov     qword [.delay+Timespec.tv_nsec], .max_nanoseconds

    jmp     .setup_for_sleep

    ;------------------------------

.not_infinity:
    mov     rdi, [rsp+.str_value]
    lea     rsi, [.delay]

    dcall   num_to_timespec
    cmp     rax, 0

    ; If the function failed, chances are the argument is invalid.
    jne     .err_bad_arg

.setup_for_sleep:
    mov     rdi, .delay
    mov     rsi, .remainder

    cmp     byte [rsp+.no_act], 1
    je     .display_only

.sleep_again:
    dcall   nanosleep

    cmp     rax, 0
    je      .success

    ; An error occurred so check errno
    dcall   get_errno
    cmp     rax, 0
    je      .success

    cmp     rax, EFAULT
    je      .error

    cmp     rax, EINVAL
    je      .error

    cmp     rax, EINTR
    je      .err_eintr

.success:
    ; Unlikely that we'll ever get here, but the user requested an
    ; infinite sleep, so give it to them!
    cmp     qword [rsp+.forever], 1

    cmp     byte [rsp+.no_act], 1
    jne     .success_not_infinity

.success_not_infinity:

    mov     rax, CMD_OK

.out:
    epilogue_with_vars 4

    ret

.display_only:
section .rodata
    .display_fmt  db "%lu.%-9.9lu",10,0
section .text
    mov     rdi, .display_fmt
    mov     rsi, [.delay+Timespec.tv_sec]
    mov     rdx, [.delay+Timespec.tv_nsec]
    xor     rax, rax
    dcall   printf
    jmp     .success

.error:
    mov     rax, CMD_FAILED
    jmp     .out

.err_need_arg:
    mov     rax, CMD_NO_ARG
    jmp     .out

.err_bad_arg:
    mov     rax, CMD_BAD_ARG
    jmp     .out

.err_eintr:
    ; set delay=remainder
    mov     rax, [.remainder+Timespec.tv_sec]
    mov     [.delay+Timespec.tv_sec], rax

    mov     rax, [.remainder+Timespec.tv_nsec]
    mov     [.delay+Timespec.tv_nsec], rax

    ; clear remainder
    mov     qword [.remainder+Timespec.tv_sec], 0
    mov     qword [.remainder+Timespec.tv_nsec], 0

    jmp     .sleep_again
