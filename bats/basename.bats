#!/usr/bin/env bats
#---------------------------------------------------------------------
# vim:set noexpandtab:
#---------------------------------------------------------------------
# Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
#
# SPDX-License-Identifier: Apache-2.0
#---------------------------------------------------------------------

load 'test-common.bats'

@test "basename with no argument" {
	local cmd='basename'

	# Handle specially due to the null argument
	local cmd_path=$(clean_path "${CMD_DIR}/${cmd}")

	run \
		--keep-empty-lines \
		--separate-stderr \
		-- \
		"$cmd_path"

	[ "$status" -eq 1 ]

	[ ${#lines[@]} = 0 ]

	[ ${#stderr_lines[@]} = 1 ]

	grep -q "ERROR: missing command argument" <<< "${stderr_lines[0]}"
}

@test "basename with empty argument" {
	test_cmd 'basename' ""
	[ "$status" -eq 0 ]

	[ -z "${lines[-1]}" ] && unset 'lines[-1]'
	[ "${lines[0]}" = '' ]
	[ ${#lines[@]} = 1 ]
}

@test "basename with non path argument" {
	local arg='foo'

	test_cmd 'basename' $arg
	[ "$status" -eq 0 ]

	[ -z "${lines[-1]}" ] && unset 'lines[-1]'
	[ ${#lines[@]} = 1 ]
	[ "${lines[0]}" = "$arg" ]
}

@test "basename with non existant path argument" {
	local arg='/foo/bar/baz'
	local basename=$(basename "$arg")

	test_cmd 'basename' $arg
	[ "$status" -eq 0 ]
	[ -z "${lines[-1]}" ] && unset 'lines[-1]'
	[ ${#lines[@]} = 1 ]
	[ "${lines[0]}" = "$basename" ]
}

@test "basename with actual path argument" {
	local arg="$BATS_TEST_FILENAME"
	local basename=$(basename "$arg")

	test_cmd 'basename' $arg
	[ "$status" -eq 0 ]
	[ -z "${lines[-1]}" ] && unset 'lines[-1]'
	[ ${#lines[@]} = 1 ]
	[ "${lines[0]}" = "$basename" ]
}

@test "basename with valid pathological values" {
	# Key: Input value.
	# Value: Expected output value.
	local -A tests=(
			['foo']='foo'
			['/foo']='foo'
			['////foo']='foo'
			['foo////']='foo'
			['////foo////']='foo'
			['/']='/'
			['.']='.'
			['..']='..'
			['../']='..'
			['///..///']='..'
			['///..///..']='..'
			['///ab///..']='..'
			['//']='/'
			['///']='/'
			['/////']='/'
			['// ///']=' '
			['/ / / / /']=' '
			['  / / / / /   ']='   '
			['////foo////bar////baz///']='baz'
			['/foo bar']='foo bar'
			['/foo  bar']='foo  bar'
			['/foo  bar  ']='foo  bar  '
			['/  foo  bar  ']='  foo  bar  '
			['  /  foo  bar  /   ']='   '
	)

	local t
	local -i i=0

	for t in "${!tests[@]}"
	do
		local value="${tests[$t]}"

		log "test[$i]: '$t', expected value: '$value'"

		test_cmd 'basename' "$t"

		[ "$status" -eq 0 ]
		[ -z "${lines[-1]}" ] && unset 'lines[-1]'
		[ ${#lines[@]} = 1 ]

		[ "${lines[0]}" = "$value" ]

		i=$((i+1))
	done
}
