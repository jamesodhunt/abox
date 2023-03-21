#---------------------------------------------------------------------
# vim:set noexpandtab:
#---------------------------------------------------------------------
# Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
#
# SPDX-License-Identifier: Apache-2.0
#---------------------------------------------------------------------
# FIXME: Handle i18n issues if parsing command output.
#---------------------------------------------------------------------

export LC_ALL="C"
export LANG="C"

asm_ext='.asm'

die()
{
	echo >&2 "ERROR: $*"
	exit 1
}

#---------------------------------------------------------------------
# Description: Write a message to stderr.
#
# Argument: Message to display.
#
# Format:
#
# - If the argument starts with a colon (':'), the message will be
#   displayed without a newline character.
#
# - If the argument is a blank string, this will be assumed to be the
#   "end" of a two part sequence so will display an "OK\n" message.
#
# Notes:
#
# BATS "owns" stdout: any data written to that stream is checked by
# BATS. If a test fails, stdout and stderr are displayed so stderr is
# good for adding debug output for display when a test fails. But if you
# wish to produce debug output for a non-failing test, the only
# solutions are to write to a file, or write direct to the terminal.
#---------------------------------------------------------------------
log()
{
	local msg="$*"

	local redirect='>&2'
	local newline='yes'

	grep -q '^:' <<< "$msg" && newline='no' || true

 	[ -n "$DEBUG" ] && redirect='>/dev/tty'

	local expanded_redirect
	eval expanded_redirect="$redirect"

	if [ "$newline" = 'yes' ]
	then
		if [ -z "$msg" ]
		then
			echo -e $expanded_redirect ": OK"
		else
			echo -e $expanded_redirect ": $msg"
		fi
	else
		local final
		final=$(echo "$msg"|sed 's/^://g')
		echo -en $expanded_redirect "DEBUG: $final"
	fi
}

setup_test_env()
{
	local abox_binary="${1:-}"
	[ -z "$abox_binary" ] && die "need binary path"
	grep -q '^/' <<< "$abox_binary" || die "need full path to binary"
	[ -e "$abox_binary" ] || die "binary missing"
	[ -x "$abox_binary" ] || die "binary not executable"

	local cmds_dir="${2:-}"
	[ -d "$cmds_dir" ] || die "need commands dir"
	grep -q '^/' <<< "$cmds_dir" || die "commands dir must be a full path"

	local test_dir="${3:-}"
	[ -z "$test_dir" ] && die "need test dir"

	[ -d "$test_dir" ] || die "invalid test dir: '$test_dir'"

	pushd "$test_dir" &>/dev/null

	local test_bin_dir="${test_dir}/bin"
	mkdir -p "$test_bin_dir"

	pushd "$test_bin_dir" &>/dev/null

	# Create a link for all valid commands
	local links=()

	local cmd
	for cmd in "$cmds_dir"/*.asm
	do
		local cmd_name
		cmd_name=$(basename -s "$asm_ext" "$cmd")

		#echo "FIXME: cmd_name: '$cmd_name'"
		links+=("${cmd_name}")
	done

	# Create a link for an invalid command
	links+=("invalid")

	# Create a link with the same name as the binary
	# since this should also work!
	local abox_name
	abox_name=$(basename "$abox_binary")

	links+=("${abox_name}")

	local link

	for link in "${links[@]}"
	do
		ln -fs "$abox_binary" "$link"
	done

	popd &>/dev/null

	popd &>/dev/null
}

clean_path()
{
	local path="${1:-}"

	[ -e "$path" ] || die "invalid path: '$path'"

	# FIXME: This function should return the full path with "../"
	# resolved, but *not* expand sym-links as we wish to return the
	# sym-link name, not the target name!
	echo "$path"
}
