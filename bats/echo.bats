#!/usr/bin/env bats
#---------------------------------------------------------------------
# vim:set noexpandtab:
#---------------------------------------------------------------------
# Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
#
# SPDX-License-Identifier: Apache-2.0
#---------------------------------------------------------------------

load 'test-common.bats'

@test "echo" {
	test_cmd 'echo'
	[ "$status" -eq 0 ]

	[ -z "${lines[-1]}" ] && unset 'lines[-1]'
	[ ${#lines[@]} -eq 1 ]

	local -A tests=(
		['foo']='foo'
		['foo bar']='foo bar'
		['foo         bar']='foo         bar'
	)

	local t
	local -i i=0

	for t in "${!tests[@]}"
	do
		local value="${tests[$t]}"

		log "test[$i]: '$t', expected value: '$value'"

		test_cmd 'echo' "$t"
		[ "$status" -eq 0 ]

		[ -z "${lines[-1]}" ] && unset 'lines[-1]'
		[ ${#lines[@]} -eq 1 ]

		[ "${lines[0]}" = "$value" ]
	done
}
