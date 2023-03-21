#!/usr/bin/env bats
#---------------------------------------------------------------------
# vim:set noexpandtab:
#---------------------------------------------------------------------
# Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
#
# SPDX-License-Identifier: Apache-2.0
#---------------------------------------------------------------------

load 'test-common.bats'

@test "pwd" {
	local expected
	expected=$(pwd)

	test_cmd 'pwd'
	[ "$status" -eq 0 ]
	[ -z "${lines[-1]}" ] && unset 'lines[-1]'
	[ ${#lines[@]} = 1 ]
	[ "${lines[0]}" = "$expected" ]
}

