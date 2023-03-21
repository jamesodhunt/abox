;---------------------------------------------------------------------
; vim:set expandtab:
;---------------------------------------------------------------------
; Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
;
; SPDX-License-Identifier: Apache-2.0
;---------------------------------------------------------------------

%include "header.inc"

global asm_basename

extern asm_strlen

;---------------------------------------------------------------------
; Description: Calculate the basename for the specified path by removing
;   the leading path elements from the specified path and returning
;   just the name (aka sanitise the path).
;
; C prototype equivalent:
;
;     char *asm_basename(char *path);
;
; Parameters:
;
; - Input: RDI (address) - Address of argv[0] string.
; - Output: RAX (address) - 0 on error, or valid address.
;
; Notes: The input path may be modified by this call.
;---------------------------------------------------------------------

asm_basename:
section .rodata
    .dot     db      ".",0
section .text
    prologue_with_vars 3

    ;--------------------
    ; Stack offsets.

    .path       equ     0   ; "char *" address.
    .p          equ     8   ; "char *" address: Used to iterate through string.
    .len        equ    16   ; size_t: Length of path string.

    ;--------------------
    ; Setup

    mov     qword [rsp+.len], 0

    ;--------------------
    ; Save args

    mov     [rsp+.path], rdi

    ;--------------------
    ; Initial pathological checks.

    ; path == NULL.
    cmp     rdi, 0
    je      .return_dot

    ; *path == '\0'.
    mov     rax, [rdi]
    cmp     al, 0
    je      .return_dot

    cmp     al, '/'
    jne     .not_single_slash

    cmp     ah, 0
    jne     .not_single_slash

    ; path == "/", so return the entire path.
    mov     rax, [rsp+.path]
    jmp     .out

.not_single_slash:
    ;--------------------
    ; Calculate length of path

    mov     rdi, [rsp+.path]
    dcall   asm_strlen
    mov     [rsp+.len], rax

    ;--------------------
    ; Set p = strlen(path) - 1

    mov     rbx, [rsp+.path]
    add     rbx, [rsp+.len]
    dec     rbx
    mov     [rsp+.p], rbx

    ;--------------------
    ; Start scanning backwards through the string.

    mov     rax, [rsp+.p]

.prev_trailing_byte:
    cmp     rax, [rsp+.path]
    je      .out ; We hit the start of the string, so just return it.

    mov     rbx, [rax]
    cmp     bl, '/'
    jne     .not_a_slash

    ; Overwrite the trailing slash
    mov     qword [rax], 0

    dec     rax
    jmp     .prev_trailing_byte

.not_a_slash:
.prev_non_slash_char:
    cmp     rax, [rsp+.path]

    jne     .not_at_start_of_string

.got_to_start_of_string:
    ; We've got to the beginning of the path,
    ; which is a special case if it starts with a slash.

    mov     rbx, [rax]
    cmp     bl, '/'

    ; Yes, it starts with a slash so don't adjust the
    ; offset as we need to return the byte after the slash.
    je      .done

    ; The first byte is not a slash, so move 1 byte *before* the start
    ; of the string (since .done will move back 1 byte).
    dec     rax
    jmp     .done

.not_at_start_of_string:

    ; We've now removed all trailing slashes.

    mov     rbx, [rax]
    cmp     bl, '/'

    ; And we've just found the first leading slash,
    ; so we've found the basename value.
    je      .done

    dec     rax
    jmp     .prev_non_slash_char

.done:
    ; We currently have the address of the last leading slash, so move
    ; to the next char so we can return the basename.
    inc     rax

.out:
    epilogue_with_vars 3
    ret

.return_dot:
    mov     rax, .dot
    jmp     .out
