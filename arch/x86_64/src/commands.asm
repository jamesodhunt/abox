;---------------------------------------------------------------------
; vim:set expandtab:
;---------------------------------------------------------------------
; Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
;
; SPDX-License-Identifier: Apache-2.0
;---------------------------------------------------------------------

global get_and_handle_command
global list_commands

%include "header.inc"

extern puts
extern printf
extern strcmp
extern write

extern commands
extern commands_count
extern handle_version

section .text

;---------------------------------------------------------------------
; Description: Determine the Command from argv and run it's handler.
;
; C prototype equivalent:
;
;     int get_and_handle_command(int argc, char *argv[]);
;
; Parameters:
;
; - Input: RDI (integer) - *original* argc.
; - Input: RSI (integer) - *original* argv array.
; - Output: RAX (integer) - result from handle_command().
;
; See: handle_command().
;---------------------------------------------------------------------

get_and_handle_command:
section .rodata
    .errInvalidCmd       db  "ERROR: invalid command",10
    .errInvalidCmd_len   equ $-.errInvalidCmd
section .text
    prologue_with_vars 3

    ;--------------------
    ; Stack offsets.

    .argc       equ     0   ; size_t.
    .argv       equ     8   ; "char **"
    .command    equ    16   ; "Command *"

    ;--------------------
    ; Save args

    mov     [rsp+.argc], rdi
    mov     [rsp+.argv], rsi

    ;--------------------

    ; Get argv[0] (command *name*, not path)
    mov     rdi, [rsi]
    dcall   get_command

    cmp     rax, 0
    je     .error_cmd_name_invalid

    ; Save the Command
    mov     [rsp+.command], rax

    ; Check if the multi-call binary has been called with a command
    ; and a version option:
    ;
    ; $ $binary $cmd -v
    ; $ $binary $cmd --version
    ;
    ; If so, handle the request on behalf of the command.

    cmp     qword [rsp+.argc], 2
    jne     .no_options_to_handle

    ; Specify the 1st actual arg (argv[1]).
    mov     rax, [rsp+.argv]
    mov     rdi, [rax+8]

    dcall   handle_version
    cmp     rax, 0

    ; Version handled, so exit.
    je      .out

    ; Check if a help option has been specified and display the
    ; Command-specific help as a convenience on behalf of the Command.

    ; Set up the parameters.
    mov     rdi, [rsp+.command]

    mov     rax, [rsp+.argv]
    mov     rsi, [rax+8] ; Specify the 1st actual arg (argv[1]).

    dcall   handle_cmd_help
    cmp     rax, 0

    ; Command help handled, so exit.
    je      .out

; There were no options that can be handled _here_ (but there might be
; command-specific options that the command will handle).
.no_options_to_handle:

    mov     rdi, [rsp+.command]
    mov     rsi, [rsp+.argc]
    mov     rdx, [rsp+.argv]

    ; Don't check return code, just pass it
    ; back to the caller.
    dcall   handle_command

.out:
    epilogue_with_vars 3
    ret

.error_cmd_name_invalid:
    mov     rdi, STDERR_FD
    mov     rsi, .errInvalidCmd
    mov     rdx, .errInvalidCmd_len
    dcall   write

    mov     rax, CMD_INVALID
    jmp     .out

;---------------------------------------------------------------------
; Description: Execute the handler for the specified Command.
;
; C prototype equivalent:
;
;     int handle_command(Command *command, int argc, char *argv[]);
;
; Parameters:
;
; - Input: RDI (address) - Pointer to Command object.
; - Input: RSI (integer) - modified argc.
; - Input: RDX (integer) - modified argv array.
; - Output: RAX (integer) - result:
;
;   |-----------------+------------------------------+-------------------|
;   | Return code     | Description                  | Error msg handler |
;   |-----------------+------------------------------+-------------------|
;   | CMD_OK          | Command successful           | n/a               |
;   |-----------------+------------------------------+-------------------|
;   | CMD_FAILED      | Command failed               | Command           |
;   |-----------------+------------------------------+-------------------|
;   | CMD_INVALID     | invalid Command              | caller            |
;   |-----------------+------------------------------+-------------------|
;   | CMD_NO_OPT      | missing Command option       | caller            |
;   | CMD_NO_ARG      | missing Command argument     | caller            |
;   |-----------------+------------------------------+-------------------|
;   | CMD_BAD_OPT     | invalid Command option       | caller            |
;   | CMD_BAD_OPT_VAL | invalid Command option value | caller            |
;   | CMD_BAD_ARG     | invalid Command argument     | caller            |
;   |-----------------+------------------------------+-------------------|
;
; Notes:
;
; - This function handles displaying the appropriate error message for
;   most of the command error scenarios listed above.
;
; - If the Command wants full control over the error messages, it should
;   display any messages it wishes and then return the generic
;   value -1 (CMD_FAILED).
;
; - `argc` and `argv` are *NOT* the same as those provided to a C
;   program as they do not contain the program name itself. Instead
;   these values reflect the _remaining_ arguments, not the original
;   ones used to run the program.
;
; Full details:
;
; |---------------------+-----------+------+-------|
; | Calling type        | arg count | argc | argv  |
; |---------------------+-----------+------+-------|
; | Called as multicall | 0         | 0    | 0     |
; | Called as multicall | 1         | 1    | <arg> |
; | Called as sym-link  | 0         | 0    | 0     |
; | Called as sym-link  | 1         | 1    | <arg> |
; |---------------------+-----------+------+-------|
;---------------------------------------------------------------------

