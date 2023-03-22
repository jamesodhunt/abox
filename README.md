# `abox`

Yet another simple [`busybox`](https://www.busybox.net) /
[`toybox`](https://landley.net/toybox) clone. This one is written in
Intel 64-bit assembly language (`x86_64`) for Linux.

> **Note:**
>
> There is no shell currently - I'm [working on it!](https://github.com/jamesodhunt/abox/issues/1) ;)

## Why?

Because I wanted an excuse to write some modern 64-bit Intel assembly
language.

## Dependencies

| Tool | Implementation | Required? | Rationale | Notes |
|-|-|-|-|-|
| Intel `x86_64` Assembler | NASM or YASM | yes ;) | | |
| C compiler | GCC or Clang | yes | For linking | |
| Build system | `meson` and `ninja` | yes | | |
| Make | GNU Make | no | Simplifies building | |
| C unit test framework | [`check`](https://github.com/libcheck/check) | no `(*)` | | aka `libcheck` |
| CLI tests | [BATS](https://github.com/bats-core/bats-core) | no `(*)` | CLI testing | |

`(*)` - The defaults assume these tools are present.

### Install dependencies on Fedora like system

```bash
$ sudo dnf -y install bats check make meson nasm ninja yasm
```

### Install dependencies on Debian / Ubuntu like system

```bash
$ sudo apt -y install bats check make meson nasm ninja-build yasm
```
## Usage

### Show help information

```bash
$ abox
$ abox help
$ abox -h
$ abox --help
```

### Show available commands

```bash
$ abox -l
$ abox --list
```

### Run a command

```bash
$ abox echo 'Hello from abox!'
```

## Build

### Development build

```bash
$ make && make test
```

### Release build

```bash
$ make RELEASE=1 && make test
```

## Install

> **FIXME: / TODO:**
>
> - Installing the binary.
> - Creating the sym-links.
