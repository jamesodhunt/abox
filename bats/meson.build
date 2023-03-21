#---------------------------------------------------------------------
# vim:set noexpandtab:
#---------------------------------------------------------------------
# Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
#
# SPDX-License-Identifier: Apache-2.0
#---------------------------------------------------------------------

if enable_tests
  # Used to basename a file.
  fs = import('fs')

  test_env = environment()

  # Variable used by the BATS tests.
  test_env.set('BUILD_DIR', meson.current_build_dir())

  bats = find_program('bats', required: true)

  bats_test_sources = run_command(find,
    '.',
    '-type', 'f',
    '-name', '*.bats',
    '-a',
    '!', '-name', 'test-common.bats',
    capture : true,
    check: true,
  )

  # Generate a test settings file. This is required as bats doesn't
  # allow arguments to be specified to a bats test ;(

  test_settings_file = 'generated-test-settings.sh'

  test_dir = join_paths(meson.current_build_dir(), 'test')

  generated_test_settings_file = custom_target(test_settings_file,
    output: test_settings_file,
    command: [util_script,
      'generate', 'test-settings',
      name,
      binary.full_path(),
      src_cmds_dir_full,
      test_dir,
      '@OUTPUT@',
    ],
    build_by_default: true,
    depends: binary,
  )

  bats_sources_array = bats_test_sources.stdout().strip().split('\n')

  foreach file: bats_sources_array
    test_script = files(file)

    # Remove annoying "./" prefix
    file_basename = fs.name(file)

    # Create a variable representing the script to run
    test_name = 'bats test @0@'.format(file_basename)

    # Create a test for the script file to run
    test(test_name,
      test_script,
      env: test_env,
      depends: generated_test_settings_file,
    )
  endforeach

endif
