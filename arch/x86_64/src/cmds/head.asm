;---------------------------------------------------------------------
; vim:set expandtab:
;---------------------------------------------------------------------
; Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
;
; SPDX-License-Identifier: Apache-2.0
;---------------------------------------------------------------------

global command_help_head
global command_head

extern asm_getopt
extern asm_strchr
extern libc_strtol
extern read_block
extern write_block

extern close
extern open
extern optarg
extern write

extern optind

section .rodata
command_help_head:  db  "see head(1)",0

%include "header.inc"

section .text

;---------------------------------------------------------------------
; Object passed to a handler.
;
; [*] - The handler specific data is initialised to zero. the handler
;       can then use it to keep track of bytes / lines handled.
;---------------------------------------------------------------------
struc Block

%ifdef NASM
    align 8,db 0
%endif

%ifdef YASM
    align 8
%endif
    .amount  resq    1 ; size:t: Number of bytes or lines to handle in total.
    .bytes   resq    1 ; size_t: Number of bytes in buffer.
    .num     resq    1 ; size_t: Block number (1st is 0).
    .data    resq    1 ; size_t: Handler specific data [*].
    .done    resq    1 ; bool: Handler sets to indicate work complete.
    .buffer  resb    IO_READ_BUF_SIZE ; char array: file data to read.
endstruc

;---------------------------------------------------------------------
;
;---------------------------------------------------------------------

command_head:
section .rodata
    .optstring          db  "c:n:",0

    .short_bytes_opt    equ 'c'
    .long_bytes_opt     db  "--bytes",0     ; FIXME: long options not supported.

    .short_lines_opt    equ 'n'
    .long_lines_opt     db  "--lines",0     ; FIXME: long options not supported.

section .text
    prologue_with_vars 6

    ;--------------------
    ; Stack offsets.

    .argc       equ     0   ; int.
    .argv       equ     8   ; "char **"
    .amount     equ    16   ; size_t: number of lines or bytes.
    .use_bytes  equ    24   ; bool: bytes if true, else lines (default).
    .file_idx   equ    32   ; int: index into argc for file(s) to process.
    .fd_in      equ    40   ; int: file descriptor of file to read.

    ;--------------------
    ; Set defaults

    ; By default, head(1) prints the 1st 10 lines of a file.
    mov     qword [rsp+.use_bytes], 0
    mov     qword [rsp+.amount], 10

    ; XXX: Careful! optind and argc are 32-bit ints, so clear all
    ; 64-bits of each to avoid surprises!
    mov     qword [rsp+.file_idx], 0
    mov     qword [rsp+.argc], 0

    mov     qword [rsp+.fd_in], -1

    ;--------------------
    ; Save args

    mov     [rsp+.argc], rdi
    mov     [rsp+.argv], rsi

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
    cmp     al, .short_bytes_opt
    je      .handle_bytes_opt

    cmp     al, .short_lines_opt
    je      .handle_lines_opt

.handle_bytes_opt:
    mov     qword [rsp+.use_bytes], 1

    mov     rdi, [optarg]
    mov     rsi, BASE_10
    lea     rdx, [rsp+.amount]

    dcall   libc_strtol

    cmp     rax, 0
    jne     .error_bad_num

    jmp     .next_arg

.handle_lines_opt:
    mov     qword [rsp+.use_bytes], 0

    mov     rdi, [optarg]
    mov     rsi, BASE_10
    lea     rdx, [rsp+.amount]

    dcall   libc_strtol

    cmp     rax, 0
    jne     .error_bad_num

    jmp     .next_arg

    ;--------------------

.options_parsed:

    ; Now read all remaining args (from index optind to .argc)
    ; as files to operate on.
    mov     eax, [optind]
    mov     [rsp+.file_idx], eax

    mov     ecx, [rsp+.argc]
    cmp     ecx, optind
    je      .read_stdin ; No file arg specified.

