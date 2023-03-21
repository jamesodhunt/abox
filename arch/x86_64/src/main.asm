;---------------------------------------------------------------------
; vim:set expandtab:
;---------------------------------------------------------------------
; Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
;
; SPDX-License-Identifier: Apache-2.0
;---------------------------------------------------------------------

;---------------------------------------------------------------------
; Description: abox main.
; Language: ASM, assembler, assembly language, NASM, YASM.
; uses:libc
;---------------------------------------------------------------------

%include "header.inc"

global abox_environ
global stdin_alias
global main

extern exit
extern fflush
extern printf
extern puts
extern strcmp
extern write

extern asm_strlen
extern basename
extern get_and_handle_command
extern list_commands
extern multicall_name
extern multicall_name_len
extern show_version

;---------------------------------------------------------------------
; Constants

section .rodata
    short_help_opt      equ '-h'
    long_help_opt       db  "--help",0

    short_list_opt      equ '-l'
    long_list_opt       db  "--list",0

    short_version_opt   equ '-v'
    long_version_opt    db  "--version",0

    errInvalidOpt   db  "ERROR: invalid option",10
    errInvalidOpt_len   equ $-errInvalidOpt

    usage_fmt           db  "Usage: %s [function [arguments]...]",10, \
    "   or: [function [arguments]...]",10, \
    "   or: %s [-h, --help]",10, \
    "   or: %s [-l, --list]",10, \
    "   or: %s [-v, --version]",10,0

    ; Used for commands like cat(1) and head(1).
    stdin_alias    db  "-",0

;---------------------------------------------------------------------
; Globals

section .bss
    ; FIXME: not needed.
    ; Original argv[0]
    program_path      resq    1 ; "char *" pointer

    ; Cleaned name (path removed)
    ; This will either be `multicall_name`, or the name of a Command.
    program_name      resq    1 ; "char *" pointer

    ; "Command *" pointer (set if not called as a multi-call binary).
    command           resq    1

    ; Global since used by the env command.
    abox_environ      resq    1  ; "char **" pointer to environment variables.

;---------------------------------------------------------------------

section .text

