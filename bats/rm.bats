#!/usr/bin/env bats
#---------------------------------------------------------------------
# vim:set noexpandtab:
#---------------------------------------------------------------------
# Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
#
# SPDX-License-Identifier: Apache-2.0
#---------------------------------------------------------------------

load 'test-common.bats'

@test "rm file" {
	local tmpdir=$(mktemp -d)

	local name='foo'

	local file="$tmpdir/$name"

	# Ensure ENOENT handling is correct
	test_cmd_via_sym_link 'rm' "$file"
	[ "$status" -ne 0 ]

	test_cmd_via_multi_call_binary 'rm' "$file"
	[ "$status" -ne 0 ]

	# Create the file
	touch "$file"
	[ -e "$file" ]

    test_cmd_via_sym_link 'rm' "$file"
	[ "$status" -eq 0 ]

	# File should not exist
	[ ! -e "$file" ]

	# Recreate the file
	touch "$file"
	[ -e "$file" ]

	test_cmd_via_multi_call_binary 'rm' "$file"
	[ "$status" -eq 0 ]

	# File should not exist
	[ ! -e "$file" ]

	rm -rf "$tmpdir"
}

@test "rm multiple file" {
	local cmd='rm'

	local tmpdir=$(mktemp -d)

	local -a names=(foo bar baz)

	local -a files

	local cmd_path
	cmd_path=$(clean_path "${CMD_DIR}/${cmd}")

	local name

	for name in "${names[@]}"
	do
		local file="$tmpdir/$name"

		files+=("$file")

		[ ! -e "$file" ]
		touch "$file"
		[ -e "$file" ]
	done

	run "$cmd_path" "${files[@]}"
	[ "$status" -eq 0 ]

	# Recreate files
	for name in "${names[@]}"
	do
		local file="$tmpdir/$name"

		[ ! -e "$file" ]
		touch "$file"
		[ -e "$file" ]
	done

	run "$ABOX_BINARY" "$cmd" "${files[@]}"
	[ "$status" -eq 0 ]

	rm -rf "$tmpdir"
}

@test "rm dir" {
	local tmpdir=$(mktemp -d)

	local dirname='dir'

	local dir="$tmpdir/$dirname"

	mkdir "$dir"

	test_cmd 'rm' "$dir"
	[ "$status" -ne 0 ]
	[ ${#lines[@]} = 0 ]

	rm -rf "$tmpdir"
}

@test "rm multiple files and directories" {
	local cmd='rm'

	local cmd_path
	cmd_path=$(clean_path "${CMD_DIR}/${cmd}")

	local tmpdir=$(mktemp -d)

	local -a names=(foo bar baz)

	local -a files

	local dirname='dir'

	local dir="$tmpdir/$dirname"

	mkdir "$dir"

	local name

	for name in "${names[@]}"
	do
		local file="$tmpdir/$name"

		files+=("$file")

		[ ! -e "$file" ]
		touch "$file"
		[ -e "$file" ]
	done

	run "$cmd_path" "${files[@]}" "$dir"
	[ "$status" -ne 0 ]

	local file

	for file in "${files[@]}"
	do
		# Ensure files deleted
		[ ! -e "$file" ]
	done

	# Ensure directory not deleted
	[ -e "$dir" ]

	for file in "${files[@]}"
	do
		touch "$file"

		[ -e "$file" ]
	done

	run "$ABOX_BINARY" "$cmd" "${files[@]}" "$dir"
	[ "$status" -ne 0 ]

	for file in "${files[@]}"
	do
		# Ensure files deleted
		[ ! -e "$file" ]
	done

	# Ensure directory not deleted
	[ -e "$dir" ]

	rm -rf "$tmpdir"
}
