;---------------------------------------------------------------------
; vim:set expandtab:
;---------------------------------------------------------------------
; Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
;
; SPDX-License-Identifier: Apache-2.0
;---------------------------------------------------------------------

%include "header.inc"

global libc_strtod
global libc_strtod_full
global libc_strtol

extern get_errno
extern set_errno

extern strtod
extern strtol

;---------------------------------------------------------------------
; Description: Call strtol(3).
;
; C prototype equivalent:
;
;     int libc_strtol(const char *str, int base, long *result);
;
; Parameters:
;
; - Input: RDI (str) - Address of string to parse.
; - Input: RSI (base) - Base (0 (for hex), or 2-36 inclusive).
; - Input/Output: pointer value that will contain parsed value.
; - Output RAX - 0 on success, -1 on error.
;
; Error detection:
;
; strtol(3) sets ERRNO on error. It needs to do this to allow the
; function to correctly parse the value "-1". However, this makes its
; use a bit unwieldy as you need to check ERRNO after every call to see
; if the parse failed. This function tries to make life easier by
; checking ERRNO. If it is set, it returns the errno value in RAX. If no
; error occurred, RAX is set to zero.
;
; Summary:
;
; If RAX == 0 and RDX is -1, the number is -1.
; If RAX != 0, the value of RDX is undefined.
;---------------------------------------------------------------------
libc_strtol:
    prologue_with_vars 5

    ;--------------------
    ; Stack offsets.

    .str        equ      0  ; "char *"
    .base       equ      8  ; int
    .result     equ     16  ; "long *"

    .p          equ     24  ; "char *" pointer.

    .num        equ     32  ; size_t

    ;--------------------
    ; Checks

    cmp     rdi, 0
    je      .err  ; Invalid string specified.

    cmp     rsi, 0
    jl      .err   ; Invalid base

    cmp     rdx, 0
    je      .err   ; Invalid result pointer

    ;--------------------
    ; Save args

    mov     [rsp+.str], rdi
    mov     [rsp+.base], rsi
    mov     [rsp+.result], rdx

    ;--------------------

    mov     rdi, 0   ; Clear errno before call (see strtol(3)).
    dcall   set_errno

    mov     rdi, [rsp+.str]
    lea     rsi, [rsp+.p] ; Set endptr.
    mov     rdx, [rsp+.base]

    dcall   strtol

    ; Save result
    mov     [rsp+.num], rax

    dcall   get_errno
    cmp     rax, 0
    jne     .err

    cmp     qword [rsp+.num], 0

    ; Return value was not zero, but we still need to check the endptr
    ; value.
    jne     .check_endptr

    ; if (rc == 0 && endptr == nptr) an error occcurred.
    mov     rax, [rsp+.p]
    cmp     rax, [rsp+.str]
    je     .err ; Invalid input or trailing garbage.

.check_endptr:
    ; If (endptr != '\0') an error occurred.
    xor     rax, rax ; Clear.
    mov     rcx, [rsp+.p]  ; Copy address of 1st invalid char.
    mov     byte al, [rcx] ; Copy *value* of the invalid char.
    cmp     al, 0
    je     .success

    jmp     .err

.success:
    ; Return the parsed value
    mov     rax, [rsp+.num]    ; rax = number

    mov     rdx, [rsp+.result] ; rdx = address
    mov     [rdx], rax         ; *addr = number

    mov     rax, 0 ; Mark as success.

.out:
    epilogue_with_vars 5
    ret

.err:
    mov     rax, -1 ; Mark as failed.
    jmp     .out

;---------------------------------------------------------------------
; Description: Call strtod(3).
;
; C prototype equivalent:
;
;     int libc_strtod(const char *str, double *result)
;
; Parameters:
;
; - Input: RDI (str): Address of string to parse.
; - Input/Output: RSI (address): pointer to parsed value.
; - Output: RAX: 0 on success, -1 on error.
;
; Error detection:
;
; strtod(3) sets ERRNO on error. It needs to do this to allow the
; function to correctly parse the value "-1". However, this makes its
; use a bit unwieldy as you need to check ERRNO after every call to see
; if the parse failed. This function to make life easier by
; checking ERRNO, returning the value through a parameter and actually
; returning a reliable status value to determine if the call was
; successful or not.
;---------------------------------------------------------------------

