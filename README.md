# `abox`

Yet another simple [`busybox`](https://www.busybox.net) /
[`toybox`](https://landley.net/toybox) clone. This one is written in
Intel 64-bit assembly language (`x86_64`) for Linux.

## Why?

Because I wanted an excuse to write some modern 64-bit Intel assembly
language.

## Commands

Currently, the following commands are implemented in some form:

```bash
$ abox -l | xargs
basename cat clear echo env false head ln pwd rm seq sleep sync touch true yes
```

> **Note:**
>
> There is no shell currently - I'm [working on it!](https://github.com/jamesodhunt/abox/issues/1) ;)

## Dependencies

| Tool | Implementation | Required? | Rationale | Notes |
|-|-|-|-|-|
| Intel `x86_64` Assembler | NASM or YASM | yes ;) | | |
| C compiler | GCC or Clang | yes | For linking | |
| Build system | `meson` and `ninja` | yes | | |
| Make | GNU Make | no | Simplifies building | |
| C unit test framework | [`check`](https://github.com/libcheck/check) | no `(*)` | | aka `libcheck` |
| CLI tests | [BATS](https://github.com/bats-core/bats-core) | no `(*)` | [CLI testing](bats) | |
| `moreutils` package | `errno` command | yes | Used by [`abox-util.sh`](scripts/abox-util.sh) to generate definitions | |

`(*)` - The defaults assume these tools are present.

### Install dependencies on Fedora like system

```bash
$ sudo dnf -y install @development-tools
$ sudo dnf -y install bats check make meson moreutils nasm ninja-build yasm
```

### Install dependencies on Debian / Ubuntu like system

> **Notes:**
>
> - The version of `meson` provided by Ubuntu is too old,
>   so you need to install a more recent version using `pip`.
>
> - If you want to run the BATS tests, you will need to be running
>   Ubuntu 22.10 or newer to install `bats` version 1.5.0+.
>   Alternatively, [you can install it manually](https://github.com/bats-core/bats-core).

```bash
$ sudo apt -y install bats build-essential check errno make nasm ninja-build python3-pip yasm
$ python3 -m pip install meson
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
