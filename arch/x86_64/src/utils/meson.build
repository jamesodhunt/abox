#---------------------------------------------------------------------
# vim:set noexpandtab:
#---------------------------------------------------------------------
# Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
#
# SPDX-License-Identifier: Apache-2.0
#---------------------------------------------------------------------

asm_utils_sources_list = run_command(find,
   meson.current_source_dir(),
  '-type', 'f',
  '-name', '*.asm',
  capture: true,
  check: true,
)

asm_utils_sources = asm_utils_sources_list.stdout().strip().split('\n')
#asm_utils_sources = files('utils.asm')

asm_utils_objects = asm_gen.process(asm_utils_sources)

#---------------------------------------------------------------------

if enable_tests
  utils_test_sources = [asm_utils_objects, 'test_utils.c']

  # libcheck C test unit test framework
  check_dep = dependency('check')

  test_prog = executable('test-utils',
    utils_test_sources,
    dependencies: check_dep,
  )

  test('utils test', test_prog)

endif
