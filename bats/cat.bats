#!/usr/bin/env bats
#---------------------------------------------------------------------
# vim:set noexpandtab:
#---------------------------------------------------------------------
# Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
#
# SPDX-License-Identifier: Apache-2.0
#---------------------------------------------------------------------

load 'test-common.bats'

@test "cat" {
	local cmd='cat'

	local cmd_path=$(clean_path "${CMD_DIR}/${cmd}")

	[ -x "$cmd_path" ]

	log "cat: cmd_path: '$cmd_path'"

	#--------------------
	# zero byte output

	run "$cmd_path" < /dev/null
	[ "$status" -eq 0 ]
	[ ${#lines[@]} -eq 0 ]

	run "$cmd_path" - < /dev/null
	[ "$status" -eq 0 ]
	[ ${#lines[@]} -eq 0 ]

	#--------------------
	# 1 byte output

	local msg='x'

	run "$cmd_path" <<< "$msg"
	[ "$status" -eq 0 ]
	[ ${#lines[@]} -eq 1 ]
	grep -q "$msg" <<< "${lines[0]}"

	run "$cmd_path" - <<< "$msg"
	[ "$status" -eq 0 ]
	[ ${#lines[@]} -eq 1 ]
	grep -q "$msg" <<< "${lines[0]}"

	#--------------------
	# multi-byte output

	local msg='hello, world'

	run "$cmd_path" <<< "$msg"
	[ "$status" -eq 0 ]
	[ ${#lines[@]} -eq 1 ]
	grep -q "$msg" <<< "${lines[0]}"

	run "$cmd_path" - <<< "$msg"
	[ "$status" -eq 0 ]
	[ ${#lines[@]} -eq 1 ]
	grep -q "$msg" <<< "${lines[0]}"

	#--------------------
	# multi-line output

	local line_1='hello world'
	local line_2='foo bar'
	local msg=$(echo -e "${line_1}\n${line_2}")

	run "$cmd_path" <<< "$msg"
	[ "$status" -eq 0 ]
	[ ${#lines[@]} -eq 2 ]
	grep -q "$line_1" <<< "${lines[0]}"
	grep -q "$line_2" <<< "${lines[1]}"
}
