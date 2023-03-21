#!/usr/bin/env bats
#---------------------------------------------------------------------
# vim:set noexpandtab:
#---------------------------------------------------------------------
# Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
#
# SPDX-License-Identifier: Apache-2.0
#---------------------------------------------------------------------

load 'test-common.bats'

@test "false" {
	test_cmd 'false'
	[ "$status" -eq 1 ]
	[ ${#lines[@]} = 0 ]

	# Ensure args are ignored
	test_cmd 'false' foo bar baz
	[ "$status" -eq 1 ]
	[ ${#lines[@]} = 0 ]
}