.next_file:
    mov     ecx, [rsp+.file_idx]
    cmp     ecx, [rsp+.argc]
    je      .success ; No more files to process.

    mov     rdi, [rsp+.argv]

    ; Calculate index into the argv array.
    lea     rax, [ecx*8]
    add     rdi, rax
    mov     rdi, [rdi]

    ; FIXME: TODO: support magic "-" file (meaning stdin).
.open_file:
    mov     rsi, O_RDONLY
    dcall   open
    cmp     eax, -1
    je      .error_bad_file

    ; Save fd
    mov     [rsp+.fd_in], rax

    mov     rdi, rax
    mov     rsi, [rsp+.amount]
    mov     rdx, [rsp+.use_bytes]

    dcall   head
    cmp     rax, 0
    jl      .error

.close_file:
    mov     rdi, [rsp+.fd_in]
    cmp     rdi, 0 ; Is the file stdin?
    je      .dont_close_file

    dcall   close
    cmp     rax, 0
    jl      .error

.dont_close_file:

    ; Move to the next file
    inc     dword [rsp+.file_idx]

    jmp     .next_file

.success:
    mov     rax, 0

.out:
    epilogue_with_vars 6

    ret

.read_stdin:
    ; /dev/fd/0
    mov     rdi, STDIN_FD
    mov     rsi, [rsp+.amount]
    mov     rdx, [rsp+.use_bytes]

    dcall   head
    cmp     rax, 0
    jl      .error
    jmp     .success

.error_bad_num:
    mov     rax, CMD_BAD_OPT_VAL
    jmp     .out

.error_bad_option:
    mov     rax, CMD_BAD_OPT
    jmp     .out

.error_bad_file:
    mov     rax, CMD_BAD_ARG
    jmp     .out

.error:
    jmp     .out

;---------------------------------------------------------------------
; Description: Display the top of the file specified by the file
;   descriptor.
;
; C prototype equivalent:
;
;     int head(int fd, size_t amount, bool use_bytes);
;
; Parameters:
;
; - Input: RDI (integer) - 32-bit file descriptor.
; - Input: RSI (integer) - Amount of bytes or lines.
; - Input: RDX (bool) - if true, treat amount as bytes, else lines.
; - Output: RAX (integer) - 0 on success, or -1 on error.
;
; Notes:
;
; - This function reads the file into blocks and passes each
;   block to a handler: a bytes handler if use_bytes is true, else a line
;   handler. The handler has the following prototype:
;
;     int head_handler(int fd, Block *block);
;
;     Handler parameters:
;
;     - Input: RDI (int) - File descriptor.
;     - Input: RSI (Block *) - Block to handle.
;     - Output: RAX (integer) - 0 on success, or -1 on error.
;
; - The caller is responsible for closing the fd on error.
;
; Limitations:
;
; See:
;---------------------------------------------------------------------

head:
    ; This many auto-allocated variable...
    prologue_with_vars 6

    ; ... plus a manually allocated one.
    ;
    ; Allocate space for Block
    alloc_space Block_size

    ;--------------------
    ; Stack offsets.

    .fd_in      equ     0   ; size_t: (actually 32-bit) file descriptor.
    .amount     equ    16   ; size_t: file descriptor.
    .use_bytes  equ    24   ; bool: bytes if true, else lines (default).
    .ret        equ    32   ; return value.
    .handler    equ    40   ; void *: function pointer

    .block      equ    48   ; Block_size bytes.

    ;--------------------

    cmp     rdi, 0
    jl      .error ; Invalid fd.

    cmp     rsi, 0
    je      .success ; Nothing to do

    ;--------------------
    ; Save args

    mov     qword [rsp+.fd_in], 0
    mov     [rsp+.fd_in], edi

    mov     [rsp+.amount], rsi
    mov     [rsp+.use_bytes], rdx

    ;--------------------
    ; Setup

    ; Assume failure. Pessimistic but safe.
    mov     qword [rsp+.ret], CMD_FAILED

    lea     rax, [rsp+.block]   ; Get Block pointer

    mov     qword [rax+Block.amount], rsi
    mov     qword [rax+Block.num], 0
    mov     qword [rax+Block.data], 0
    mov     qword [rax+Block.done], 0

    ;--------------------
    ; Select handler

    cmp     qword [rsp+.use_bytes], 0
    je      .use_lines
    mov     qword [rsp+.handler], head_handle_bytes
    jmp     .selected_handler
