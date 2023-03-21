#---------------------------------------------------------------------
# vim:set noexpandtab:
#---------------------------------------------------------------------
# Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
#
# SPDX-License-Identifier: Apache-2.0
#---------------------------------------------------------------------

# Summary

project('abox',
  'c',
  version: '0.0.1',
  license: 'Apache-2.0',
  default_options: [
    'c_std=gnu99',
    'prefix=/usr',
  ],
  meson_version : '>= 0.62.0',
)

name = meson.project_name()

#---------------------------------------------------------------------
# Setup

root_dir = meson.current_source_dir()

scripts_dir = join_paths('.', 'scripts')
util_script = files(join_paths(scripts_dir, '@0@-util.sh'.format(name)))

#---------------------------------------------------------------------

subdir('meson')

if git.found()
    # Don't fail in case we're built from outside a git repo.
    git_version = run_command(git,
      'rev-parse',
      'HEAD',
      check: false).stdout().strip()
endif

if git_version == ''
    git_version = 'unknown-version'
endif

# Load source
subdir('arch/@0@'.format(required_arch))

objects = [asm_objects, extra_c_sources]

binary = executable(
  name,
  objects,
  install: true,
)

# Load tests
subdir('bats')

summary('BATS tests', enable_tests, section: 'tests')
summary('unit tests', enable_tests, section: 'tests')
summary(check_dep.name(), check_dep.version(), section: 'tests')
