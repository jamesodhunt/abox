;---------------------------------------------------------------------
; vim:set noexpandtab:
;---------------------------------------------------------------------
; Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
;
; SPDX-License-Identifier: Apache-2.0
;---------------------------------------------------------------------

%ifndef _command_included
%define _command_included 1

; Define the structure to hold a command.
struc Command

%ifdef NASM
	align 8,db 0
%endif

%ifdef YASM
	align 8
%endif

	; Name of command (required).
	.name    resq    1 ; (const char * const) string pointer.

	; Handler function (required).
	.func    resq    1 ; (void *) address pointer to handler function.

	; Null-terminated usage message (optional).
	.help    resq    1 ; (const char * const) string pointer.
endstruc

; See handle_command()
CMD_OK				equ		 0
CMD_FAILED			equ		-1
CMD_INVALID			equ		-2
CMD_NO_OPT			equ		-3
CMD_NO_ARG			equ		-4
CMD_BAD_OPT			equ		-5
CMD_BAD_OPT_VAL		equ		-6
CMD_BAD_ARG			equ		-7

;---------------------------------------------------------------------
%endif ; _command_included
