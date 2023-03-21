#!/usr/bin/env bats
#---------------------------------------------------------------------
# vim:set noexpandtab:
#---------------------------------------------------------------------
# Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
#
# SPDX-License-Identifier: Apache-2.0
#---------------------------------------------------------------------

load 'test-common.bats'

@test "head (missing file)" {
	local tmpdir=$(mktemp -d)

	local file="$tmpdir/ENOENT"

	test_cmd 'head' $file
	[ "$status" -eq 1 ]
	[ ${#lines[@]} = 0 ]

	test_cmd 'head' -c 3 $file
	[ "$status" -eq 1 ]
	[ ${#lines[@]} = 0 ]

	test_cmd 'head' -n 3 $file
	[ "$status" -eq 1 ]
	[ ${#lines[@]} = 0 ]

	# FIXME: check error value
	#[ ${#lines[@]} = 1 ]
}

@test "head by default number of lines" {
	local file=$(mktemp)

	local cmd='head'

	# A value greater than the default of 10.
	seq 13 > "$file"

	test_cmd "$cmd" "$file"
	[ "$status" -eq 0 ]

	[ -z "${lines[-1]}" ] && unset 'lines[-1]'

	[ "${lines[0]}" = 1 ]
	[ "${lines[1]}" = 2 ]
	[ "${lines[2]}" = 3 ]
	[ "${lines[3]}" = 4 ]
	[ "${lines[4]}" = 5 ]
	[ "${lines[5]}" = 6 ]
	[ "${lines[6]}" = 7 ]
	[ "${lines[7]}" = 8 ]
	[ "${lines[8]}" = 9 ]
	[ "${lines[9]}" = 10 ]

	[ "${#lines[@]}" -eq 10 ]

	rm -f "$file"
}

@test "head by default number of lines with gaps" {
	local file=$(mktemp)

	local cmd='head'

	(echo;echo;seq 4;echo;seq 2;echo) > "$file"

	test_cmd "$cmd" "$file"

	[ "$status" -eq 0 ]

	[ "${lines[0]}" = '' ]
	[ "${lines[1]}" = '' ]
	[ "${lines[2]}" = 1 ]
	[ "${lines[3]}" = 2 ]
	[ "${lines[4]}" = 3 ]
	[ "${lines[5]}" = 4 ]
	[ "${lines[6]}" = '' ]
	[ "${lines[7]}" = 1 ]
	[ "${lines[8]}" = 2 ]
	[ "${lines[9]}" = '' ]
	[ "${lines[10]}" = '' ]

	[ "${#lines[@]}" = 11 ]

	rm -f "$file"
}

@test "head by bytes" {
	local tmpdir=$(mktemp -d)
	local cmd='head'

	local small_file=$(printf "%s/%s" "$tmpdir" "${cmd}.txt")

	local max='17'
	local big_max='1027'

	local expected_result

	local big_file=$(printf "%s/%s" "$tmpdir" "${cmd}-big.txt")

	# Note: no newline!
	seq 1 1 "$big_max" | tr -d '\n' > "$big_file"

	[ "$big_max" -gt "$max" ]

	local bytes

	for bytes in $(seq "$max")
	do
		# Note: no newline!
		seq 1 1 "$bytes" |tr -d '\n' > "$small_file"

		local file

		for file in "$small_file" "$big_file"
		do
			# Compare the output with that from the read head(1).
			test_cmd_unquoted_args "$cmd" -c "$bytes" "$file"
			[ "$status" -eq 0 ]

			[ -z "${lines[-1]}" ] && unset 'lines[-1]'
			[ ${#lines[@]} = 1 ]

			expected_result=$("$cmd" -c "$bytes" "$file")

			[ "${lines[*]}" = "$expected_result" ]
		done
	done

	rm -rf "$tmpdir"
}

@test "head by lines" {
	local file=$(mktemp)

	local cmd='head'

	# A value greater than the default of 10.
	seq 13 > "$file"

	test_cmd_unquoted_args "$cmd" -n 11 "$file"
	[ "$status" -eq 0 ]

	[ -z "${lines[-1]}" ] && unset 'lines[-1]'

	[ "${lines[0]}" = 1 ]
	[ "${lines[1]}" = 2 ]
	[ "${lines[2]}" = 3 ]
	[ "${lines[3]}" = 4 ]
	[ "${lines[4]}" = 5 ]
	[ "${lines[5]}" = 6 ]
	[ "${lines[6]}" = 7 ]
	[ "${lines[7]}" = 8 ]
	[ "${lines[8]}" = 9 ]
	[ "${lines[9]}" = 10 ]

	[ "${#lines[@]}" -eq 11 ]

	rm -f "$file"
}
