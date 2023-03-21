#!/usr/bin/env bats
#---------------------------------------------------------------------
# vim:set noexpandtab:
#---------------------------------------------------------------------
# Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
#
# SPDX-License-Identifier: Apache-2.0
#---------------------------------------------------------------------

load 'test-common.bats'

@test "seq no args" {
	test_cmd 'seq'

	[ "$status" -eq 1 ]
	[ ${#lines[@]} = 0 ]
	[ ${#stderr_lines[@]} = 1 ]

	grep -q "ERROR: bad value" <<< "${stderr_lines[0]}"
}

@test "seq LAST (no output)" {
	local -a args

	# If LAST <= 0, there should be no output.
	args+=('0')
	args+=('+0')
	args+=('-0')
	args+=('-1')
	args+=('-999')
	args+=('-1024')

	local arg

	for arg in "${args[@]}"
	do
		test_cmd 'seq' "$arg"
		[ "$status" -eq 0 ]
		[ "${#lines[@]}" -eq 0 ]
	done
}

@test "seq LAST (invalid)" {
	local -a args

	# Invalid values
	args+=('')
	args+=('foo')
	args+=('foo bar')
	args+=('1234a')
	args+=('999hello12')

	local arg

	for arg in "${args[@]}"
	do
		test_cmd 'seq' "$arg"
		[ "$status" -eq 1 ]
		grep -q "ERROR: bad value" <<< "${stderr_lines[0]}"
	done
}

@test "seq LAST" {
	local -a args

	# Valid values
	args+=('0')
	args+=('+0')
	args+=('1')

	test_cmd 'seq' 0
	[ "$status" -eq 0 ]
	[ "${#lines[@]}" = 0 ]

	test_cmd 'seq' 1
	[ "$status" -eq 0 ]
	[ "${#lines[@]}" = 2 ]
	[ "${lines[0]}" = '1' ]
	[ "${lines[1]}" = '' ]

	local num
	num='7'

	test_cmd 'seq' "$num"
	[ "$status" -eq 0 ]

	[ -z "${lines[-1]}" ] && unset 'lines[-1]'

	[ "${#lines[@]}" = "$num" ]

	local i
	for value in $(seq "$num")
	do
		local i
		i=$(( value - 1 ))

		[ "${lines[$i]}" = "$value" ]
	done
}

@test "seq FIRST LAST (no output)" {
	local -a tests

 	# If FIRST < LAST, there should be no output
	tests+=('1:0')
	tests+=('1:-9')
	tests+=('0:-1')
	tests+=('0:-99')
	tests+=('7:3')
	tests+=('100:3')
	tests+=('100:0')

	local t

	for t in "${tests[@]}"
	do
		local first=$(echo "$t"|cut -d: -f1)
		local last=$(echo "$t"|cut -d: -f2)

		test_cmd_unquoted_args 'seq' "$first" "$last"
		[ "$status" -eq 0 ]
		[ "${#lines[@]}" -eq 0 ]
	done
}

@test "seq FIRST LAST" {
	local cmd='seq'

	local first
	local last

	local long_max='2147483647'

	first="$((long_max - 1))"
	last="$long_max"

	log "first: '$first', last: '$last'"

	local cmd_path

	for cmd_path in \
		"${CMD_DIR}/${cmd}" \
		"${CMD_DIR}/${ABOX}"
	do
		if grep -q "${ABOX}$" <<< "$cmd_path"
		then
			run "$cmd_path" "$cmd" "$first" "$last"
		else
			run "$cmd_path" "$first" "$last"
		fi

		[ "$status" -eq 0 ]
		[ ${#lines[@]} = 2 ]
		[ "${lines[0]}" = "$first" ]
		[ "${lines[1]}" = "$last" ]
	done
}

@test "seq FIRST INCREMENT LAST" {
	local cmd='seq'

	local -a tests

	# Colon-separated fields:
	#
	# Field:
	#
	# 1: first
	# 2: step/increment
	# 3: last
	# 4: number of lines of output expected
	# 5: comma-separated list of output lines (optional)
	tests+=('1:1:1:1:1')
	tests+=('1:1:2:2:1,2')
	tests+=('1:1:3:3:1,2,3')
	tests+=('1:-1:0:2:1,0')
	tests+=('1:-1:-1:3:1,0,-1')
	tests+=('1:3:22:8:1,4,7,10,13,16,19,22')
	tests+=('1:-3:22:0')
	tests+=('7:-3:1:3:7,4,1')
	tests+=('3:-2:-3:4:3,1,-1,-3')

	local t

	for t in "${tests[@]}"
	do
		local first
		local step
		local last
		local count

		first=$(echo "$t"|cut -d: -f1)
		step=$(echo "$t"|cut -d: -f2)
		last=$(echo "$t"|cut -d: -f3)
		count=$(echo "$t"|cut -d: -f4)

		local cmd_path

		for cmd_path in \
			"${CMD_DIR}/${cmd}" \
			"${CMD_DIR}/${ABOX}"
		do
			if grep -q "${ABOX}$" <<< "$cmd_path"
			then
				run "$cmd_path" "$cmd" "$first" "$step" "$last"
			else
				run "$cmd_path" "$first" "$step" "$last"
			fi

			[ "$status" -eq 0 ]
			[ "${#lines[@]}" -eq "$count" ]

			[ "$count" -eq 0 ] && continue || true

			local -a output=()
			output=( $(echo "$t"|cut -d: -f5|tr ',' ' ') )

			local i

			for i in $(seq 0 $((count - 1 )))
			do
				[ "${lines[$i]}" = "${output[$i]}" ]
			done
		done
	done
}
