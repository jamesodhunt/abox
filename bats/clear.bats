#!/usr/bin/env bats
#---------------------------------------------------------------------
# vim:set noexpandtab:
#---------------------------------------------------------------------
# Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
#
# SPDX-License-Identifier: Apache-2.0
#---------------------------------------------------------------------

load 'test-common.bats'

@test "clear" {
	local cmd='clear'

	local cmd_path=$(clean_path "${CMD_DIR}/${cmd}")

	[ -x "$cmd_path" ]

	log "clear: cmd_path: '$cmd_path'"

	$cmd_path |\
		od -c |\
		grep -E '033 *\[ *\<H\> *033 *\[ *\<J\>' \
		|| die "invalid clear escape sequences"
}

