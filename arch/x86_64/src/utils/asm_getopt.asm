;---------------------------------------------------------------------
; vim:set expandtab:
;---------------------------------------------------------------------
; Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
;
; SPDX-License-Identifier: Apache-2.0
;---------------------------------------------------------------------

%include "header.inc"

global asm_getopt

extern asm_strlen
extern dprintf

;---------------------------------------------------------------------
; These symbols are provided by libc. See getopt(3) for details.

; Type: "char *".
; Description: Option argument.
; Defined in libc section: BSS
; Initial value (as defined by POSIX): 0
extern optarg

; Type: int
; Description: Next argc value (aka argv element) to be processed.
; Defined in libc section: DATA
; Initial value (as defined by POSIX): 1
extern optind

; Type: int
; Description: Set if errors should be displayed to stderr.
; Defined in libc section: DATA
; Initial value (as defined by POSIX): 1
extern opterr

; Type: int
; Description: Invalid option char when '?' returned.
; Defined in libc section: DATA
; Initial value (as defined by POSIX): '?'
extern optopt

;---------------------------------------------------------------------
; Description: Assembly implementation of getopt(3).
;
; C prototype equivalent:
;
;     int asm_getopt(int argc, char *const argv[], const char *optstring);
;
; Parameters:
;
; - Input: RDI (integer) - argc.
; - Input: RSI (integer) - argv.
; - Input: RDX (integer) - optstring.
; - Output: RAX (integer) - 0 on success, or -1 on error.
;
; Notes:
;
; - We _could_ implement and call asm_strchr to search within optstring
;   however that needs to calculate the length of the optstring each time
;   it is called. Since we would need to call strchr for each argument, that
;   seems inefficient so instead we calculate the length of the
;   optstring once and then call scasb each time.
;
; - This implementation sets 'optopt' after every call. This ensures the
;   implementation can be tested fully. Note that this is not required by
;   POSIX, and, indeed, the glibc implementation only updates 'optopt' on
;   (every) error (meaning it can never be reset once an error has
;   occurred.
;
; Limitations:
;
; - Only supports basic POSIX behaviour: the first non-option
;   argument results in asm_getopt() returning -1 and 'optind' is not
;   updated.
;
;   See: https://pubs.opengroup.org/onlinepubs/9699919799.2018edition/
;
; - Although option bundling is supported for an option and its
;   argument, full option bundling (where multiple boolean options can
;   share a single dash) is not supported:
;
;   prog -a -b -c foo  # OK
;   prog -a -b -cfoo   # OK
;   prog -ab   -cfoo   # Not supported.
;
; - Does not support "magic" optstring prefixes '+', '-' or ':'.
;
; - Does not support long ("--foo") options yet.
;
; BUGS:
;
; - The code is horrid and needs a thorough review + refactor!
;---------------------------------------------------------------------

%ifdef NO_LIBC
; If we are not linking against libc, we need to define our own
; version of these symbols. See getopt(3) for more details.
section .bss
    optarg: resq 0  ; "char *": option argument.

section .data
    optind: dd 1    ; int: next argc value (aka argv element) to be processed.
    opterr: dd 1    ; int: true if errors should be displayed to stderr.
    optopt: dd '?'  ; int: invalid option char when '?' returned.

section .text

%endif ; NO_LIBC

asm_getopt:
section .rodata
    .invalid_opt_fmt    db   "%s: invalid option -- '%c'",10,0
    .ret_no_more_options     equ -1
    .short_opt_prefix        equ '-'

    .short_opt_invalid       equ '?'
    .short_opt_missing_arg   equ ':'
section .bss
    .program_name    resq    0 ; "char *" pointer

;---------------------------------------------------------------------

section .text

    prologue_with_vars 7

    ;--------------------
    ; Stack offsets.

    .argc           equ      0  ; size_t.
    .argv           equ      8  ; "char **"
    .optstring      equ     16  ; "const char *"
    .optstring_len  equ     24  ; size_t
    .curr_opt       equ     32  ; char: current option being handled.
    .bundled_arg    equ     40  ; "char *".

    ; An option arg needs the next argument for it's value.
    ; This is needed to handle the scenario where optstring might be
    ; "a:" but the complete argv vector is:
    ;
    ; "prog", "-a", NULL
    ;
    ; In this scenario, getopt must return '?' to denote a missing
    ; option argument.
    .need_arg       equ     48  ; bool: option arg needs next arg for it's value

    ;--------------------
    ; argc must be > 1 as argv[0] is the program name.
    cmp     rdi, 1
    jle     .error

    ; argv == NULL.
    cmp     rsi, 0
    je      .error

    ; Invalid optstring
    cmp     rdx, 0
    je      .error

    ;--------------------
    ; Save program name
    mov     rax, [rsi]
    mov     [.program_name], rax

    ;--------------------
    ; Save actual args

    mov     [rsp+.argc], rdi
    mov     [rsp+.argv], rsi
    mov     [rsp+.optstring], rdx

    ;--------------------
    ; Set defaults

    mov     qword [rsp+.need_arg], 0
    mov     qword [optarg], 0

    ;--------------------
    ; Calculate length of optstring

    mov     rdi, [rsp+.optstring]
    dcall   asm_strlen

    ; FIXME: scasb seems to need 1 byte extra in the rax count?!?
    inc     rax
    mov     [rsp+.optstring_len], rax

    ; Check the next CLI arg to see if it's an option.
.next_arg:
    mov     rax, [optind]
    mov     rbx, [rsp+.argc]
    cmp     rax, rbx
    je      .no_more_options

    ; Get address of next argument by indexing into the argv array:
    ;
    ;   rbx = argv[optind]
    mov     rcx, [rsp+.argv]
    mov     rax, [rcx + 8*rax] ; char *rax = argv[optind].

    ; Save, even if not a bundle arg "just in case"
    mov     [rsp+.bundled_arg], rax

    mov     rcx, [rax] ; rcx = first 8 chars

    ; check if 1st char denotes an option
    cmp     cl, .short_opt_prefix

    jne     .handle_non_option_arg

    ; Check for an option which is exactly "-", a common alias for
    ; stdin, but not a valid getopt option.
    ;
    ; Note that in POSIXLY_CORRECT mode, this single dash
    ; causes getopt to stop parsing arguments *BUT* unlike "--",
    ; optind is *not* updated!
    cmp     ch, 0
    je      .handle_end_of_options_single_dash

    ; Now, check to see if we've found "--", which means
    ; "end of options".
    cmp     ch, .short_opt_prefix
    je      .consume_end_of_options_double_dash

    mov     rax, rcx
    shr     rax, (2*8) ; Remove 1st two bytes ('-' and option char).
    cmp     al, 0
    je      .no_bundled_arg

    ; Arg was a bundled arg, so remove 1st 2 bytes
    add     qword [rsp+.bundled_arg], 2

    jmp     .saved_bundle_arg

.handle_non_option_arg:
    ; A non option argument should not consume an optind entry.
    mov     rax, .ret_no_more_options
    jmp     .out_dont_update_optind

.no_bundled_arg:
    mov     qword [rsp+.bundled_arg], 0 ; set bundle_arg = NULL

    ; @@ fall through @@

.saved_bundle_arg:

    ; FIXME: Now, we need to check the char *after* the option char. If
    ; it's 0, it's a normal option, but if it's not, this is a bundled
    ; option:
    ;
    ;   -c foo   # Not bundled.
    ;
    ; Compared with:
    ;
    ;   -cfoo    # Bundled.
    ;
    ; For a bundled option, we need to shift the 1st 2 chars off the
    ; string by incrementing the pointer twice (aka remove '-c'). What
    ; remains need to be assigned to optarg.

    xor     rax, rax
    mov     al, ch ; set option char to look for

    mov     rdi, [rsp+.optstring]
    mov     rcx, [rsp+.optstring_len]

    repne   scasb    ; Repeatedly search for byte.
    jnz     .invalid_option_char

    cmp     rcx, 0
    je      .invalid_option_char

    ; We read a valid option char, so save it
    mov     qword [rsp+.curr_opt], 0
    mov     [rsp+.curr_opt], al

    ; XXX: rdi and the index value in rcx both now point one byte
    ; *beyond* the option character.

    mov     rbx, [rdi] ; read next char in optstring

    cmp     bl, ':'
    je      .get_option_arg

    ; Reset
    mov     qword [rsp+.need_arg], 0

    ; rdi now points at the next option char, or the end of
    ; optstring. Either way, the option we found is valid.
    jmp     .option_valid

    ; FIXME:

.option_valid:
    ; al already contains the option char
    jmp     .out

.get_option_arg:
    ; We need 1 more arg for this options value.
    mov     qword [rsp+.need_arg], 1

    cmp     qword [rsp+.bundled_arg], 0
    je      .get_next_arg ; no bundled arg, so get next arg

    ; We've got a bundle arg, so "return" it in optarg.

    mov     rax, [rsp+.bundled_arg]
    mov     [optarg], rax

    jmp     .set_option_char

.set_optopt:
    mov     rbx, [rsp+.curr_opt]
    mov     [optopt], rbx
    jmp     .no_more_options

.get_next_arg:
    ; Consume next CLI arg as it's this options argument.
    inc     dword [optind]

    mov     rax, [optind]
    mov     rbx, [rsp+.argc]
    cmp     rax, rbx
    je      .set_optopt

    ; Save next arg in optarg for caller.
    mov     rcx, [rsp+.argv]

    mov     rbx, [rcx + 8*rax] ; char *rax = argv[optind].
    mov     [optarg], rbx

.set_option_char:
    xor     rax, rax

    ; Option character to return.
    mov     eax, [rsp+.curr_opt]

    ; Clear top 56 bits, leaving the lowest 8 bits set - the character
    ; to return.
    and     rax, 0xff

    jmp     .out

.invalid_option_char:
    cmp     qword [opterr], 0
    je      .no_invalid_option_err_msg

    mov     [optopt], rax ; Save the invalid option char

    mov     rdi, STDERR_FD
    mov     rsi, .invalid_opt_fmt
    mov     rdx, [.program_name]
    mov     rcx, [optopt]

    xor     rax, rax
    dcall   dprintf

.no_invalid_option_err_msg:
    mov     rax, .short_opt_invalid
    jmp     .out

.handle_missing_arg:
    mov     rax, .short_opt_invalid
    jmp     .error_return

.no_more_options:
    cmp     qword [rsp+.need_arg], 1
    je      .handle_missing_arg

    ; getopt(3) does this.
    inc     dword [optind]

    mov     rax, .ret_no_more_options
    jmp     .out_dont_update_optind

    ; We found "--" meaning ignore what follows. But we
    ; still need to update optind to consume the end-of-options marker
    ; argument!
.consume_end_of_options_double_dash:
    inc     dword [optind]
    mov     rax, .ret_no_more_options
    jmp     .out_dont_update_optind

    ; Got a "-" meaning stop processing options. Crucially do *NOT*
    ; update optind.
.handle_end_of_options_single_dash:
    mov     rax, .ret_no_more_options
    jmp     .out_dont_update_optind

.out:
    ; optind++. Note that the variable is incremented on success
    ; *and* failure!
    inc     dword [optind]

.out_dont_update_optind:

    mov     dword [optopt], 0 ; Success

.error_return:
    epilogue_with_vars 7
    ret

.error:
    xor     rax, rax
    mov     eax, -1

    ; Do what getopt(3) does.
    mov     dword [optopt], 0

    jmp     .error_return
