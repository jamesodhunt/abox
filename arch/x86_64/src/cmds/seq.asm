;---------------------------------------------------------------------
; vim:set expandtab:
;---------------------------------------------------------------------
; Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
;
; SPDX-License-Identifier: Apache-2.0
;---------------------------------------------------------------------

global command_help_seq
global command_seq

extern close
extern libc_strtol
extern printf
extern write

section .rodata
command_help_seq:  db  "see seq(1)",0

%include "header.inc"

section .text

;---------------------------------------------------------------------
; FIXME: switch from strtol(3) to strtod(3) for compat with seq(1).
;---------------------------------------------------------------------

command_seq:
section .rodata
    .errNoArg            db   "ERROR: missing argument(s)",10,0
    .errNoArgLen         equ  $-.errNoArg-1

    .errTooManyArgs      db   "ERROR: too many arguments",10,0
    .errTooManyArgsLen   equ  $-.errTooManyArgs-1

    .errBadNum           db   "ERROR: bad value",10,0
    .errBadNumLen        equ  $-.errBadNum-1

section .text
    .default_first  equ  1
    .default_step   equ  1

    prologue_with_vars 7

    ;--------------------
    ; Stack offsets.

    ; Params
    .arg_count      equ      0  ; size_t.

    .first_str      equ      8  ; "char *" ssize_t value.
    .step_str       equ     16  ; "char *" ssize_t value.
    .last_str       equ     24  ; "char *" ssize_t value.

    .first          equ     32  ; ssize_t value.
    .step           equ     40  ; ssize_t value.
    .last           equ     48  ; ssize_t value.

    ;--------------------

    consume_program_name

    cmp     rdi, 0
    je     .error_no_arg

    ; Save arg count
    mov     qword [rsp+.arg_count], rdi

    cmp     rdi, 1
    je     .handle_single_arg

    cmp     rdi, 2
    je     .handle_two_args

    cmp     rdi, 3
    je     .handle_three_args

    jmp     .error_too_many_args

.call_seq:
    mov     rdi, [rsp+.first]
    mov     rsi, [rsp+.step]
    mov     rdx, [rsp+.last]

    dcall   seq

.nothing_to_output:
.success:
    mov     rax, 0

.out:
    epilogue_with_vars 7

    ret

.error_no_arg:
    mov     rsi, .errNoArg
    mov     rdx, .errNoArgLen
    jmp     .handle_error

.error_too_many_args:
    mov     rsi, .errTooManyArgs
    mov     rdx, .errTooManyArgsLen
    jmp     .handle_error

.error_bad_num:
    mov     rsi, .errBadNum
    mov     rdx, .errBadNumLen
    jmp     .handle_error

.handle_error:
    mov     rdi, STDERR_FD
    dcall   write
    mov     rax, -1
    jmp     .out

;-----------------------------------
; Usage: "seq last"
; Default values: first, step.

