#---------------------------------------------------------------------
# vim:set noexpandtab:
#---------------------------------------------------------------------
# Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
#
# SPDX-License-Identifier: Apache-2.0
#---------------------------------------------------------------------

# Set in setup()
export ABOX='abox'
typeset ABOX_PATH
typeset CMD_DIR
typeset BUILD_DIR
typeset -a COMMANDS
typeset -i COMMANDS_COUNT

#---------------------------------------------------------------------
# Required for the '--keep-empty-lines' option for the bats 'run'
# command.

bats_require_minimum_version 1.5.0

#---------------------------------------------------------------------

setup() {
	local CWD

	CWD="$(cd "$(dirname "$BATS_TEST_FILENAME")" &>/dev/null && pwd)"

	source "${CWD}/test-common.sh"

	local arch
	arch=$(uname -m)

	local generated_test_settings_file
	generated_test_settings_file='generated-test-settings.sh'

	local generated_test_settings

	[ -n "$BUILD_DIR" ] ||\
		die "BUILD_DIR variable not set - run 'meson test -C \$build_dir'"

	[ -d "$BUILD_DIR" ] ||\
		die "Invalid BUILD_DIR: '${BUILD_DIR}'"

	#------------------------------

	generated_test_settings="${BUILD_DIR}/${generated_test_settings_file}"

	[ -e "${generated_test_settings}" ] || die "Invalid '$generated_test_settings' file - run 'make'"

	source "${generated_test_settings}"

	# Check values from the generated test settings
	[ -n "${ABOX_BINARY:-}" ] || die "ABOX_BINARY not set"
	[ -n "${ABOX_NAME:-}" ] || die "ABOX_NAME not set"
	[ -n "${CMDS_DIR:-}" ] || die "CMDS_DIR not set"
	[ -n "${TEST_DIR:-}" ] || die "TEST_DIR not set"

	CMD_DIR="${BUILD_DIR}/test/bin"

	ABOX_PATH="${CMD_DIR}/${ABOX_NAME}"

	setup_test_env \
		"${ABOX_BINARY:-}" \
		"${CMDS_DIR:-}" \
		"${TEST_DIR:-}"

	pushd "$CMDS_DIR" &>/dev/null
	COMMANDS=($(ls *"${asm_ext}" |\
		sort -u |\
		sed "s/${asm_ext}//g"))
	popd &>/dev/null

	COMMANDS_COUNT=${#COMMANDS[@]}

	[ $COMMANDS_COUNT -gt 0 ]
}

teardown() {
	# Success, so nothing to display
	[ "${BATS_ERROR_STATUS:-}" -eq 0 ] && return 0

	local ruler
	ruler=$(printf "%*s\n" $((COLUMNS-10)) ''|sed 's/ /_/g')

	log "$ruler"
	log "BATS ERROR detected:"

	# Hack: print a char, then delete it to force BATS to display the
	# output in the format we want.
	log " \b"

	log "BATS_TEST_NAME: '${BATS_TEST_NAME}'"
	log "BATS_TEST_FILENAME: '${BATS_TEST_FILENAME}'"
	log "BATS_ERROR_STATUS: '${BATS_ERROR_STATUS}'"
	log "BATS status: $status"
	log "BATS_RUN_COMMAND: '${BATS_RUN_COMMAND}'"
	log "BATS_TEST_NUMBER: '${BATS_TEST_NUMBER}'"
	log "BATS_SUITE_TEST_NUMBER: '${BATS_SUITE_TEST_NUMBER}'"
	log "BATS_VERSION: '${BATS_VERSION}'"

	log "$ruler"

	log "USER: '$USER'"
	log "PWD: '$PWD'"

	log "$ruler"

	local msg
	msg='lines'
	[ "${#lines[@]}" -eq 1 ] && msg='line'

	log "BATS stdout output ('lines' array contains ${#lines[@]} $msg):"
	[ "${#lines[@]}" -gt 0 ] && log " \b"

	local i=0
	local line

	for line in "${lines[@]}"
	do
		log "lines[$i]: '$line'"
		i=$((i+1))
	done

	log "$ruler"

	msg='lines'
	[ "${#stderr_lines[@]}" -eq 1 ] && msg='line'

	log "BATS stderr output ('stderr_lines' array contains ${#stderr_lines[@]} $msg):"
	[ "${#stderr_lines[@]}" -gt 0 ] && log " \b"

	local i=0
	local line

	for line in "${stderr_lines[@]}"
	do
		log "stderr_lines[$i]: '$line'"
		i=$((i+1))
	done

	log "$ruler"
}

#---------------------------------------------------------------------

cmd_valid() {
	local cmd="${1:-}"
	[ -z "$cmd" ] && die "need command name"

	local abox_cmd_path
	abox_cmd_path=$(clean_path "${CMD_DIR}/${ABOX}")

	local opt
	for opt in '-l' '--list'
	do
		"$abox_cmd_path" "$opt"|grep -q "^${cmd}$" && return 0
	done

	# Command was not listed, so must be invalid.
	return 1
}

_test_cmd_via_sym_link() {
	local quote="${1:-}"
	[ -n "$quote" ] || die "need quote value"

	shift

	local cmd="${1:-}"
	[ -n "$cmd" ] || die "need command"

	shift

	local args="$@"

	cmd_valid "$cmd"

	# First, run the command as specified
	# (which is probably the sym-link name)
	local cmd_path

	cmd_path=$(clean_path "${CMD_DIR}/${cmd}")
	[ -x "$cmd_path" ] || die "invalid path: '$cmd_path'"

	log ":test_cmd_via_sym_link: cmd: '$cmd'," \
		"cmd_path: '$cmd_path', args: '$args'"

	if [ "$quote" = 'yes' ]
	then
		run \
			--keep-empty-lines \
			--separate-stderr \
			-- \
			"${cmd_path}" "${args}"
	else
		run \
			--keep-empty-lines \
			--separate-stderr \
			-- \
			"${cmd_path}" ${args}
	fi

	log ""

	return 0
}

_test_cmd_via_multi_call_binary() {
	local quote="${1:-}"
	[ -n "$quote" ] || die "need quote value"

	shift

	local cmd="${1:-}"
	[ -n "$cmd" ] || die "need command"

	shift

	local args="$@"

	local abox_cmd_path
	abox_cmd_path=$(clean_path "${CMD_DIR}/${ABOX}")

	local cmd_path
	cmd_path="${abox_cmd_path}"
	[ -x "$cmd_path" ] || die "invalid path: '$cmd_path'"

	cmd_valid "$cmd"

	log ":test_cmd_via_multi_call_binary: cmd: '$cmd'," \
		"cmd_path: '$cmd_path', args: '$args'"

	if [ "$quote" = 'yes' ]
	then
		run \
			--keep-empty-lines \
			--separate-stderr \
			-- \
            "${cmd_path}" "${cmd}" "${args}"
	else
		run \
			--keep-empty-lines \
			--separate-stderr \
			-- \
            "${cmd_path}" "${cmd}" ${args}
	fi

	log ""

	return 0
}

# BUGS: This won't work if:
#
# - The command is expected to fail!
# - The arguments must not be quoted (use 'test_cmd_unquoted_args()').
_test_cmd() {
	local quote="${1:-}"
	[ -n "$quote" ] || die "need quote value"

	shift

	local cmd="${1:-}"
	[ -n "$cmd" ] || die "need command"

	shift

	local args="$@"

	cmd_valid "$cmd"

	_test_cmd_via_sym_link "$quote" "$cmd" "$args"

	# cmd was the multi-call binary, so nothing more to do.
	[ "$cmd" = "$ABOX" ] && return 0

	# Now, run the same command using the multi-call binary method.

	_test_cmd_via_multi_call_binary "$quote" "$cmd" "$args"

	return 0
}

test_cmd() {
	local cmd="${1:-}"
	[ -n "$cmd" ] || die "need command"

	shift
	local args="$@"

	local quote='yes'

	_test_cmd "$quote" "$cmd" "$args"

	return 0
}

test_cmd_via_sym_link() {
	local cmd="${1:-}"
	[ -n "$cmd" ] || die "need command"

	shift
	local args="$@"

	local quote='yes'

	_test_cmd_via_sym_link "$quote" "$cmd" "$args"

	return 0
}

test_cmd_via_multi_call_binary() {
	local cmd="${1:-}"
	[ -n "$cmd" ] || die "need command"

	shift

	local args="$@"

	local quote='yes'

	_test_cmd_via_multi_call_binary "$quote" "$cmd" "$args"

	return 0
}

test_cmd_unquoted_args() {
	local cmd="${1:-}"
	[ -n "$cmd" ] || die "need command"

	shift

	local args="$@"

	local quote
	quote='no'

	_test_cmd "$quote" "$cmd" $args

	return 0
}

test_cmd_via_sym_link_unquoted_args() {
	local cmd="${1:-}"
	[ -n "$cmd" ] || die "need command"

	shift

	local args="$@"

	local quote
	quote='no'

	_test_cmd_via_sym_link "$quote" "$cmd" "$args"

	return 0
}

test_cmd_via_multi_call_binary_unquoted_args() {
	local cmd="${1:-}"
	[ -n "$cmd" ] || die "need command"

	shift

	local args="$@"

	local quote
	quote='no'

	_test_cmd_via_multi_call_binary "$quote" "$cmd" "$args"

	return 0
}
