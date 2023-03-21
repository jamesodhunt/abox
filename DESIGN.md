# Design

Like `busybox` and `toybox`, `abox` is a single binary. It can be
built statically or dynamically and can be run either directly as a
multi-call binary (`abox $command`), or it can run via a sym-link
(assuming the name of the symlink is a valid `abox` command.

## Approach

### Overall

This project does not aim for the smallest possible binary or the
fastest possible implementation.

The main goal of this project is didactic: this is designed to be an
educational project, both for the authors and the readers of the
source. It also places a strong emphasis on correctness.

Learning assembly language programming is hard, particularly if you
only have cryptically terse uncommented source to read!

Hence, the primary concrete objective is to create a functional and
correct tool with a clear and easily understandable and maintainable
codebase.

### Phased development

#### Phase 1: Get it working

Initially, the code will make use of libc calls for convenience and
development speed.

#### Phase 2: Rewrite libc functions

Once the codebase is functionally complete and all tests are in place,
the intention is to remove the need for libc by switching to using
only system calls and assembly language implementations of libc
functions.

## Architecture

Although the code is 100% 64-bit Intel `x86_64` assembly code, the
source is structured in a way that it is possible to add additional
architectures.

## Details

- No crazy register shuffling (aka keeping all values in registers)

  Yes, it's incredibly efficient, but only a compiler can keep track
  of the code and it makes debugging very hard.

- No crazy stack manipulations.

  Overuse of `push` and `pop` is just as bad as register shuffling in
  terms of making the code difficult to understand.

  However, a single push and then referencing the value on the stack
  (via a macro / `equ` for clarity) is fine.

- No huge static buffers.

  Either allocate storage dynamically, or use the BSS segment with
  named variables (labels).

## Coding standard

- Comments should be used as much as possible to explain the code.

  Unlike higher level languages *all* assembly is cryptic so explain
  what you're doing!

- Use the stack (rather than the BSS section) for local variables. 

- Ensure the stack is 16-byte aligned.

- All commands must have a unit test.

- Labels should have meaningful names.

  No cryptic "compiler-generated" names!

- Commands should make all labels and variables private by using a dot
  prefix for all labels.

- Commands should use the `rodata` section where possible for defining
  constant strings.

- Commands should use an assembler directive (such as `equ`,
  `%define`, `%assign`, _etc_) for defining constants.

- Rather than calling a function using the `call` instruction, use the
  `dcall` macro. This detects stack misalignment issues for
  non-release builds and can be used to set a breakpoint on every
  `call` instruction.

## Adding a new command

- Create a new `.asm` file (`arch/x86_64/src/cmds/${command}.asm`).
- Create a `global` symbol for a function called `command_${command}`.
- Ensure the symbol/function creates and destroys a stack frame.
- The return code (in the `rax` register) should be:
  - `0` on success.
  - `-1` if the command failed.
  - `-2` if an option or argument was invalid.

  > **Notes:**
  >
  > - See `command.inc` for the symbolic names for standard error
  >   return values.
  >
  > - If an error occurs, the command should generally display an error
  >   message to `stderr` in addition to returning a negative value.

- The command will be passed it's arguments in the normal SysV ABI
  manner:

  - `rdi` contains the argument count (`argc`)
  - `rsi` contains containing the address of the argument array (`argv`).

- `argv[0]` will be set to the name of the command, not the name of
  the multi-call binary.

- Create a second `global` symbol called `command_help_${cmd}`.

  This should be a null-terminated string defined in the `.rodata`
  section that describes the command briefly and lists all available
  options (aka a usage statement).

### Example command

For example, to add a new `foo` command create
`arch/x86_64/src/cmds/foo.asm` containing:

```asm
global command_foo
global command_help_foo

section .rodata
command_help_foo:   db  "This command creates unicorns, ",10 \
                    db  "fairies and pixies.",10, \
                    db  10, \
                    db  "Options:",10, \
                    db  "-a : ...",10, \
                    db  "-b : ...",10, \
                    db  "-z : ...",10, \
                    db  "See echo(1)",0

section .text

;---------------------------------------------------------------------
; Description: Implement the standard `foo` command.
;
; C prototype equivalent:
;
;     int command_foo(int argc, char *argv[]);
;
; Parameters:
;
; - Input: RDI (integer) - argc.
; - Input: RSI (address) - argv.
; - Output: RAX (integer) - 0 on success, -1 on error.
;
; Notes:
;
; Limitations:
;
; See: `foo(1)`.
;
;---------------------------------------------------------------------

command_foo:
    ; Create stack frame
    push    rbp
    mov     rbp, rsp

    ; Preserve register value (callee saved)
    ; XXX: Also preserve r12, r13, r14, r15!
    push    rbx

    ;-----------------------------------
    ; FIXME: function body goes here.
    ;-----------------------------------

.out:
    ; Restore callee saved register
    pop     rbx

    ; Destroy stack frame
    leave

    ret
```

### Stack handling

To simplify stack handling and local variables, the convention is for
all functions to:

- Always create a stack frame.
- Always push and pop `rbx`.
- Adjust the stack pointer using a multiplication expression that
  represents the number of variables.
- Assume all fundamental type variables (at least int, pointer, char,
  even bool) occupy 8 bytes. This isn't efficient but it makes the code
  clearer.

#### Local variables

Use the `prologue_with_vars` and `epilogue_with_vars` macros to simplify
the code. Calls to these macros must be paired and called with the same
numeric values.

Example:

```asm
    ; Create stack frame, preserves rbx on the stack and "allocates" space
    ; on the stack for the specified number of 64-bit variables.
    prologue_with_vars 3

    ;--------------------
    ; Stack offsets.

    .var1       equ     0   ; int
    .var2       equ     8   ; "char *"
    .var3       equ     16  ; ssize_t

    ;--------------------

    ; ...

.out:
    ; "deallocates" stack space for specified number of variables (which
    ; obviously needs to be the same value passed to `prologue_with_vars`),
    ; destroys the stack frame, and restores rbx.
    epilogue_with_vars 3

    ; Return from function.
    ret
```

## Debugging

The assemblers do not create debug symbols for structures (DWARF `DW_TAG_structure_type`).
This means that you cannot cast to compound (C/C++ `struct`) types in gdb(1). However, a
workaround is to define a C type with the same layout as the ASM
`struc` (macro!) type but with a different name. You can then cast the ASM type
to the C type in gdb(1).

For example, to build with the C definition of the head commands `struc Block`:

```bash
$ make EXTRA_C_SOURCES="extra/c_block.c"
```

Then, assuming `rax` contains a pointer to a `struc Block`, you can run:

```bash
$ gdb abox
(gdb) p (CBlock *)$rax
```
