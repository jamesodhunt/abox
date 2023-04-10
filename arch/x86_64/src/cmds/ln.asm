;---------------------------------------------------------------------
; vim:set expandtab:
;---------------------------------------------------------------------
; Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
;
; SPDX-License-Identifier: Apache-2.0
;---------------------------------------------------------------------

global command_help_ln
global command_ln

extern asm_getopt
extern get_errno

extern close
extern dprintf
extern link
extern mkdtemp
extern mkstemp
extern remove
extern rename
extern sprintf
extern symlink
extern unlink
extern write

extern optind

section .rodata
command_help_ln:  db  "see ln(1)",0

%include "header.inc"

section .text

;---------------------------------------------------------------------
;
;---------------------------------------------------------------------

command_ln:
section .rodata
    .errArgCount            db   "ERROR: Usage: <target> <link-name>",10,0
    .errArgCountLen         equ  $-.errArgCount-1
    .optstring          db  "fs",0
    .force_opt          equ 'f'
    .symlink_opt        equ 's'

section .text
    prologue_with_vars 7

    ;--------------------
    ; Stack offsets.

    ; Params
    .argc           equ      0  ; int.
    .argv           equ      8  ; "char **"
    .file_idx       equ     16  ; int: index into argc for file args to process.

    .target_name    equ     24  ; "char *" value.
    .link_name      equ     32  ; "char *" value.

    ; Create a symlink if true, else create a hard link.
    .symlink        equ     40  ; bool value:
    .force          equ     48  ; bool value.

    ;--------------------
    ; Save args

    mov     [rsp+.argc], rdi
    mov     [rsp+.argv], rsi

    ;--------------------
    ; Set defaults

    mov     qword [rsp+.symlink], 0
    mov     qword [rsp+.force], 0

    ; XXX: Careful! optind and argc are 32-bit ints, so clear all
    ; 64-bits of each to avoid surprises!
    mov     qword [rsp+.file_idx], 0

    ;--------------------

.next_arg:
    mov     rdi, [rsp+.argc]
    mov     rsi, [rsp+.argv]
    mov     rdx, .optstring

    ; Note: No call to consume_program_name as
    ; getopt expects to find argc+argv unmolested!
    dcall   asm_getopt

    cmp     eax, -1 ; End of options
    jz      .options_parsed

    cmp     ax, '--' ; End of options
    jz      .options_parsed

    cmp     al, '?'
    jz      .error_bad_option

    ;------------------------------

    cmp     al, .force_opt
    je      .handle_force_opt

    cmp     al, .symlink_opt
    je      .handle_symlink_opt

.handle_force_opt:
    mov     qword [rsp+.force], 1
    jmp     .next_arg

.handle_symlink_opt:
    mov     qword [rsp+.symlink], 1
    jmp     .next_arg

.options_parsed:

    ; Now read all remaining args (from index optind to .argc)
    ; as files to operate on.
    mov     eax, [optind]
    mov     [rsp+.file_idx], eax

    mov     ecx, [rsp+.argc]
    sub     ecx, eax

    ; Limitation: we currently require both arguments.
    cmp     ecx, 2
    jl     .error_arg_count

    ;------------------------------
    ; Calculate index into the argv array for the args.

    ; get target name
    mov     eax, [optind]
    cdqe

    lea     rbx, [rax*PTR_SIZE]

    mov     rdi, [rsp+.argv]

    add     rdi, rbx
    mov     rdi, [rdi]
    mov     [rsp+.target_name], rdi

    ; get link name
    mov     eax, [optind]
    cdqe
    inc     rax

    lea     rbx, [rax*PTR_SIZE]

    mov     rdi, [rsp+.argv]

    add     rdi, rbx
    mov     rdi, [rdi]
    mov     [rsp+.link_name], rdi

;------------------------------

    mov     rdi, [rsp+.target_name]
    mov     rsi, [rsp+.link_name]
    mov     rdx, [rsp+.symlink]
    mov     rcx, [rsp+.force]

    dcall   ln
    cmp     rax, 0
    jne     .error

.success:
    mov     rax, CMD_OK

.out:
    epilogue_with_vars 7

    ret

.error_bad_option:
    mov     rax, CMD_BAD_OPT
    jmp     .out

.error_arg_count:
    mov     rsi, .errArgCount
    mov     rdx, .errArgCountLen
    jmp     .handle_error

.handle_error:
    mov     rdi, STDERR_FD
    dcall   write
    mov     rax, CMD_FAILED
    jmp     .out

.error:
    mov     rax, CMD_FAILED
    jmp     .out

;---------------------------------------------------------------------
; Description: ln(1).
;
; C prototype equivalent:
;
;     int ln(const char *target, const char *link, bool symlink);
;
; Parameters:
;
; - Input: RDI (address) - "char *": Name of file to create link for.
; - Input: RSI (address) - "char *": Name of link to create.
; - Input: RDX (integer) - bool: create symlink if true,
;     else hard link.
; - Input: RCX (integer) - bool: force creation if true,
;     else fail if link exists.
; - Output: RAX (integer) - 0 on success, or -1 on error.
;---------------------------------------------------------------------

