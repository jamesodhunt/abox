#!/usr/bin/env bats
#---------------------------------------------------------------------
# vim:set noexpandtab:
#---------------------------------------------------------------------
# Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
#
# SPDX-License-Identifier: Apache-2.0
#---------------------------------------------------------------------

load 'test-common.bats'

@test "env" {
	local cmd='env'
	local cmd_path=$(clean_path "${CMD_DIR}/${cmd}")

	[ -x "$cmd_path" ]

	local control_file=$(mktemp)
	local out_file=$(mktemp)

	log "end: control_file: '$control_file'"
	log "env: out_file: '$out_file'"

	env > "$control_file"
	[ -s "$control_file" ]

	local expected_count
	expected_count=$(wc -l "$control_file" |awk '{print $1}')

	# We have to run this manually as BATS plays with fds.
	"$cmd_path" > "$out_file"
	[ "$?" -eq 0 ]

	local actual_count
	actual_count=$(wc -l "$out_file" |awk '{print $1}')

	log "actual_count: '$actual_count'"
	log "expected_count: '$expected_count'"

	[ "${actual_count}" -eq "${expected_count}" ]

	# Output should match that of env(3).
	diff \
		<(grep -v '^_=' "$control_file") \
		<(grep -v '^_=' "$out_file")

	[ "${BATS_ERROR_STATUS:-}" -eq 0 ] && \
		rm -f \
			"$control_file" \
			"$out_file" \
	|| true
}
