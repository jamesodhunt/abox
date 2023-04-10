#!/usr/bin/env bats
#---------------------------------------------------------------------
# vim:set noexpandtab:
#---------------------------------------------------------------------
# Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
#
# SPDX-License-Identifier: Apache-2.0
#---------------------------------------------------------------------

load 'test-common.bats'

get_inode()
{
	local file="${1:-}"
	[ -z "$file" ] && die "need file"

	stat -c '%i' "$file"
}

@test "ln with missing source file" {
	local tmpdir=$(mktemp -d)

	local file_name='file'
	local link_name='link'

	local file_path="$tmpdir/$file_name"
	local link_path="$tmpdir/$link_name"

	local func
	for func in \
		test_cmd_via_sym_link_unquoted_args \
		test_cmd_via_multi_call_binary_unquoted_args
	do
		[ ! -e "$file_path" ]

		# You can't create a hard link to a non-existant file!
		$func 'ln' "$file_path" "$link_path"
		[ "$status" -eq 1 ]
		[ ! -e "$link_path" ]

		# But you can create a symlink to a non-existant file.
		$func 'ln' -s "$file_path" "$link_path"
		[ "$status" -eq 0 ]
		[ ${#lines[@]} = 0 ]

		# Link path should exist even though the file doesn't.
		[ -L "$link_path" ]
		[ ! -e "$file_path" ]

		# Clean up
		rm -f "$link_path"
	done

	rm -rf "$tmpdir"
}

@test "ln with existing regular source file" {
	local tmpdir=$(mktemp -d)

	local file_name='file'
	local link_name='link'

	local file_path="$tmpdir/$file_name"
	local link_path="$tmpdir/$link_name"

	local func
	for func in \
		test_cmd_via_sym_link_unquoted_args \
		test_cmd_via_multi_call_binary_unquoted_args
	do
		touch "$file_path"
		[ -e "$file_path" ]

		$func 'ln' "$file_path" "$link_path"
		[ "$status" -eq 0 ]
		[ -e "$link_path" ]

		local file_path_inode
		local link_path_inode

		file_path_inode=$(get_inode "$file_path")
		link_path_inode=$(get_inode "$link_path")

		# Hard linked files share the same inode
		[ "$file_path_inode" = "$link_path_inode" ]

		rm -f "$file_path" "$link_path"

		# Setup for next test

		touch "$file_path"
		[ -e "$file_path" ]

		$func 'ln' -s "$file_path" "$link_path"
		[ "$status" -eq 0 ]
		[ ${#lines[@]} = 0 ]

		# Link path should exist even though the file doesn't.
		[ -L "$link_path" ]
		[ -e "$file_path" ]

		# Clean up
		rm -f "$file_path" "$link_path"
	done

	rm -rf "$tmpdir"
}

@test "ln with force" {
	local tmpdir=$(mktemp -d)

	local file_name='file'
	local link_name='link'

	local file_path="$tmpdir/$file_name"
	local link_path="$tmpdir/$link_name"

	local func
	for func in \
		test_cmd_via_sym_link_unquoted_args \
		test_cmd_via_multi_call_binary_unquoted_args
	do
		local file_path_inode
		local link_path_inode

		touch "$file_path"
		[ -e "$file_path" ]

		# Create link as a regular file for the test
		touch "$link_path"
		[ -e "$link_path" ]

		file_path_inode=$(get_inode "$file_path")
		link_path_inode=$(get_inode "$link_path")

		$func 'ln' -f "$file_path" "$link_path"
		[ "$status" -eq 0 ]
		[ -e "$file_path" ]
		[ -e "$link_path" ]
		[ -L "$link_path" ]

		local new_link_path_inode
		new_link_path_inode=$(get_inode "$link_path")

		[ "$new_link_path_inode" != "$link_path_inode" ]
		[ "$new_link_path_inode" = "$file_path_inode" ]

		rm -f "$file_path" "$link_path"

		#--------------------
		# Setup for next test

		touch "$file_path"
		[ -e "$file_path" ]

		# Create link as a regular file for the test
		touch "$link_path"
		[ -e "$link_path" ]

		#$func 'ln' -s -f "$file_path" "$link_path"
		#[ "$status" -eq 0 ]
		#[ ${#lines[@]} = 0 ]

		# Link path should exist even though the file doesn't.
		#[ -L "$link_path" ]
		#[ -e "$file_path" ]

		# Clean up
		rm -f "$file_path" "$link_path"
	done

	rm -rf "$tmpdir"
}

@test "ln to existing linked file" {
	# TODO:
}

@test "ln to existing linked directory" {
	# TODO:
}

@test "hard link to existing hard link" {
	# TODO:
}

@test "hard link to existing soft link" {
	# TODO:
}

@test "soft link to existing soft link" {
	# TODO:
}

@test "soft link to existing hard link" {
	# TODO:
}