handle_command:
section .rodata
    .errBadCmd            db  "ERROR: invalid command",10
    .errBadCmd_len        equ $-.errBadCmd

    ;--------------------

    .errNoCmdOpt          db  "ERROR: missing command option",10
    .errNoCmdOpt_len      equ $-.errNoCmdOpt

    .errNoCmdArg          db  "ERROR: missing command argument",10
    .errNoCmdArg_len      equ $-.errNoCmdArg

    ;--------------------

    .errBadCmdOpt         db  "ERROR: invalid command option",10
    .errBadCmdOpt_len     equ $-.errBadCmdOpt

    .errBadCmdOptVal      db  "ERROR: invalid command option value",10
    .errBadCmdOptVal_len  equ $-.errBadCmdOptVal

    .errBadCmdArg         db  "ERROR: invalid command argument",10
    .errBadCmdArg_len     equ $-.errBadCmdArg

section .text
    prologue_with_vars 0

    cmp     rdi, 0
    je     .error_invalid_cmd

    ; Load the handler address
    mov     rax, [rdi+Command.func]

    ; Arrange the arguments for the handler.
    mov     rdi, rsi
    mov     rsi, rdx

    ; Call the Command handler

    dcall   rax

    cmp     rax, CMD_OK
    je      .success

    cmp     rax, CMD_FAILED
    je      .error_cmd_failed

    cmp     rax, CMD_INVALID
    je      .error_invalid_cmd

    cmp     rax, CMD_NO_OPT
    je      .error_no_cmd_opt

    cmp     rax, CMD_NO_ARG
    je      .error_no_cmd_arg

    cmp     rax, CMD_BAD_OPT
    je      .error_bad_cmd_opt

    cmp     rax, CMD_BAD_OPT_VAL
    je      .error_bad_cmd_opt_val

    cmp     rax, CMD_BAD_ARG
    je      .error_bad_cmd_arg

    ; Catch-all for 'impossible' situations.
    jmp     .error

.success:
    mov     rax, 0

.out:
    epilogue_with_vars 0
    ret

.error_invalid_cmd:
    mov     rdi, STDERR_FD
    mov     rsi, .errBadCmd
    mov     rdx, .errBadCmd_len
    dcall   write

    mov     rax, CMD_INVALID
    jmp     .out

.error_no_cmd_opt:
    mov     rdi, STDERR_FD
    mov     rsi, .errNoCmdOpt
    mov     rdx, .errNoCmdOpt_len
    dcall   write

    mov     rax, CMD_NO_OPT
    jmp     .out

.error_no_cmd_arg:
    mov     rdi, STDERR_FD
    mov     rsi, .errNoCmdArg
    mov     rdx, .errNoCmdArg_len
    dcall   write

    mov     rax, CMD_NO_ARG
    jmp     .out

.error_bad_cmd_opt:
    mov     rdi, STDERR_FD
    mov     rsi, .errBadCmdOpt
    mov     rdx, .errBadCmdOpt_len
    dcall   write

    mov     rax, CMD_BAD_OPT
    jmp     .out

.error_bad_cmd_opt_val:
    mov     rdi, STDERR_FD
    mov     rsi, .errBadCmdOptVal
    mov     rdx, .errBadCmdOptVal_len
    dcall   write

    mov     rax, CMD_BAD_OPT_VAL
    jmp     .out

.error_bad_cmd_arg:
    mov     rdi, STDERR_FD
    mov     rsi, .errBadCmdArg
    mov     rdx, .errBadCmdArg_len
    dcall   write

    mov     rax, CMD_BAD_ARG
    jmp     .out

