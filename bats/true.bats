#!/usr/bin/env bats
#---------------------------------------------------------------------
# vim:set noexpandtab:
#---------------------------------------------------------------------
# Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
#
# SPDX-License-Identifier: Apache-2.0
#---------------------------------------------------------------------

load 'test-common.bats'

@test "true" {
	test_cmd 'true'
	[ "$status" -eq 0 ]
	[ ${#lines[@]} = 0 ]

	# Ensure args are ignored
	test_cmd 'true' foo bar baz
	[ "$status" -eq 0 ]
	[ ${#lines[@]} = 0 ]
}