libc_strtod:
    prologue_with_vars 3

    ;--------------------
    ; Stack offsets.

    .str        equ     0   ; "char *"
    .p          equ     8   ; "char *"
    .endp       equ     16  ; "char **"

    ;--------------------
    ; Save arg

    mov     [rsp+.str], rdi

    ;--------------------
    ; XXX: Setup pointer arg
    ;
    ; Note: The first 2 args are already setup correctly
    ; by the caller.

    ; char *p;
    ; char **endp = &p;
    lea     rax, [rsp+.p]
    mov     [rsp+.endp], rax

    ;--------------------

    mov     rdx, [rsp+.endp] ; Set endptr.

    dcall   libc_strtod_full

    cmp     rax, 0
    jne     .err

.cmp_pointers:
    mov     rax, [rsp+.endp]
    cmp     rax, [rsp+.str]

    ; if (rc == 0 && endptr == nptr) an error occurred.
    je      .err

    ; if (endptr == '\0') no error occurred.
    cmp     qword [rsp+.endp], 0
    je      .success

.chk_endptr:
    ; If (endptr != '\0') an error occurred.
    xor     rax, rax ; Clear.

    ; XXX: Get the address of the pointer
    ; XXX: (**NOT** the pointer to XXX: pointer!)
    mov     rcx, [rsp+.p] ; Copy address of 1st invalid char.

    ; XXX: Dereference the pointer to get the first character
    ; XXX: pointed to.
    mov     byte al, [rcx] ; Copy *value* of the invalid char.
    cmp     al, 0
    je     .success

    jmp     .err

.success:
    mov     rax, 0 ; Mark as success.

.out:
    epilogue_with_vars 3
    ret

.err:
    mov     rax, -1  ; Mark as failed.
    jmp     .out

;---------------------------------------------------------------------
; Description: Call strtod(3) and pass return any suffix.
;
; C prototype equivalent:
;
;     int libc_strtod_full(const char *str, double *result, char **endptr)
;
; Parameters:
;
; - Input: RDI (str): Address of string to parse.
; - Input/Output: RSI (address): pointer to parsed value.
; - Input/Output: RDX (address): pointer to pointer to string.
; - Output: RAX: 0 on success, -1 on error.
;
; Error detection:
;
; strtod(3) sets ERRNO on error. It needs to do this to allow the
; function to correctly parse the value "-1". However, this makes its
; use a bit unwieldy as you need to check ERRNO after every call to see
; if the parse failed. This function to make life easier by
; checking ERRNO, returning the value through a parameter and actually
; returning a reliable status value to determine if the call was
; successful or not.
;---------------------------------------------------------------------
libc_strtod_full:
    prologue_with_vars 4

    ;--------------------
    ; Stack offsets.

    .str        equ     0   ; "char *"
    .result     equ     8   ; "double *"

    .endp       equ     16  ; "char **" pointer.
    .num        equ     24  ; double

    ;--------------------

    cmp     rdi, 0
    je      .err   ; Invalid string address.

    cmp     rsi, 0
    je      .err   ; Invalid result address.

    cmp     rdx, 0
    je      .err   ; Invalid endptr address.

    ; Save args
    mov     [rsp+.str], rdi
    mov     [rsp+.result], rsi
    mov     [rsp+.endp], rdx

    mov     byte al, [rdi]
    cmp     al, 0
    je     .err   ; Invalid address specified.

    mov     rdi, 0   ; Clear errno before call (see strtod(3)).
    dcall   set_errno

    mov     rdi, [rsp+.str]

    mov     rsi, [rsp+.endp] ; Set endptr.

    dcall   strtod

    ;--------------------
    ; XXX: Save the *floating point* result

    ; Get the address of the result pointer.
    mov         rax, [rsp+.result]

    ; Write the double value through the pointer
    movq        [rax], xmm0

    ;--------------------

    dcall   get_errno
    cmp     rax, 0
    jne     .err

    cmp     qword [rsp+.result], 0

    jne     .success

    ; if (rc == 0 && endptr == nptr) an error occurred.
    mov     rcx, [rsp+.endp]
    mov     rax, [rcx]

    cmp     rax, [rsp+.str]
    je     .err ; Invalid input or trailing garbage.

; Note: We let the caller decide if they want to check endp!

.success:
    mov     rax, 0 ; Mark as success.

.out:
    epilogue_with_vars 4
    ret

.err:
    mov     rax, -1  ; Mark as failed.
    jmp     .out
