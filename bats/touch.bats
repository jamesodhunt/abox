#!/usr/bin/env bats
#---------------------------------------------------------------------
# vim:set noexpandtab:
#---------------------------------------------------------------------
# Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
#
# SPDX-License-Identifier: Apache-2.0
#---------------------------------------------------------------------

load 'test-common.bats'

@test "touch -c file" {
	local tmpdir=$(mktemp -d)

	local name='foo'

	local file="$tmpdir/$name"

	test_cmd 'touch' -c "$file"
	[ "$status" -eq 0 ]
	[ ${#lines[@]} = 0 ]

	# File should not exist
	[ ! -e "$file" ]

	rm -rf "$tmpdir"
}

@test "touch file" {
	local tmpdir=$(mktemp -d)

	local name='foo'

	local file="$tmpdir/$name"

	test_cmd 'touch' "$file"
	[ "$status" -eq 0 ]
	[ ${#lines[@]} = 0 ]

	[ -e "$file" ]
	[ ! -s "$file" ]

	local fields
	fields=$(stat -c '%0.9X %0.9Y' "$file")

	local orig_atime
	local orig_mtime

	orig_atime=$(echo "$fields"|awk '{print $1}')
	orig_mtime=$(echo "$fields"|awk '{print $2}')

	# File was created so this must be true
	[ "$orig_atime" = "$orig_mtime" ]

	# Any sleep will be sufficient to change the values when we
	# re-touch the file as we're using nanosecond timestamps.
	sleep 0.01

	test_cmd 'touch' "$file"
	[ "$status" -eq 0 ]
	[ ${#lines[@]} = 0 ]

	# File must exist
	[ -e "$file" ]

	# And, considering both these tests, should have a size of zero.
	[ ! -s "$file" ]

	fields=$(stat -c '%0.9X %0.9Y' "$file")

	local new_atime
	local new_mtime

	new_atime=$(echo "$fields"|awk '{print $1}')
	new_mtime=$(echo "$fields"|awk '{print $2}')

	[ "$new_atime" != "$orig_atime" ] \
		|| die "identical atime: $new_atime"
	[ "$new_mtime" != "$orig_mtime" ] \
		|| die "identical mtime: $new_mtime"

	rm -rf "$tmpdir"
}

@test "touch dir" {
	local tmpdir=$(mktemp -d)

	local dirname='dir'

	local dir="$tmpdir/$dirname"

	mkdir "$dir"

	test_cmd 'touch' "$dir"
	[ "$status" -eq 0 ]
	[ ${#lines[@]} = 0 ]

	rm -rf "$tmpdir"
}
