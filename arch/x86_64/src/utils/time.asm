;---------------------------------------------------------------------
; vim:set expandtab:
;---------------------------------------------------------------------
; Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
;
; SPDX-License-Identifier: Apache-2.0
;---------------------------------------------------------------------

%include "header.inc"

global num_to_timespec

extern libc_strtod_full
extern modf

;---------------------------------------------------------------------
; Description: Convert a numeric string to a timespec.
;
; C prototype equivalent:
;
;     int num_to_timespec(const char *num, struct timespec *ts);
;
; Parameters:
;
; - Input: RDI (string) - Number to convert.
; - Input/Output: RSI (address) - timespec pointer.
; - Output: RAX (integer) - 0 on success, or -1 on error.
;
; Notes: The number to convert can be either an integer, or a floating
;   point value. If no suffix is specified, the value is assumed to be
;   in seconds. A range of suffixes are recognised. If present, the
;   timespec value is updated accordingly:
;
;   - 's' (seconds).
;   - 'm' (minutes).
;   - 'h' (hours).
;   - 'd' (days).
;
;   If an invalid (unrecognised) suffix is treated as an error.
;
; Limitations:
;
; See:
;---------------------------------------------------------------------

num_to_timespec:
    prologue_with_vars 10

    ;--------------------
    ; Stack offsets.

    ; XXX: Define a set of stack *OFFSETS* for our "variables"
    .str_value     equ     0   ; "char *".
    .p             equ     8   ; "char *"
    .endp          equ     16  ; "char **".
    .ts            equ     24  ; "struct timespec *".
    .fp_value      equ     32  ; double FP version of str_value.

    ; Return values from modf(3).
    .fp_int_part   equ     48  ; double floating point.
    .fp_frac_part  equ     56  ; double floating point.

    ; Values for nanosleep(3).
    .tv_sec        equ     64  ; size_t.
    .tv_nsec       equ     72  ; size_t.

    ; (gdb) p * (size_t *)($rsp+72)
    .multiplier    equ     80  ; size_t.

    ;--------------------

    cmp     rdi, 0
    je      .error ; Invalid string address.

    cmp     rsi, 0
    je      .error ; Invalid timespec address.

    ; Save params
    mov     [rsp+.str_value], rdi
    mov     [rsp+.ts], rsi

    ;--------------------
    ; XXX: Setup pointer arg

    ; char *p;
    ; char **endp = &p;
    lea     rax, [rsp+.p]
    mov     [rsp+.endp], rax

    ;--------------------

    ; Convert the string numeric to a double floating point value.
    lea     rsi, [rsp+.fp_value]

    mov     rdx, [rsp+.endp] ; Set endptr.

    dcall   libc_strtod_full

    cmp     rax, 0
    jne     .error

    ; Check to ensure that the successfully parsed value is >=0
    movq    xmm0, [rsp+.fp_value]
    mov     rax, 0 ; Value to check against.
    push    rax    ; Give the value an address on the stack.

    ; Compare the address on the stack with the parsed valued.
    ucomisd xmm0, [rsp]
    pop     rax    ; Clean up.
    jb      .error

.cmp_pointers:
    mov     rax, [rsp+.endp]
    cmp     rax, [rsp+.str_value]

    ; if (rc == 0 && endptr == nptr) an error occurred.
    je      .error

    ; if (endptr == '\0') no error occurred.
    cmp     qword [rsp+.endp], 0
    je      .no_suffix

.check_endptr:
    ; If (endptr != '\0') an error occurred.
    xor     rax, rax ; Clear.

    ; XXX: Get the address of the pointer
    ; XXX: (**NOT** the pointer to XXX: pointer!)
    mov     rcx, [rsp+.p] ; Copy address of 1st suffix char.

    ; XXX: Dereference the pointer to get the first characters
    ; XXX: pointed to.
    mov     word ax, [rcx] ; Copy *value* of the 1st *two* suffix chars.
    cmp     al, 0 ; The lower byte should be a valid suffix, or `\0`.

    je      .unit_multiplier ; Found end of string byte.

    cmp     ah, 0 ; But the upper byte (the last byte on the CLI) should
    ; be the end of string marker (`\0`). If it isn't, the
    ; user either specified an invalid suffix, or possibly
    ; the entire value is a non-numeric string, so bail!
    jne     .error

    ;---------------------------------------------------
    ; Found a suffix, so check for the ones we recognise

    ; strtod(3) parsed a number, but there may be a trailing suffix,
    ; so check endp.

    cmp     al, 's'    ; Handle seconds by ignoring it
    ; (seconds are the default)
    je      .unit_multiplier

