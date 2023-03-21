#---------------------------------------------------------------------
# vim:set noexpandtab:
#---------------------------------------------------------------------
# Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
#
# SPDX-License-Identifier: Apache-2.0
#---------------------------------------------------------------------

# A source tree directory
include_dir = join_paths(meson.current_source_dir(), 'include')

# This directory will be created below the *build directory*.
generated_dir = join_paths(meson.current_build_dir(), 'src')

subdir('src')

include_directories('include')

check_target = run_target('check',
  command : [util_script, 'check', meson.current_source_dir()]
)
