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

test_help_result() {
	[ "$status" -eq 0 ]
	[ ${#lines[@]} -ge 1 ]
	[[ ${lines[0]} =~ ^Usage:+ ]]
}

test_help() {
	local cmd="${1:-}"
	[ -n "$cmd" ]

	local arg="${2:-}"

	local cmd_path=$(clean_path "${CMD_DIR}/${cmd}")
	[ -x "$cmd_path" ] || die "invalid path: '$cmd_path'"

	log ":test_help: cmd: '$cmd', cmd_path: '$cmd_path', arg: '$arg'"

	run "${cmd_path}" ${arg}

	log ""

	test_help_result
}

test_help_args() {
	local cmd="${1:-}"
	[ -n "$cmd" ] || die "need command"

	local arg

	for arg in '-h' '--help'
	do
		test_help "$cmd" "$arg"
	done
}

# Check the result of a version command
test_version_result() {
	[ "$status" -eq 0 ]
	[ ${#lines[@]} = 1 ]
	[[ ${lines[0]} =~ ^abox[[:space:]]version[[:space:]][0-9a-f][0-9a-f]+(-dirty)*$ ]]
}

test_version() {
	local cmd="${1:-}"
	[ -n "$cmd" ]

	local arg="${2:-}"

	local cmd_path=$(clean_path "${CMD_DIR}/${cmd}")

	log "test_version: cmd: '$cmd', cmd_path: '$cmd_path', arg: '$arg'"

	run "${cmd_path}" ${arg}

	test_version_result
}

test_version_args() {
	local cmd="${1:-}"
	[ -n "$cmd" ]

	local arg

	for arg in '-v' '--version'
	do
		test_version "$cmd" "$arg"
	done
}

test_list() {
	local cmd="${1:-}"
	[ -n "$cmd" ]

	local arg="${2:-}"

	local cmd_path=$(clean_path "${CMD_DIR}/${cmd}")

	log ":test_list: cmd: '$cmd'"

	run "${cmd_path}" ${arg}

	log ""

	[ "$status" -eq 0 ]
	[ ${#lines[@]} = "${COMMANDS_COUNT}" ]

	local i=0
	local cmd

	for cmd in "${COMMANDS[@]}"
	do
		[ "${lines[$i]}" = "${COMMANDS[$i]}" ]
		i=$((i+1))
	done
}

test_list_args() {
	local cmd="${1:-}"
	[ -n "$cmd" ]

	local arg

	for arg in '-l' '--list'
	do
		test_list "$cmd" "$arg"
	done
}

#---------------------------------------------------------------------

@test "$ABOX no args shows help" {
	run "${ABOX_PATH}"
	test_help_result
}

@test "$ABOX list" {
	test_list_args "$ABOX"
}

@test "$ABOX version" {
	test_version_args "$ABOX" "$arg"
}

@test "$ABOX help" {
	local cmd_path=$(clean_path "${ABOX_PATH}")
	local arg

	for arg in '-h' '--help'
	do
		run "$cmd_path" "$arg"
		test_help_result
	done
}

# Ensure the multi-call binary intercepts the version
# request on behalf of the command.
@test "'$ABOX command' version" {
	local cmd_path=$(clean_path "${ABOX_PATH}")
	local cmd

	for cmd in ${COMMANDS[@]}
	do
		local arg

		for arg in '-v' '--version'
		do
			run "$cmd_path" "$cmd" "$arg"
			test_version_result
		done
	done
}

@test "'$ABOX command' help" {
	local cmd_path=$(clean_path "${ABOX_PATH}")
	local cmd

	for cmd in ${COMMANDS[@]}
	do
		local arg

		for arg in '-h' '--help'
		do
			run "$cmd_path" "$cmd" "$arg"
			test_help_result
		done
	done
}

@test "command help" {
	local cmd

	for cmd in ${COMMANDS[@]}
	do
		test_help_args "$cmd"
	done
}

@test "command version" {
	local cmd

	for cmd in ${COMMANDS[@]}
	do
		test_version_args "$cmd"
	done
}

@test "$ABOX invalid command" {
	run "$ABOX_PATH" invalid

	[ "$status" -eq 1 ]
	[ ${#lines[@]} = 1 ]
	[ "${lines[0]}" = "ERROR: invalid command" ]
}

@test "$ABOX invalid option" {
	run "$ABOX_PATH" --invalid

	[ "$status" -eq 1 ]
	[ ${#lines[@]} = 1 ]
	[ "${lines[0]}" = "ERROR: invalid option" ]
}