.use_lines:
    mov     qword [rsp+.handler], head_handle_lines
.selected_handler:

    ;--------------------

.read_next_block:
    mov     rdi, [rsp+.fd_in]

    lea     rax, [rsp+.block]   ; Get Block pointer
    lea     rsi, [rax+Block.buffer]
    mov     rdx, IO_READ_BUF_SIZE

    dcall   read_block

    cmp     rax, 0
    je      .success ; EOF
    jl      .error

    lea     rdi, [rsp+.block]   ; Get Block pointer
    mov     [rdi+Block.bytes], rax ; Set actual byte count for handler.

    ; Call handler
    mov     rax, [rsp+.handler]
    dcall   rax

    cmp     rax, 0
    jl      .error

    lea     rbx, [rsp+.block]   ; Get Block pointer

    ; Check if handler signalled completion
    cmp     qword [rbx+Block.done], 1
    je      .success

    inc     qword [rbx+Block.num]

    jmp     .read_next_block

    ;--------------------

.success:
    mov     qword [rsp+.ret], 0

.out:
    ; Set return value
    mov     rax, [rsp+.ret]

    free_space  Block_size
    epilogue_with_vars 6
    ret

.error:
    mov     qword [rsp+.ret], CMD_FAILED
    jmp     .out

;---------------------------------------------------------------------
; Description: Display first 'n' bytes of top of the file specified
;   by the file descriptor.
;
; C prototype equivalent:
;
;     int head_handle_bytes(Block *block);
;
; Parameters:
;
; - Input: RDI (Block *) - Block structure.
; - Output: RAX (integer) - 0 on success, or -1 on error.
;
; Notes:
;
; Limitations:
;
; See:
;
;---------------------------------------------------------------------

head_handle_bytes:
    prologue_with_vars 1
    alloc_space      Block_size

    ;--------------------
    ; Stack offsets.

    .show_bytes equ     0   ; size_t: Number of bytes to display for this call.
    .block      equ     8   ; "Block *"

    ;--------------------

    cmp         rdi, 0
    je          .error

    ;--------------------
    ; Save args

    mov         [rsp+.block], rdi

    ;--------------------
    ; Checks

    cmp         qword [rdi+Block.done], 1
    je          .success

    ; Check if we've handled all the data we've been asked to.
    mov         rax, [rdi+Block.amount]
    cmp         rax, [rdi+Block.data]
    jne         .more_data_to_process

    mov         qword [rdi+Block.done], 1
    jmp         .success

.more_data_to_process:

    ; Calculate remaining bytes to handle
    sub         rax, [rdi+Block.data]

    ; Compare remaining bytes with bytes in block
    cmp         rax, [rdi+Block.bytes]
    jl          .show_partial_buffer

    ; show full buffer
    mov         rax, [rdi+Block.bytes]
    mov         [rsp+.show_bytes], rax
    jmp         .calculted_bytes_to_write

.show_partial_buffer:
    mov         [rsp+.show_bytes], rax

.calculted_bytes_to_write:

    ; if (remaining >= bytes)
    ;     write_block(entire)
    ; else
    ;     write_block(partial)

    mov         rdi, STDOUT_FD

    mov         rax, [rsp+.block]
    lea         rsi, [rax+Block.buffer]
    mov         rdx, [rsp+.show_bytes]

    dcall       write_block
    cmp         rax, 0
    jl          .error

    mov         rbx, [rsp+.block]   ; Get Block pointer
    add         [rbx+Block.data], rax

