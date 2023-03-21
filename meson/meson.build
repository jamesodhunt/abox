#---------------------------------------------------------------------
# vim:set noexpandtab:
#---------------------------------------------------------------------
# Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
#
# SPDX-License-Identifier: Apache-2.0
#---------------------------------------------------------------------

find = find_program('find', required: true)

# FIXME: Use a VERSION file as an alternative to git?
git = find_program('git', required: false)

mkdir = find_program('mkdir', required: true)

#---------------------------------------------------------------------
# Options

enable_tests = get_option('tests')

#---------------------------------------------------------------------
# OS and architecture checks

required_system = 'linux'

if host_machine.system() != required_system
  error('Need @0@ system, found @1@'.format(required_system, host_machine.system()))
endif

required_arch = 'x86_64'

if host_machine.cpu_family() != required_arch
  error('Need @0@ architecture, found @1@'.format(required_arch, host_machine.cpu_family()))
endif

#---------------------------------------------------------------------
# C compiler options

add_project_arguments(
  # Compiler debug symbols
  '-gdwarf',

  # Disable optimisation
  '-O0',

  # Error on warning(s)
  '-Werror',

  language: 'c'
)

# C linker options

add_project_link_arguments(
  # Generate 64-bit binaries
  '-m64',

  # No Position Independent Code for sane debugging!
  '-no-pie',

  # Keep the frame pointer for sane debugging!
  '-fno-omit-frame-pointer',

  # NX: Disable executable stack
  '-Wl,-z,noexecstack',

  # Compiler debug symbols
  '-gdwarf',

  # Disable optimisation
  '-O0',

  language: 'c',
)

#---------------------------------------------------------------------