;---------------------------------------------------------------------
; Description: Entry point.
;
; C prototype equivalent:
;
;     int32_t main(int32_t argc, char *argv[], char *environ[]);
;
; Notes:
;
; CLI parameters are passed to main like this:
;
; Register   C equivalent  Description
; ---------|------------|------------------
; rdi        argc         Argument count.
; rsi        argv         Argument array (termined with a NULL element).
; rdx        environ      Env var array (termined with a NULL element).
;---------------------------------------------------------------------
; TODO: Switch to using asm_getopt for arg parsing (once it supports
; long options too!
;---------------------------------------------------------------------

main:
    prologue_with_vars 2

    ;--------------------
    ; Stack offsets

    .argc       equ     0   ; size_t.
    .argv       equ     8   ; "char **"

    ;--------------------
    ; Save arguments

    mov     [rsp+.argc], rdi
    mov     [rsp+.argv], rsi
    mov     [abox_environ], rdx ; This needs to be global

    ;--------------------

    mov     rax, [rsi]          ; Get argv
    mov     [program_path], rax ; Save program *path* (argv[0]).

    ; Remove the path from the program name
    mov     rdi, rax
    dcall   basename
    cmp     rax, 0
    je      .error

    ; Save the returned program *name*.
    mov     [program_name], rax

    ; See how we were called (either as the multi-call
    ; binary name, or as the name of one of the commands).
.check_name:
    mov     rsi, [program_name]
    mov     rdi, multicall_name

    xor     rax, rax
    mov     al, [multicall_name_len]
    mov     rcx, rax

    cld
    repe    cmpsb

    ;------------------------------------------------------------
    ; Binary has been called with the multi-call name.
    ;------------------------------------------------------------

    jz     .got_abox

    ;------------------------------------------------------------
    ; Binary has been called as a sym-linked command name.
    ;
    ; Before passing control to the command, check if a version
    ; option was specified since (unlike a help option!), this can be
    ; handled generically here.

.not_abox:
    mov     rdi, [rsp+.argc]
    mov     rsi, [rsp+.argv]

    ; Overwrite the sym-link path with the sym-link name
    mov     rax, [program_name]
    mov     [rsi], rax

    jmp     .call_handle_command

    ; Handle the help option on behalf of the Command
    ; as a convenience.
    ; FIXME: this should be handled by calling handle_cmd_help!
.handle_command_help:
section .rodata
    .help_fmt     db "Usage: %s",10,0
section .text

    mov     rax, [command]
    mov     rdi, .help_fmt
    mov     rsi, [rax+Command.help]
    xor     rax, rax
    dcall   printf

    jmp     .success

.try_cmd_short_options:
    cmp     bx, short_version_opt
    je     .show_version

    cmp     bx, short_help_opt
    je     .handle_command_help

; Handle traditional (single-character) options.
;
; bh contains the short option
.handle_short_options:
    cmp     bx, short_help_opt
    je     .show_usage

    cmp     bx, short_list_opt
    je     .list_commands

    cmp     bx, short_version_opt
    je     .show_version

    jmp     .errInvalidOption

; Handle double-dash (long) options.
.handle_long_options:
    ; Restore argv
    mov     rax, [rsp+.argv]
    mov     rdi, [rax]

    mov     rsi, long_help_opt
    dcall   strcmp
    jz      .show_usage

    ; Restore argv
    mov     rax, [rsp+.argv]
    mov     rdi, [rax]

    mov     rsi, long_list_opt
    dcall   strcmp
    jz      .list_commands

    ; Restore argv
    mov     rax, [rsp+.argv]
    mov     rdi, [rax]

    mov     rsi, long_version_opt
    dcall   strcmp
    jz      .show_version

    jmp     .errInvalidOption

.success:
    mov     rdi, EXIT_SUCCESS

.out:

    push1   rdi ; Save return code

    ; fflush(NULL) to ensure that any data that's been written that
    ; did not end in a NL ('\n') is flushed to stdout/stderr.
    mov     rdi, 0
    dcall   fflush

    pop1    rdi ; Restore return code

    dcall   exit

    epilogue_with_vars 2

.error:
    mov     rdi, EXIT_FAILURE
    jmp     .out

; Assumes params have already been set up.
.call_handle_command:
    dcall   get_and_handle_command
    cmp     rax, CMD_OK
    je      .success

    ; Handle generic Command failure
    ; (or an impossible return value).
    jmp     .error

; Called as multi-call binary.
.got_abox:
    ; Remove multi-call program name from args
    dec     qword [rsp+.argc]     ; argc--
    add     qword [rsp+.argv], 8  ; argv++

    ; No arg specified to multi-call binary.
    cmp     qword [rsp+.argc], 0
    je     .show_usage

    ;----------------------------------------
    ; Check if an option was specified

    ; Load the *value* of the first argument (it's characters) into rbx.
    mov     rdi, [rsp+.argv]
    mov     rax, [rdi]
    mov     rbx, [rax]

    cmp     bx, long_opt_prefix
    je     .handle_long_options

    cmp     bl, short_opt_prefix
    je     .handle_short_options

    ; Not an option, so it must be a Command.
    mov     rdi, [rsp+.argc]
    mov     rsi, [rsp+.argv]

    jmp     .call_handle_command

.errInvalidOption:
    mov     rdi, STDERR_FD
    mov     rsi, errInvalidOpt
    mov     rdx, errInvalidOpt_len
    dcall   write

    jmp     .error

.command_failed:
    cmp     rdx, 0  ; Did the command specify an error message?
    je     .show_cmd_error_msg

    jmp     .error

.show_cmd_error_msg:

    push1   rdx ; Save error message.

    mov     rdi, rdx
    dcall   asm_strlen

    pop1     rdx ; Restore error message.

    mov     rdi, STDERR_FD
    mov     rsi, rdx ; The Command's error message
    mov     rdx, rax ; strlen
    dcall   write

.show_version:
    dcall   show_version
    jmp     .success

.show_usage:
    mov     rdi, usage_fmt
    mov     rsi, [program_name]
    mov     rdx, [program_name]
    mov     rcx, [program_name]
    mov     r8, [program_name]
    xor     rax, rax
    dcall   printf
    jmp     .success

.list_commands:
    dcall   list_commands
    cmp     rax, 0
    jnz     .error
    jmp     .success