ln:
section .rodata
    .path_fmt        db  "%s/%s",0
    .eexist_fmt      db  "ln: failed to create %s link '%s': File exists",10,0
    .link_type_hard  db  "hard",0
    .link_type_soft  db  "symbolic",0

section .data
    .tmpdir_template    db  "abox-ln-tmpdir-XXXXXX",0
    .tmpfile_template   db  "abox-ln-tmpfile-XXXXXX",0
section .text
    prologue_with_vars 4

    alloc_space PATH_MAX

    ;--------------------
    ; Stack offsets.

    ; Params
    .target_name    equ     0  ; "char *".
    .link_name      equ     8  ; "char *".

    ; Create a symlink if true, else create a hard link.
    .symlink        equ    16  ; bool value:
    .force          equ    24  ; bool value.

    .path           equ    32  ; char[PATH_MAX]

    ;--------------------
    ; Save args

    mov     [rsp+.target_name], rdi
    mov     [rsp+.link_name], rsi
    mov     [rsp+.symlink], rdx
    mov     [rsp+.force], rcx

    ;--------------------

    cmp     qword [rsp+.force], 1
    jne     .no_force

    ;--------------------
    ; Force the operation by creating a link from the file to a
    ; temporary file in a temporary directory, then atomically
    ; renaming the temporary file to the (existing) link name.

    ; First, create the tmpdir
    mov     rdi, .tmpdir_template
    dcall   mkdtemp
    cmp     rax, 0
    je      .error

    ; Next, construct the path template for the temporary file inside
    ; the temporary directory.
    lea     rdi, [rsp+.path]
    mov     rsi, .path_fmt
    mov     rdx, .tmpdir_template
    mov     rcx, .tmpfile_template
    xor     rax, rax ; No fp args

    dcall   sprintf

    cmp     rax, PATH_MAX
    jg      .error ; Path was truncated (buffer overflow).
    cmp     rax, 0
    je      .error ; No output produced.

    ; Now, create the tmp file inside the tmpdir.
    lea     rdi, [rsp+.path]
    dcall   mkstemp
    cmp     rax, 0
    jl      .error

    ; The tmpfile now exists, so close the fd as we don't need it:
    ; it's enough to know the file exists in the temporary directory.
    mov     rdi, rax
    dcall   close

    ; Now, delete the file as we know the name is unique
    ; in the directory.
    lea     rdi, [rsp+.path]
    dcall   unlink

    ; Finally, link to the just-deleted temporary name.
    mov     rdi, [rsp+.target_name]
    lea     rsi, [rsp+.path]

    jmp     .handled_force

.no_force:

    mov     rdi, [rsp+.target_name]
    mov     rsi, [rsp+.link_name]

.handled_force:

    cmp     qword [rsp+.symlink], 0
    je      .handle_hard_link

    dcall   symlink
    jmp     .check_result

.handle_hard_link:
    dcall   link

.check_result:
    cmp     rax, 0
    je      .checked_result

    dcall   get_errno
    cmp     rax, EEXIST
    je      .handle_file_exists

    jmp     .error

.checked_result:
    cmp     qword [rsp+.force], 1
    jne     .success

    ; Finish off the force operating by renaming the temporary file over
    ; the top of any existing link.

    lea     rdi, [rsp+.path]
    mov     rsi, [rsp+.link_name]
    dcall   rename
    cmp     rax, 0
    jl      .error

    cmp     qword [rsp+.symlink], 1
    je      .success

    ; For hard links, we need to remove the temporary file link.
    mov     rdi, .tmpfile_template
    dcall   unlink

.success:
    mov     rax, CMD_OK

.out:
    free_space PATH_MAX

    epilogue_with_vars 4

    ret

.error:

    ;--------------------
    ; Something bad happened so attempt to clean up by removing the
    ; tmpfile and tmpdir, but ignoring the return value as we're already
    ; in an error path.

    ; First, try to remove the tmpfile.
    mov     rdi, .tmpfile_template
    dcall   remove

    ; Next, try to remove the now-hopefully empty directory.
    lea     rdi, [rsp+.path]
    dcall   remove

    mov     rax, CMD_FAILED
    jmp     .out

.handle_file_exists:
    ; The destination file already exists and the user did not specify
    ; the force option so display an error and fail.

    mov     rdi, STDERR_FD
    mov     rsi, .eexist_fmt

    cmp     qword [rsp+.symlink], 1
    je     .use_soft_fmt

    lea     rdx, .link_type_hard
    jmp     .selected_fmt

.use_soft_fmt:
    lea     rdx, .link_type_soft

.selected_fmt:
    mov     rcx, [rsp+.link_name]
    xor     rax, rax
    dcall   dprintf

    jmp     .error
