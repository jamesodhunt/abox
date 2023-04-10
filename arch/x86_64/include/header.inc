;---------------------------------------------------------------------
; vim:set noexpandtab:
;---------------------------------------------------------------------
; Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
;
; SPDX-License-Identifier: Apache-2.0
;---------------------------------------------------------------------

%ifndef _header_included
%define _header_included 1

bits 64

short_opt_prefix 	equ '-'
long_opt_prefix 	equ '--'

; Used for commands like cat(1) and head(1).
stdin_filename  	equ '-'

; STD{IN,OUT,ERR}_FILENO values.
%assign STDIN_FD	0
%assign STDOUT_FD	1
%assign STDERR_FD	2

;---------------------------------------------------------------------
; See open(2).

%assign O_RDONLY		0x0
%assign O_WRONLY		0x1
%assign O_RDWR			0x2
%assign O_CREAT			0x40
%assign O_EXCL			0x80
%assign O_NOCTTY		0x100
%assign O_NONBLOCK		0x800
%assign O_LARGEFILE		0x8000

%assign AT_FDCWD		-100

;---------------------------------------------------------------------

NULL			equ		 0
EXIT_SUCCESS	equ		 0
EXIT_FAILURE	equ		 1
EOF				equ		-1
BASE_10			equ		10

; Number of bytes in a pointer/size_t.
PTR_SIZE		equ		 8

; FIXME: Should call pathconf(_PC_PATH_MAX).
PATH_MAX		equ		 4096

; FIXME: Should call sysconf(_SC_PAGESIZE).
PAGE_SIZE       equ      4096

; A "reasonable" size for a buffer that will be used to perform I/O.
IO_READ_BUF_SIZE        equ     (PAGE_SIZE * 16)

; SysV ABI for Intel x86-64 mandates this alignment.
%assign STACK_ALIGN_BYTES   16

;---------------------------------------------------------------------
; See ascii(7).

; Newline character ('\n').
NL				equ		10

; ESC (0o33)
%assign CONSOLE_ESC		0x1b

;---------------------------------------------------------------------

%include "command.inc"
%include "defines.inc"

;---------------------------------------------------------------------
; Description: Call a function but crash if stack not aligned before
;   the call.
;
; Parameters:
;
; - Input: label (function name) / address / register.
;
; Notes:
;
; - If building a release build, this macro will simply call
;   the specified label.
; - A simpler implementation is to call pushfq, test TF, then popfq.
;   However, in reality this fails when run under a debugger such as
;   gdb(1) since the pop ends up setting TF even if it wasn't originally
;   set!
;---------------------------------------------------------------------

%ifdef RELEASE

%macro dcall 1
	call %1
%endmacro

%else ; !RELEASE

%macro dcall 1

    sub     rsp, 8 ; Adjust stack alignment for push.
    push    rax
    lahf

    ;sub     rsp, 8 ; Adjust stack alignment for pushfq.

    ;pushfq ; Save RFLAGS as we're about to modify it.

	test	rsp, 0xf   ; Sets ZF if bottom 4 bits of rsp==0.

	jz		%%.call_%1_stack_is_aligned

	; Stack is misaligned, so force a crash.
	ud2

; Create a macro-specific (aka unique) label name.
; This allows the macro to be called as many times as necessary.
%%.call_%1_stack_is_aligned:

;%ifdef BREAK_ON_FUNC_CALL

;    ; Force enable Trap Flag TF (single-step)
;    pushf
;    xor		qword [rsp], 0x100
;    popf

;%endif ; BREAK_ON_FUNC_CALL

    pop     rax
    add     rsp, 8 ; Adjust stack alignment for pop.

    ;popfq  ; Restore RFLAGS.

    ;add     rsp, 8 ; Undo stack alignment for pushfq.

	call	%1

;%ifdef BREAK_ON_FUNC_CALL
;    ; Disable TF (single-step)
;    pushf
;    and	qword [rsp], ~0x100
;    popf
;%endif ; BREAK_ON_FUNC_CALL

%endmacro

%endif ; RELEASE

;---------------------------------------------------------------------
; Description: Push a single register and align the stack
;   on a 16-byte boundary.
;
; Parameters:
;
; - Input: register.
;
; Notes:
;
; Must be paired with a subsequent call to pop1.
;---------------------------------------------------------------------

%macro push1 1
    push    %1
    sub     rsp, 8 ; Align stack on 16-byte boundary
%endmacro

;---------------------------------------------------------------------
; Description: Pop a value off the stack into the specified register
;   and undo stack alignment.
;
; Parameters:
;
; - Input: register.
;
; Notes:
;
; Must be paired with a subsequent call to push1.
;---------------------------------------------------------------------

%macro pop1 1
    add     rsp, 8 ; unalign stack
    pop     %1
%endmacro

