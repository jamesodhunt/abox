#!/usr/bin/env bats
#---------------------------------------------------------------------
# vim:set noexpandtab:
#---------------------------------------------------------------------
# Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
#
# SPDX-License-Identifier: Apache-2.0
#---------------------------------------------------------------------

load 'test-common.bats'

@test "sleep no args" {
	local cmd='sleep'
	local cmd_path=$(clean_path "${CMD_DIR}/${cmd}")
	[ -x "$cmd_path" ]

	test_cmd "$cmd"
	[ "$status" -eq 1 ]
	[ ${#lines[@]} = 0 ]
	[ ${#stderr_lines[@]} = 1 ]
	grep -q 'ERROR: invalid command argumen' <<< "${stderr_lines[0]}"
}

@test "sleep invalid args" {
	local cmd='sleep'
	local cmd_path=$(clean_path "${CMD_DIR}/${cmd}")
	[ -x "$cmd_path" ]

	local arg
	local -a args

	args+=('-1')
	args+=('-1s')
	args+=('-3m')
	args+=('-5h')
	args+=('6g')
	args+=('-7d')
	args+=('-9.789s')
	args+=('a3.141d')
	args+=('foo bar7.2s')
	args+=('hello')

	for arg in "${args[@]}"
	do
		test_cmd "$cmd" "$arg"
		[ "$status" -eq 1 ]
		[ "${#lines[@]}" -eq 0 ]
		[ "${#stderr_lines[@]}" -eq 1 ]
		grep -q 'ERROR: invalid command argument' <<< "${stderr_lines[0]}"
	done
}

@test "sleep 1s valid args" {
	local cmd='sleep'
	local cmd_path=$(clean_path "${CMD_DIR}/${cmd}")
	[ -x "$cmd_path" ]

	local arg
	local -a args

	# Test all format variants
	args+=('1')
	args+=('1.0')
	args+=('1.00')
	args+=('1.0000000')
	args+=('1s')
	args+=('1.0s')
	args+=('1.0000000s')

	local expected='1.000000000'

	for arg in "${args[@]}"
	do
		test_cmd_unquoted_args "$cmd" '-n' "$arg"

		[ "$status" -eq 0 ]

		[ -z "${lines[-1]}" ] && unset 'lines[-1]'
		[ "${#lines[@]}" -eq 1 ]
		grep -q "^${expected}$" <<< "${lines[0]}"
	done
}

@test "sleep valid args" {
	local cmd='sleep'
	local cmd_path=$(clean_path "${CMD_DIR}/${cmd}")
	[ -x "$cmd_path" ]

	local t
	local -a tests

	# 2 colon-separated fields:
	#
	# field 1: Input value.
	# field 2: Expected output value.
	tests+=('0:0.000000000')
	tests+=('0.1:0.100000000')
	tests+=('0.1s:0.100000000')
	tests+=('7.5:7.500000000')
	tests+=('7.5s:7.500000000')
	tests+=('3m:180.000000000')
	tests+=('3h:10800.000000000')
	tests+=('3d:259200.000000000')
	tests+=('0.01:0.010000000')
	tests+=('0.057:0.057000000')

	# Strictly, these values are a lie as the command will sleep
	# "forever" (aka this value) repeatedly.
	tests+=('inf:18446744073709551615.999999999')
	tests+=('infinity:18446744073709551615.999999999')

	for t in "${tests[@]}"
	do
		local value
		local expected

		value=$(echo "$t"|cut -d: -f1)
		expected=$(echo "$t"|cut -d: -f2)

		test_cmd_unquoted_args "$cmd" '-n' "$value"

		[ "$status" -eq 0 ]
		[ -z "${lines[-1]}" ] && unset 'lines[-1]'
		[ "${#lines[@]}" -eq 1 ]
		grep -q "^${expected}$" <<< "${lines[0]}"
	done
}