.success:
    mov         rax, CMD_OK

.out:
    free_space  Block_size
    epilogue_with_vars 1
    ret

.error:
    mov         rax, CMD_FAILED
    jmp         .out

;---------------------------------------------------------------------
; Description: Display first 'n' lines of top of the file specified
;   by the file descriptor.
;
; C prototype equivalent:
;
;     int head_handle_lines(Block *block);
;
; Parameters:
;
; - Input: RDI (Block *) - Block structure.
; - Output: RAX (integer) - 0 on success, or -1 on error.
;
; Notes:
;
; Limitations:
;
; See:
;
;---------------------------------------------------------------------

head_handle_lines:
    prologue_with_vars 3
    alloc_space      Block_size

    ;--------------------
    ; Stack offsets.

    .show_lines equ     0   ; size_t: Number of lines to display for this call.
    .start      equ     8   ; "char *": Address of start of line in .block.buffer.
    .end        equ    16   ; "char *": Address of end of line in .block.buffer.
    .block      equ    24   ; "Block *"

    ;--------------------

    cmp         rdi, 0
    je          .error

    ;--------------------
    ; Save args

    mov         [rsp+.block], rdi

    ;--------------------
    ; Setup

    ; start = Block->buffer;
    lea         rax, [rdi+Block.buffer]
    mov         [rsp+.start], rax

    ;--------------------
    ; Checks

    cmp         qword [rdi+Block.done], 1
    je          .success

    ; Check if we've handled all the data we've been asked to.
    mov         rax, [rdi+Block.amount]
    cmp         rax, [rdi+Block.data]
    jne         .more_data_to_process

    mov         qword [rdi+Block.done], 1
    jmp         .success

.more_data_to_process:
.next_line:

    mov         rdi, [rsp+.start]
    mov         esi, NL

    dcall       asm_strchr

    mov         [rsp+.end], rax

    ; If strchr returns NULL, there are no more (full) lines remaining
    ; in the block, so try to handle a final partial line (without a
    ; trailing NL).
    cmp         rax, 0

    je          .handle_partial_block

    ;------------------------------
    ; Handle complete line

    ; Calculate bytes in line
    sub         rax, [rsp+.start]

    inc         rax ; Also include the NL we just found in the output.

    mov         rdx, rax ; bytes to display
    mov         rdi, STDOUT_FD

    mov         rsi, [rsp+.start]

    dcall       write_block

    ; Jump over the already displayed NL
    inc         qword [rsp+.end]

    ; Set start = end.
    mov         rax, [rsp+.end]
    mov         [rsp+.start], rax

    ; Increment number of lines displayed count.
    mov         rax, [rsp+.block]
    inc         qword [rax+Block.data]

    mov         rbx, [rax+Block.amount]
    cmp         rbx, [rax+Block.data]
    jne         .next_line

    ; We've displayed all the lines requested,
    ; so signal the caller.
    mov         qword [rax+Block.done], 1
    jmp         .success

.handle_partial_block:
    mov         rax, [rsp+.end]
    cmp         rax, 0
    jne         .error ; We expect end to be null for a partial block.

    ; Set end to the end byte of the buffer
    ; (buffer address + bytes)
    mov         rax, [rsp+.block]
    mov         rbx, [rax+Block.buffer]
    add         rbx, [rax+Block.bytes]
    mov         [rsp+.end], rbx

    ; Calculate bytes to display (end - start)
    mov         rdx, rbx
    sub         rdx, [rsp+.start]

    mov         rdi, STDOUT_FD
    mov         rsi, [rsp+.start]

    dcall       write_block
    cmp         rax, 0
    jl          .error

    ;--------------------

.success:
    mov         rax, CMD_OK

.out:
    add         rsp, Block_size
    epilogue_with_vars 3
    ret

.error:
    mov         rax, CMD_FAILED
    jmp         .out