;---------------------------------------------------------------------
; Description: Create a function prologue.
;
; Parameters: None.
;
; Notes:
;
; - Call at start of function.
; - If a function requires local variables, use prologue_with_vars
;   instead.
;---------------------------------------------------------------------

%macro prologue 0
    push    rbp        ; Align stack to 16-byte boundary (x86_64 ABI requirement)
    mov     rbp, rsp   ; Create stack frame.

    push    rbx        ; Save/preserve callee-saved register.
%endmacro

;---------------------------------------------------------------------
; Description: Create a function prologue and "allocate" space on the
;   stack for the specified number of 64-bit variables.
;
; Parameters: Number of 8-byte variables to allocate space for.
;
; Notes:
;
; Must be paired with a call to epilogue_with_vars specifying the same
; parameter value to undo the allocation.
;---------------------------------------------------------------------

%macro prologue_with_vars 1
    prologue

%if %1 > 0
    ; Align stack for specified number of variables, ensuring
    ; 16-byte overall alignment.
    ;
    sub     rsp, (8 + (%1 * 8) + ((%1 % 2) * 8))
    ;             ~    ~~~~~~     ~~~~~~~~~~~~
    ;             |       |             |
    ;            (a)     (b)           (c)
    ;
    ; Key:
    ;
    ; - (a) - Adjustment for rbx push.
    ; - (b) - space for variables.
    ; - (c) - Adjustment to correct alignment if number
    ;   of variables is odd.
%else
    sub     rsp, 8 ; Just adjust for rbx push.
%endif

%endmacro

;---------------------------------------------------------------------
; Description: Allocate space on the stack.
;
; Parameters: Number of 8-byte blocks to allocate.
;
; Notes:
;
; - Call at start of function.
; - Must be paired with a call to free_space.
;---------------------------------------------------------------------

%macro alloc_space 1
    %if %1 <= 0
        %error "ERROR: assertion failed: alloc_space > 0"
    %endif

	; Round the requested value up to ensure the stack is 16-byte
	; aligned.
    sub     rsp, (%1 + STACK_ALIGN_BYTES - (%1 % STACK_ALIGN_BYTES))
%endmacro

;---------------------------------------------------------------------
; Description: Deallocate/free space back the stack.
;
; Parameters: Number of 8-byte blocks to deallocate.
;
; Notes:
;
; - Call at end of function.
; - Must be paired with a call to alloc_space.
;---------------------------------------------------------------------

%macro free_space 1
    %if %1 <= 0
        %error "ERROR: assertion failed: free_space > 0"
    %endif

	; Round the requested value up to ensure the stack is 16-byte
	; aligned.
    add     rsp, (%1 + STACK_ALIGN_BYTES - (%1 % STACK_ALIGN_BYTES))
%endmacro

;---------------------------------------------------------------------
; Description: Create a function epilogue.
;
; Parameters: None.
;
; Notes:
;
; - Call at start of function.
; - XXX: Note that it does *not* return - the caller must call 'ret'!
; - If the function uses local variables, use epilogue_with_vars
;   instead.
;---------------------------------------------------------------------

%macro epilogue 0
    pop     rbx        ; Restore callee saved register.

    ; Equivalent to:
    ;
    ;     mov rsp, rbp
    ;     pop rbp
    leave
%endmacro

;---------------------------------------------------------------------
; Description: Create a function epilogue and "deallocate" space on
;   the stack for the specified number of 64-bit variables.
;
; Parameters: Number of 8-byte variables to deallocate.
;
; Notes:
;
; - Call at end of function.
; - Must be paired with a call to prologue_with_vars.
; - XXX: Note that it does *not* return - the caller must call 'ret'!
;---------------------------------------------------------------------

%macro epilogue_with_vars 1
%if %1 > 0
    add     rsp, (8 + (%1 * 8) + ((%1 % 2) * 8))
%else
    add     rsp, 8 ; Just adjust for rbx push.
%endif

    epilogue

%endmacro

;---------------------------------------------------------------------
; Description: Remove the program name element from a command handler
;   function with the following main()-like prototype:
;
;     int32_t command_handler(int32_t argc, char *argv[]);
;
; Register   C equivalent  Description
; ---------|------------|------------------
; rdi        argc         Argument count.
; rsi        argv         Argument array (termined with a NULL element).
;
; Notes:
;
; This should be called by all command handlers that don't care which
; name they were called by.
;---------------------------------------------------------------------

%macro consume_program_name 0
    ; Remove program name from args.
    dec     rdi    ; argc--
    add     rsi, 8 ; argv++
%endmacro

;---------------------------------------------------------------------
; Structures

struc Timespec
	.tv_sec		resq	1 ; 8 byte (unsigned) time_t
	.tv_nsec	resq	1 ; 8 byte (unsigned) time_t
endstruc

%endif ; _header_included
