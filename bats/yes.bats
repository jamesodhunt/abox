#!/usr/bin/env bats
#---------------------------------------------------------------------
# vim:set noexpandtab:
#---------------------------------------------------------------------
# Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
#
# SPDX-License-Identifier: Apache-2.0
#---------------------------------------------------------------------

load 'test-common.bats'

#---------------------------------------------------------------------

# Check the result of a help command
test_yes()
{
	# Not validated as might be blank
	local input="${1:-}"
	local expected_output="${2:-}"

	local cmd='yes'
	local cmd_path=$(clean_path "${CMD_DIR}/${cmd}")

	local out_file=$(mktemp)

	# XXX: Fragile code - seems to be just enough time to generate
	# XXX: a few lines of output, but not too much! ;)
	local timeout_secs='0.3s'

	# Arbitrary but we want to ensure it produces multiple lines of
	# output.
	local minimum_output_lines=3

	log ":test_yes: out_file: '$out_file', input: '$input', expected_output: '$expected_output'"

	{ timeout \
		"$timeout_secs" \
		"$cmd_path" \
		$input \
		> "$out_file";
	} || true

	log "done"

	local lines
	lines=$(wc -l "$out_file" | awk '{print $1}')

	[ "$lines" -gt "$minimum_output_lines" ]

	local output
	output=$(cat "$out_file" | sort -u)

	log "output: '$output'"

	[ "$output" = "$expected_output" ]

	rm -f "$out_file"
}

#---------------------------------------------------------------------

@test "yes with default output" {
	test_yes '' 'y'
}

@test "yes with custom output" {
	local -A tests=(
		['foo bar']='foo bar'
		['foo       bar']='foo bar'
	)

	local t
	local -i i=0

	for t in "${!tests[@]}"
	do
		local value="${tests[$t]}"

		log "test[$i]: '$t', expected value: '$value'"

		test_yes "$t" "$value"
	done
}
