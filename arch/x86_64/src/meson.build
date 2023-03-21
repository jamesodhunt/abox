#---------------------------------------------------------------------
# vim:set noexpandtab:
#---------------------------------------------------------------------
# Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
#
# SPDX-License-Identifier: Apache-2.0
#---------------------------------------------------------------------

src_cmds_dir = join_paths('.', 'cmds')
src_cmds_dir_full = join_paths(meson.current_source_dir(), src_cmds_dir)

asm_cmd_sources_list = run_command(find,
  src_cmds_dir,
  '-type', 'f',
  '-name', '*.asm',
  capture: true,
  check: true,
)

# The list of available commands / subcommands
# (aka the available "applets" (busybox) or "toys" (toybox)).
asm_cmd_sources = asm_cmd_sources_list.stdout().strip().split('\n')

# These files comprise the core of the program.
asm_main_sources = files(
  'main.asm',
  'commands.asm',
  'version.asm',
)

# List of all source files that need to be assembled.
asm_sources = []

asm_sources += asm_main_sources
asm_sources += asm_cmd_sources

#------------------------------
# This header file is generated, but not built.

defines_file = 'defines.inc'

generated_defines_file = custom_target(
    defines_file,
    output: defines_file,
    command: [util_script,
      'generate', 'defines',
      '@OUTPUT@',
    ],
    build_always_stale: true,
)

#------------------------------

details_file = 'details.asm'

generated_details_file = custom_target(
    details_file,
    output: details_file,
    command: [util_script,
      'generate', 'details',
      name,
      git_version,
      '@OUTPUT@',
    ],
    build_always_stale: true,
)

#------------------------------

commands_data_file = 'commands-data.asm'

generated_cmds_file = custom_target(
    commands_data_file,
    output: commands_data_file,
    command: [util_script,
      'generate', 'commands',
      src_cmds_dir_full,
      '@OUTPUT@',
    ],
    build_always_stale: true,
)

#------------------------------

# List of *TARGETS* for generated files
generated_src_file_targets = []

generated_src_file_targets += generated_cmds_file
generated_src_file_targets += generated_defines_file
generated_src_file_targets += generated_details_file

# List of all assembler object files.
asm_objects = []

# List of additional C source files (for debugging).
#
# This is useful for debugging purposes. Since the assemblers do not
# create debug symbols for structures (DWARF `DW_TAG_structure_type`),
# you cannot cast to compound (struct) types in gdb(1). However, a
# workaround is to define a C type with the same layout as the ASM
# "struc" (macro!) type but with a different name. You can then cast the ASM type
# to the C type in gdb!
extra_c_sources = get_option('extra_c_sources')

# XXX: Crucial!
asm_sources += generated_src_file_targets

generated_src_files_to_build = []

generated_src_files_to_build += commands_data_file
generated_src_files_to_build += details_file

#---------------------------------------------------------------------
# Usable Intel assemblers

nasm_cmd = 'nasm'
yasm_cmd = 'yasm'

# Note that we could call meson.get_compiler('nasm'), but that's not
# helpful since yasm is only used as a fallback if nasm is not
# available. The problem is that for debugging, yasm is superior to
# nasm as it appears to support a higher DWARF level, meaning that a
# yasm-compiled program can be debugged with gdb(1) and show assembler
# source. NASM v2.16 cannot do that.
nasm = find_program(nasm_cmd, required: false)
yasm = find_program(yasm_cmd, required: false)

compiler = meson.get_compiler('c')

# XXX: You don't appear to be able to query a compilers path, hence
# this is required:
compiler_binary = find_program(compiler.get_id())

if not nasm.found() and not yasm.found()
  error('Need either @0@ or @1@'.format(nasm_cmd, yasm_cmd))
endif

#---------------------------------------------------------------------
# Assembler handling

assembler_to_use = get_option('assembler')

if assembler_to_use == 'nasm'
  assembler = nasm
  assembler_name = nasm_cmd
else
  assembler = yasm
  assembler_name = yasm_cmd
endif

if not assembler.found()
  error('Assembler @0@ not available'.format(assembler_to_use))
endif

generic_assembler_args = []

generic_assembler_args += ['-I', '@0@'.format(include_dir)]
generic_assembler_args += ['-I', '@0@'.format(generated_dir)]
generic_assembler_args += ['-f', 'elf64']
generic_assembler_args += ['-o', '@OUTPUT@']
generic_assembler_args += '@INPUT@'

if get_option('buildtype') == 'debug'
  generic_assembler_args += '-DDEBUG'
endif

if get_option('buildtype') != 'release'
  generic_assembler_args += '-O0'
endif

if get_option('buildtype') == 'release'
  generic_assembler_args += '-DRELEASE'
endif

nasm_assembler_args = []

nasm_assembler_args += '-DNASM'
nasm_assembler_args += '-w+all'
nasm_assembler_args += '-w+error'
nasm_assembler_args += ['-g', '-Fdwarf']

yasm_assembler_args = []

yasm_assembler_args += '-DYASM'
yasm_assembler_args += '-Werror'
yasm_assembler_args += '-gdwarf2'

if assembler == nasm
  assembler_specific_args = nasm_assembler_args
else
  assembler_specific_args = yasm_assembler_args
endif

# XXX: Note: do *NOT* use "capture:true" as it results in empty
# XXX: object files!
asm_gen_special = generator(assembler,
    output: '@BASENAME@.o',
    arguments: [
      generic_assembler_args,
      assembler_specific_args,
    ],
    depends: generated_src_file_targets,
)

#---------------------------------------------------------------------

generated_sources = []

generated_sources += join_paths(meson.current_build_dir(), details_file)
generated_sources += join_paths(meson.current_build_dir(), commands_data_file)

asm_gen = generator(assembler,
    output: '@BASENAME@.o',
    arguments: [
      generic_assembler_args,
      assembler_specific_args,
    ],
    depends: generated_src_file_targets,
)

#---------------------------------------------------------------------
subdir('utils')

asm_sources += asm_utils_sources

#---------------------------------------------------------------------

# Create the objects from the source file using the generator.
asm_objects += asm_gen.process(asm_sources)

#---------------------------------------------------------------------

summary('type', get_option('buildtype'), section: 'build')

summary('name', assembler_name, section: 'assembler')
summary('version', assembler.version(), section: 'assembler')
summary('path', assembler, section: 'assembler')
summary('generic-args', ' '.join(generic_assembler_args), section: 'assembler')
summary('assembler-args', ' '.join(assembler_specific_args), section: 'assembler')

summary('name', compiler.get_id(), section: 'compiler')
summary('version', compiler.version(), section: 'compiler')
summary('path', compiler_binary.full_path(), section: 'compiler')