.handle_single_arg:
    ; Get and save last arg string
    mov     rax, [rsi]
    mov     [rsp+.last_str], rax

    mov     rdi, [rsp+.last_str]
    mov     rsi, BASE_10
    lea     rdx, [rsp+.last]

    dcall     libc_strtol

    cmp     rax, 0
    jne     .error_bad_num

    ; If (last <= 0) do nothing (for compatability with seq(1).
    cmp     qword [rsp+.last], 0
    jle     .nothing_to_output

    mov     qword [rsp+.first], .default_first
    mov     qword [rsp+.step], .default_step

    jmp     .call_seq

;-----------------------------------
; Usage: "seq first last"
; Default values: step.

.handle_two_args:
    ; Get and save 'first' arg string
    mov     rax, [rsi+0]
    mov     [rsp+.first_str], rax

    ; Get and save 'last' arg string
    mov     rax, [rsi+8]
    mov     [rsp+.last_str], rax

    ;--------------------
    ; Parse 'first' string

    mov     rdi, [rsp+.first_str]
    mov     rsi, BASE_10
    lea     rdx, [rsp+.first]

    dcall     libc_strtol

    cmp     rax, 0
    jne     .error_bad_num

    ;--------------------
    ; Parse 'last' string

    mov     rdi, [rsp+.last_str]
    mov     rsi, BASE_10
    lea     rdx, [rsp+.last]

    dcall     libc_strtol

    cmp     rax, 0
    jne     .error_bad_num

    ; If (first > last) do nothing (for compatability with seq(1).
    mov     rax, [rsp+.first]
    cmp     rax, [rsp+.last]
    jg     .nothing_to_output

    ;--------------------
    ; Set defaults
    mov     qword [rsp+.step], .default_step

    jmp     .call_seq

;-----------------------------------
; Usage: "seq first step last"
; Default values: n/a.

.handle_three_args:
    ; Get and save 'first' arg string
    mov     rax, [rsi+0]
    mov     [rsp+.first_str], rax

    ; Get and save 'last' arg string
    mov     rax, [rsi+8]
    mov     [rsp+.step_str], rax

    ; Get and save 'last' arg string
    mov     rax, [rsi+16]
    mov     [rsp+.last_str], rax

    ;--------------------
    ; Parse 'first' string

    mov     rdi, [rsp+.first_str]
    mov     rsi, BASE_10
    lea     rdx, [rsp+.first]

    dcall     libc_strtol

    cmp     rax, 0
    jne     .error_bad_num

    ;--------------------
    ; Parse 'step' string

    mov     rdi, [rsp+.step_str]
    mov     rsi, BASE_10
    lea     rdx, [rsp+.step]

    dcall     libc_strtol

    cmp     rax, 0
    jne     .error_bad_num

    ;--------------------
    ; Parse 'last' string

    mov     rdi, [rsp+.last_str]
    mov     rsi, BASE_10
    lea     rdx, [rsp+.last]

    dcall     libc_strtol

    cmp     rax, 0
    jne     .error_bad_num

    ;--------------------

    jmp     .call_seq

;---------------------------------------------------------------------
; Description: seq(1).
;
; C prototype equivalent:
;
;     int seq(ssize_t first, ssize_t increment, ssize_t last);
;
; Parameters:
;
; - Input: RDI (integer) - initial value.
; - Input: RSI (integer) - increment or step value.
; - Input: RDX (integer) - final value.
; - Output: RAX (integer) - 0 on success, or -1 on error.
;---------------------------------------------------------------------

seq:
section .rodata
    .fmt              db   "%d",10,0

    .errZeroStep         db   "ERROR: step cannot be zero",10,0
    .errZeroStepLen      equ  $-.errZeroStep-1

section .text
    prologue_with_vars 4

    ;--------------------
    ; Stack offsets.

    ; Params
    .first          equ     0   ; ssize_t
    .step           equ     8   ; ssize_t: increment value.
    .last           equ     16  ; ssize_t

    .i              equ     24  ; size_t: counter.

    ;--------------------

    ; Save args
    mov     [rsp+.first], rdi
    mov     [rsp+.step], rsi
    mov     [rsp+.last], rdx

    jmp     .check_args

.checks_done:

    ; set i=first
    mov     rax, [rsp+.first]
    mov     [rsp+.i], rax

.loop:
    ; Check
    cmp     qword [rsp+.step], 0
    jl     .negative_step_checks

    ; step is +ve, so we're counting up.
    mov     rax, [rsp+.i]
    cmp     rax, [rsp+.last]
    jg      .success
    jmp     .display_value

.negative_step_checks:

    ; step is -ve, so we're counting down.
    mov     rax, [rsp+.i]
    cmp     rax, [rsp+.last]
    jl      .success

.display_value:

    ; Display the value
    mov     rdi, .fmt
    mov     rsi, [rsp+.i]
    xor     rax, rax

    dcall   printf

    ; i += step
    mov     rax, [rsp+.step]
    add     [rsp+.i], rax

    jmp     .loop

.success:
    mov     rax, CMD_OK

.nothing_to_output:
.out:
    epilogue_with_vars 4

    ret

.error:
    mov     rax, CMD_FAILED
    jmp     .out

; Output is only generated if the following is true:
;
; if (step == 0) error()
; if (step > 0) show_output_if_true(first < last) ; since we're counting up.
; if (step < 0) show_output_if_true(first > last) ; since we're counting down.
.check_args:
    cmp     qword [rsp+.step], 0
    je      .error_step_cannot_be_zero
    jl      .check_negative_step
    jmp     .check_positive_step

.check_positive_step:
    mov     rax, [rsp+.first]
    cmp     rax, qword [rsp+.last]
    jg      .nothing_to_output

    jmp     .checks_done

.check_negative_step:
    mov     rax, [rsp+.first]
    cmp     rax, qword [rsp+.last]
    jl      .nothing_to_output

    jmp     .checks_done

.error_step_cannot_be_zero:
    mov     rsi, .errZeroStep
    mov     rdx, .errZeroStepLen
    jmp     .handle_error

.handle_error:
    mov     rdi, STDERR_FD
    dcall   write
    mov     rax, CMD_FAILED
    jmp     .out