.error:
.error_cmd_failed:
    mov     rax, CMD_FAILED
    jmp     .out

;---------------------------------------------------------------------
; Description: .
;
; C prototype equivalent:
;
;     void *get_command(const char *name);
;
; Parameters:
;
; - Input: RDI (string) - name of command.
; - Output: RAX (address) - Address of Command, or 0 if not found.
;
; Notes:
;
; Limitations:
;
; See:
;
;---------------------------------------------------------------------

get_command:
    prologue_with_vars 3

    ;--------------------
    ; Stack offsets.

    .name       equ     0   ; "const char *"
    .command    equ     8   ; "Command *"
    .count      equ    16   ; size_t: commands_count

    ;--------------------
    ; Save arg

    mov     [rsp+.name], rdi

    ;--------------------
    ; Load values

    mov     qword [rsp+.command], commands

    mov     rax, [commands_count]
    mov     [rsp+.count], rax

.loop:
    cmp     qword [rsp+.count], 0
    je      .error

    mov     rdi, [rsp+.name]
    mov     rax, [rsp+.command]
    mov     rsi, [rax+Command.name]

    dcall   strcmp

    cmp     rax, 0
    jz     .got_it

    dec     qword [rsp+.count]

    ; Move to next entry in array.
    add     qword [rsp+.command], Command_size

    jmp     .loop

.done:

.out:
    epilogue_with_vars 3
    ret

.error:
    mov     rax, 0 ; Command not found
    jmp     .out

.got_it:
    mov     rax, [rsp+.command] ; Return the address of the Command.
    jmp     .out

;---------------------------------------------------------------------
; Description: List all available commands, one per line to stdout.
;
; C prototype equivalent:
;
;     int list_commands(void);
;
; Parameters:
;
; - Output: RAX (integer) - 0 on success, or -1 on error .
;
; Notes:
;
; Limitations:
;
; See:
;
;---------------------------------------------------------------------

list_commands:
    prologue_with_vars 2

    ;--------------------
    ; Stack offsets.

    .command    equ     0   ; "Command *"
    .count      equ     8   ; size_t: commands_count

    ;--------------------
    ; Setup

    ; Load address of Command's array
    mov     qword [rsp+.command], commands

    ; Load count of available commands
    mov     rax, [commands_count]
    mov     [rsp+.count], rax

.loop:
    cmp     qword [rsp+.count], 0
    je      .done

    mov     rax, [rsp+.command]
    mov     rdi, [rax+Command.name]

    dcall   puts

    dec     qword [rsp+.count]

    ; Move to next entry in array.
    add     qword [rsp+.command], Command_size

    jmp     .loop

.done:
    mov     rax, 0 ; Set return code

.out:
    epilogue_with_vars 2
    ret

;---------------------------------------------------------------------
; Description: Handle the command-specific help statement.
;
; C prototype equivalent:
;
;     int handle_cmd_help(const Command *cmd, const char *argv1);
;
; Parameters:
;
; - Input: RDI (address) - Command object.
; - Input: RSI (address) - address of first actual string argument
;   (which might be a short or long help option).
; - Output: RAX (integer) - 0 on success (denoting that the string
;   argument was a help option), -1 on error.
;
; Notes:
;
; FIXME: TODO:
; On success show_help() will have been called so the caller of
; this function can immediately exit.
;---------------------------------------------------------------------

handle_cmd_help:
section .rodata
    .short_help_opt     equ  '-h'
    .long_help_opt      db   "--help",0
    .fmt                db   "Usage: %s",10,0
section .text
    prologue_with_vars 1

    ;--------------------
    ; Stack offsets.

    .command    equ     0   ; "Command *"

    ;--------------------

    cmp     rdi, 0
    je      .error ; Invalid Command specified.

    ; Save Command
    mov     [rsp+.command], rdi

    ; Load the *value* of the argument.
    mov     rbx, [rsi]

    ; Check if it's the short option.
    cmp     bx, .short_help_opt
    je      .show_cmd_help

    ; Not a short option so check if the long option
    ; equivalent was specified.

.try_long_opt:
    mov     rdi, rsi
    mov     rsi, .long_help_opt
    dcall   strcmp
    jz      .show_cmd_help

    mov     rax, -1 ; Failure.

.out:
    epilogue_with_vars 1
    ret

.show_cmd_help:
    mov     rdi, .fmt
    mov     rax, [rsp+.command]
    mov     rsi, [rax+Command.help]
    xor     rax, rax
    dcall   printf

    mov     rax, 0 ; Success.
    jmp     .out

.error:
    mov     rax, -1 ; Error.
    jmp     .out