.check_minutes_suffix:
    cmp     al, 'm'    ; Handle minutes.
    jne     .check_hours_suffix

    mov     qword [rsp+.multiplier], 60 ; seconds in 1 minute.
    jmp     .suffix_handled

.check_hours_suffix:
    cmp     al, 'h'    ; Handle hours.
    jne     .check_days_suffix

    mov     qword [rsp+.multiplier], (60*60) ; seconds in 1 hour.
    jmp     .suffix_handled

.check_days_suffix:
    cmp     al, 'd'    ; Handle days.
    jne     .error

    mov     qword [rsp+.multiplier], (60*60*24) ; seconds in 1 day.
    jmp     .suffix_handled

.unit_multiplier:
.no_suffix:
    mov     qword [rsp+.multiplier], 1

.suffix_handled:

    ;--------------------------------------------------

    ; Now, the fun begins! ;)

    movq    xmm0, [rsp+.fp_value]


    ; XXX: 2nd parameter for modf(3) (a non-FP value - it's a pointer!)
    lea     rdi, [rsp+.fp_int_part]

    ; XXX: Take care with this one! Since modf(3) accepts and returns
    ; double (floating point) values, those are passed using the xmm*
    ; registers. However, that *does not* apply to *pointers*
    ; ("double *") which are still passed in the normal way.
    ; Since the first non-FP argument is the "double *" pointer
    ; (actually the 2nd argument), that value is specified in rdi!
    ;
    ; The prototype is:
    ;
    ; func:      double modf(double x , double *iptr);
    ; descr.: (frac. part) (original) , (int. part)
    ; type:      fp          fp       , pointer
    ; register:  xmm0        xmm0     , rdi
    dcall   modf


    ; Save the (lower 64-bits) of the resulting fractional part.
    movq     [rsp+.fp_frac_part], xmm0

    ; Convert the double fractional part into a whole number
    ; by multiplying by 1_000_000_000.
    pxor      xmm1, xmm1       ; Clear
    mov       rax, 1000000000  ; Load literal multiplier value

    ; Conver the integer to a double.
    cvtsi2sd xmm1, rax

    pxor      xmm0, xmm0       ; Clear
    movq      xmm0, [rsp+.fp_frac_part] ; Restore saved value.

    mulsd     xmm0, xmm1       ; Perform the double FP multiplication

    ; Now, convert the whole number from a double to an integer
    cvtsd2si rax, xmm0

    mov     [rsp+.tv_nsec], rax ; Save integer result.

    ;------------------------------
    pxor    xmm0, xmm0 ; Clear

    ; XXX: Note the special form of mov required to move the FP value!
    pxor    xmm0, xmm0       ; Clear
    movq    xmm0, [rsp+.fp_int_part]

    cvtsd2si rax, xmm0

    mov     [rsp+.tv_sec], rax ; Save value.

    ;------------------------------
    ; Handle the suffix multiplier

    ; tv_sec *= multiplier
    mov     rax, [rsp+.multiplier]
    mul     qword [rsp+.tv_sec]
    mov     qword [rsp+.tv_sec], rax

    ;------------------------------
    ; Now, update the timespec parameter

    ; Load timespec address
    mov     rax, [rsp+.ts]

    mov     rcx, [rsp+.tv_sec]
    mov     [rax+Timespec.tv_sec], rcx

    mov     rcx, [rsp+.tv_nsec]
    mov     [rax+Timespec.tv_nsec], rcx

    ;------------------------------

.success:
    mov     rax, 0

.out:
    epilogue_with_vars 10
    ret

.error:
    mov     rax, -1
    jmp     .out
