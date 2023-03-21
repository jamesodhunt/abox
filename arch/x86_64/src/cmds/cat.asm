;---------------------------------------------------------------------
; vim:set expandtab:
;---------------------------------------------------------------------
; Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
;
; SPDX-License-Identifier: Apache-2.0
;---------------------------------------------------------------------

global command_help_cat
global command_cat

extern close
extern open
extern read_block

; FIXME: using stdin_filename instead
extern stdin_alias

extern write_block

section .rodata
command_help_cat:  db  "see cat(1)",0

%include "header.inc"

section .text

;---------------------------------------------------------------------
;
;---------------------------------------------------------------------

command_cat:
section .text
    prologue_with_vars 3

    ;--------------------
    ; Stack offsets.

    .argc       equ     0   ; size_t.
    .argv       equ     8   ; "char **"
    .fd_in      equ    16   ; size_t: file descriptor (int actually).

    ;--------------------
    ; Save args

    ; Not using getopt yet, so remove program name.
    consume_program_name

    mov     [rsp+.argc], rdi
    mov     [rsp+.argv], rsi

    ;--------------------

    cmp     rdi, 0
    jg      .not_stdin

    ; The user didn't specify an argument, which means that the
    ; command should read from stdin.
    mov     rdi, STDIN_FD

    dcall   cat
    cmp     rax, 0
    jne     .error

    jmp     .success

.not_stdin:
.next_file:
    mov     rdi, [rsi] ; Grab the next filename.

    ; Check if the stdin alias has been specified as an arg.
    mov     rax, [rdi]
    cmp     al, stdin_filename
    cmp     ah, 0
    jne     .open_file

    ;--------------------
    ; Ok, arg is exactly "-", so read from stdin.

    ; The return code (fd) from the elided open(2) call for stdin.
    mov     rax, STDIN_FD

    jmp     .file_opened

.open_file:
    mov     rsi, O_RDONLY
    dcall   open
    cmp     rax, -1
    je      .error

.file_opened:
    ; Save the fd
    mov     [rsp+.fd_in], rax

    ; Setup cat call
    mov     rdi, rax

    dcall   cat
    cmp     rax, 0
    jne     .error

.close_file:
    mov     rdi, [rsp+.fd_in]
    cmp     rdi, 0
    jle     .dont_close_file

    dcall   close
    cmp     rax, 0
    jne     .error

.dont_close_file:

    ; Update on the stack
    add     qword [rsp+.argv], 8 ; argv++
    dec     qword [rsp+.argc]    ; argc--

    ; Reload the values
    mov     rdi, [rsp+.argc]
    mov     rsi, [rsp+.argv]

    cmp     rdi, 0  ; argc was >=1, but is now zero!
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

;---------------------------------------------------------------------
; Description: Read a single file specified by it's file descriptor
;   and display to stdout.
;
; C prototype equivalent:
;
;     int cat(int fd);
;
; Parameters:
;
; - Input: RDI (int) - File descriptor to read from.
; - Output: RAX (integer) - 0 on success, or -1 on error.
;
; Notes:
;
; Limitations:
;
; See:
;
;---------------------------------------------------------------------

cat:
    ; 3 auto-allocated variables...
    prologue_with_vars 3

    ; ... and 1 manually allocated one.
    ;
    ; Allocate space for read buffer.
    sub         rsp, IO_READ_BUF_SIZE

    ;--------------------
    ; Stack offsets.

    .fd_in      equ     0   ; size_t: file descriptor.
    .bytes      equ     8   ; size_t: bytes read.
    .buffer     equ     16  ; IO_READ_BUF_SIZE bytes.
    .ret        equ     24  ; return value.

    ;--------------------
    ; Setup

    ; Assume failure. Pessimistic but safe.
    mov     qword [rsp+.ret], CMD_FAILED

    ;--------------------
    ; Checks

    cmp     rdi, 0
    jl     .error ; Invalid fd

    ;--------------------
    ; Save args

    mov     [rsp+.fd_in], rdi

    ;--------------------

.read_again:
    mov     rdi, [rsp+.fd_in]
    lea     rsi, [rsp+.buffer]
    mov     rdx, IO_READ_BUF_SIZE

    dcall   read_block

    cmp     rax, 0
    je      .success ; Reached EOF
    jl      .error

    ; Read was successful
    mov     [rsp+.bytes], rax ; Save byte count

    ; Write the block of data that's been read.
    mov     rdi, STDOUT_FD
    lea     rsi, [rsp+.buffer]
    mov     rdx, [rsp+.bytes]

    dcall   write_block

    cmp     rax, 1
    jge     .read_again
    jmp     .error

.success:
    mov     qword [rsp+.ret], CMD_OK

.out:
    add     rsp, IO_READ_BUF_SIZE
    epilogue_with_vars 3

    ret

.error:
    mov     qword [rsp+.ret], CMD_FAILED
    jmp     .out
