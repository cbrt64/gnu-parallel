#!/usr/bin/env bash

# This file must be sourced in bash:
#
#   source `which env_parallel.bash`
#
# after which 'env_parallel' works
#
#
# Copyright (C) 2016-2022 Ole Tange, http://ole.tange.dk and Free
# Software Foundation, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, see <http://www.gnu.org/licenses/>
# or write to the Free Software Foundation, Inc., 51 Franklin St,
# Fifth Floor, Boston, MA 02110-1301 USA
#
# SPDX-FileCopyrightText: 2021-2022 Ole Tange, http://ole.tange.dk and Free Software and Foundation, Inc.
# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck disable=SC2006

env_parallel() {
    # env_parallel.bash

    _names_of_ALIASES() {
	# No aliases will return false. This error should be ignored.
	compgen -a || true
    }
    _bodies_of_ALIASES() {
	local _i
	for _i in "$@"; do
	    # shellcheck disable=SC2046
	    if [ $(alias "$_i" | wc -l) == 1 ] ; then
		true Alias is a single line. Good.
	    else
		_warning_PAR "Alias '$_i' contains newline."
		_warning_PAR "Make sure the command has at least one newline after '$_i'."
		_warning_PAR "See BUGS in 'man env_parallel'."
	    fi
	done
	alias "$@"
    }
    _names_of_FUNCTIONS() {
	compgen -A function
    }
    _bodies_of_FUNCTIONS() {
	typeset -f "$@"
    }
    _names_of_VARIABLES() {
	compgen -A variable
    }
    _bodies_of_VARIABLES() {
	typeset -p "$@"
    }
    _ignore_HARDCODED() {
	# Copying $RANDOM will cause it not to be random
	# The rest cannot be detected as read-only
	echo '(RANDOM|_|TIMEOUT|GROUPS|FUNCNAME|DIRSTACK|PIPESTATUS|USERNAME|BASHPID|BASH_[A-Z_]+)'
    }
    _ignore_READONLY() {
	# shellcheck disable=SC1078,SC1079,SC2026
	readonly | perl -e '@r = map {
                chomp;
                # sh on UnixWare: readonly TIMEOUT
	        # ash: readonly var='val'
	        # ksh: var='val'
		# mksh: PIPESTATUS[0]
                s/^(readonly )?([^=\[ ]*?)(\[\d+\])?(=.*|)$/$2/ or
	        # bash: declare -ar BASH_VERSINFO=([0]="4" [1]="4")
	        # zsh: typeset -r var='val'
                  s/^\S+\s+\S+\s+(\S[^=]*)(=.*|$)/$1/;
                $_ } <>;
            $vars = join "|",map { quotemeta $_ } @r;
            print $vars ? "($vars)" : "(,,nO,,VaRs,,)";
            '
    }
    _remove_bad_NAMES() {
	# Do not transfer vars and funcs from env_parallel
	# shellcheck disable=SC2006
	_ignore_RO="`_ignore_READONLY`"
	# shellcheck disable=SC2006
	_ignore_HARD="`_ignore_HARDCODED`"
	# Macos-grep does not like long patterns
	# Old Solaris grep does not support -E
	# Perl Version of:
	# grep -Ev '^(...)$' |
	perl -ne '/^(
		     PARALLEL_ENV|
		     PARALLEL_TMP|
		     _alias_NAMES|
		     _bodies_of_ALIASES|
		     _bodies_of_FUNCTIONS|
		     _bodies_of_VARIABLES|
		     _error_PAR|
		     _function_NAMES|
		     _get_ignored_VARS|
		     _grep_REGEXP|
		     _ignore_HARD|
		     _ignore_HARDCODED|
		     _ignore_READONLY|
		     _ignore_RO|
		     _ignore_UNDERSCORE|
		     _list_alias_BODIES|
		     _list_function_BODIES|
		     _list_variable_VALUES|
		     _make_grep_REGEXP|
		     _names_of_ALIASES|
		     _names_of_FUNCTIONS|
		     _names_of_VARIABLES|
		     _names_of_maybe_FUNCTIONS|
		     _parallel_exit_CODE|
		     _prefix_PARALLEL_ENV|
		     _prefix_PARALLEL_ENV|
		     _remove_bad_NAMES|
		     _remove_readonly|
		     _variable_NAMES|
		     _warning_PAR|
		     _which_PAR)$/x and next;
	    # Filter names matching --env
	    /^'"$_grep_REGEXP"'$/ or next;
            /^'"$_ignore_UNDERSCORE"'$/ and next;
	    # Remove readonly variables
            /^'"$_ignore_RO"'$/ and next;
            /^'"$_ignore_HARD"'$/ and next;
            print;'
    }
    _prefix_PARALLEL_ENV() {
        shopt 2>/dev/null |
        perl -pe 's:\s+off:;: and s/^/shopt -u /;
                  s:\s+on:;: and s/^/shopt -s /;
                  s:;$:&>/dev/null;:';
        echo 'shopt -s expand_aliases &>/dev/null';
    }

    _get_ignored_VARS() {
        perl -e '
            for(@ARGV){
                $next_is_env and push @envvar, split/,/, $_;
                $next_is_env=/^--env$/;
            }
            if(grep { /^_$/ } @envvar) {
                if(not open(IN, "<", "$ENV{HOME}/.parallel/ignored_vars")) {
             	    print STDERR "parallel: Error: ",
            	    "Run \"parallel --record-env\" in a clean environment first.\n";
                } else {
            	    chomp(@ignored_vars = <IN>);
                }
            }
            if($ENV{PARALLEL_IGNORED_NAMES}) {
                push @ignored_vars, split/\s+/, $ENV{PARALLEL_IGNORED_NAMES};
                chomp @ignored_vars;
            }
            $vars = join "|",map { quotemeta $_ } @ignored_vars;
	    print $vars ? "($vars)" : "(,,nO,,VaRs,,)";
            ' -- "$@"
    }

    # Get the --env variables if set
    # --env _ should be ignored
    # and convert  a b c  to (a|b|c)
    # If --env not set: Match everything (.*)
    _make_grep_REGEXP() {
        perl -e '
            for(@ARGV){
                /^_$/ and $next_is_env = 0;
                $next_is_env and push @envvar, split/,/, $_;
                $next_is_env = /^--env$/;
            }
            $vars = join "|",map { quotemeta $_ } @envvar;
            print $vars ? "($vars)" : "(.*)";
            ' -- "$@"
    }
    _which_PAR() {
	# type returns:
	#   ll is an alias for ls -l (in ash)
	#   bash is a tracked alias for /bin/bash
	#   true is a shell builtin (in bash)
	#   myfunc is a function (in bash)
	#   myfunc is a shell function (in zsh)
	#   which is /usr/bin/which (in sh, bash)
	#   which is hashed (/usr/bin/which)
	#   gi is aliased to `grep -i' (in bash)
	#   aliased to `alias | /usr/bin/which --tty-only --read-alias --show-dot --show-tilde'
	# Return 0 if found, 1 otherwise
	LANG=C type "$@" |
	    perl -pe '$exit += (s/ is an alias for .*// ||
	                        s/ is aliased to .*// ||
                                s/ is a function// ||
                                s/ is a shell function// ||
                                s/ is a shell builtin// ||
                                s/.* is hashed .(\S+).$/$1/ ||
                                s/.* is (a tracked alias for )?//);
                      END { exit not $exit }'
    }
    _warning_PAR() {
	echo "env_parallel: Warning: $*" >&2
    }
    _error_PAR() {
	echo "env_parallel: Error: $*" >&2
    }

    # Bash is broken in version 3.2.25 and 4.2.39
    # The crazy '[ "`...`" == "" ]' is needed for the same reason
    if [ "`_which_PAR parallel`" == "" ]; then
	# shellcheck disable=SC2016
	_error_PAR 'parallel must be in $PATH.'
	return 255
    fi

    # Grep regexp for vars given by --env
    # shellcheck disable=SC2006
    _grep_REGEXP="`_make_grep_REGEXP \"$@\"`"
    unset _make_grep_REGEXP

    # Deal with --env _
    # shellcheck disable=SC2006
    _ignore_UNDERSCORE="`_get_ignored_VARS \"$@\"`"
    unset _get_ignored_VARS

    # --record-env
    # Bash is broken in version 3.2.25 and 4.2.39
    # The crazy '[ "`...`" == 0 ]' is needed for the same reason
    if [ "`perl -e 'exit grep { /^--record-env$/ } @ARGV' -- "$@"; echo $?`" == 0 ] ; then
	true skip
    else
	(_names_of_ALIASES;
	 _names_of_FUNCTIONS;
	 _names_of_VARIABLES) |
	    cat > "$HOME"/.parallel/ignored_vars
	return 0
    fi

    # --session
    # Bash is broken in version 3.2.25 and 4.2.39
    # The crazy '[ "`...`" == 0 ]' is needed for the same reason
    if [ "`perl -e 'exit grep { /^--session$/ } @ARGV' -- "$@"; echo $?`" == 0 ] ; then
	true skip
    else
	# Insert ::: between each level of session
	# so you can pop off the last ::: at --end-session
	# shellcheck disable=SC2006
	PARALLEL_IGNORED_NAMES="`echo \"$PARALLEL_IGNORED_NAMES\";
          echo :::;
          (_names_of_ALIASES;
	   _names_of_FUNCTIONS;
	   _names_of_VARIABLES) | perl -ne '
	    BEGIN{
	      map { $ignored_vars{$_}++ }
                split/\s+/, $ENV{PARALLEL_IGNORED_NAMES};
	    }
	    chomp;
	    for(split/\s+/) {
	      if(not $ignored_vars{$_}) {
	        print $_,\"\\n\";
	      }
            }
	    '`"
	export PARALLEL_IGNORED_NAMES
	return 0
    fi
    # Bash is broken in version 3.2.25 and 4.2.39
    # The crazy '[ "`...`" == 0 ]' is needed for the same reason
    if [ "`perl -e 'exit grep { /^--end.?session$/ } @ARGV' -- "$@"; echo $?`" == 0 ] ; then
	true skip
    else
	# Pop off last ::: from PARALLEL_IGNORED_NAMES
	# shellcheck disable=SC2006
	PARALLEL_IGNORED_NAMES="`perl -e '
          $ENV{PARALLEL_IGNORED_NAMES} =~ s/(.*):::.*?$/$1/s;
	  print $ENV{PARALLEL_IGNORED_NAMES}
        '`"
	return 0
    fi
    # Grep alias names
    # shellcheck disable=SC2006
    _alias_NAMES="`_names_of_ALIASES | _remove_bad_NAMES | xargs echo`"
    _list_alias_BODIES="_bodies_of_ALIASES $_alias_NAMES"
    if [ "$_alias_NAMES" = "" ] ; then
	# no aliases selected
	_list_alias_BODIES="true"
    fi
    unset _alias_NAMES

    # Grep function names
    # shellcheck disable=SC2006
    _function_NAMES="`_names_of_FUNCTIONS | _remove_bad_NAMES | xargs echo`"
    _list_function_BODIES="_bodies_of_FUNCTIONS $_function_NAMES"
    if [ "$_function_NAMES" = "" ] ; then
	# no functions selected
	_list_function_BODIES="true"
    fi
    unset _function_NAMES

    # Grep variable names
    # shellcheck disable=SC2006
    _variable_NAMES="`_names_of_VARIABLES | _remove_bad_NAMES | xargs echo`"
    _list_variable_VALUES="_bodies_of_VARIABLES $_variable_NAMES"
    if [ "$_variable_NAMES" = "" ] ; then
	# no variables selected
	_list_variable_VALUES="true"
    fi
    unset _variable_NAMES

    _which_TRUE="`_which_PAR true`"
    # Copy shopt (so e.g. extended globbing works)
    # But force expand_aliases as aliases otherwise do not work
    PARALLEL_ENV="`
        _prefix_PARALLEL_ENV
        $_list_alias_BODIES;
        $_list_function_BODIES;
        $_list_variable_VALUES;
    `"
    export PARALLEL_ENV
    unset _list_alias_BODIES _list_variable_VALUES _list_function_BODIES
    unset _bodies_of_ALIASES _bodies_of_VARIABLES _bodies_of_FUNCTIONS
    unset _names_of_ALIASES _names_of_VARIABLES _names_of_FUNCTIONS
    unset _ignore_HARDCODED _ignore_READONLY _ignore_UNDERSCORE
    unset _remove_bad_NAMES _grep_REGEXP
    unset _prefix_PARALLEL_ENV
    # Test if environment is too big
    if [ "`_which_PAR true`" == "$_which_TRUE" ] ; then
	parallel "$@"
	_parallel_exit_CODE=$?
	# Clean up variables/functions
	unset PARALLEL_ENV
	unset _which_PAR _which_TRUE
	unset _warning_PAR _error_PAR
	# Unset _parallel_exit_CODE before return
	eval "unset _parallel_exit_CODE; return $_parallel_exit_CODE"
    else
	unset PARALLEL_ENV;
	_error_PAR "Your environment is too big."
	_error_PAR "You can try 3 different approaches:"
	_error_PAR "1. Run 'env_parallel --session' before you set"
	_error_PAR "   variables or define functions."
	_error_PAR "2. Use --env and only mention the names to copy."
	_error_PAR "3. Try running this in a clean environment once:"
	_error_PAR "     env_parallel --record-env"
	_error_PAR "   And then use '--env _'"
	_error_PAR "For details see: man env_parallel"
	return 255
    fi
}

parset() {
    _parset_PARALLEL_PRG=parallel
    _parset_main "$@"
}

env_parset() {
    _parset_PARALLEL_PRG=env_parallel
    _parset_main "$@"
}

_parset_main() {
    # If $1 contains ',' or space:
    #   Split on , to get the destination variable names
    # If $1 is a single destination variable name:
    #   Treat it as the name of an array
    #
    #   # Create array named myvar
    #   parset myvar echo ::: {1..10}
    #   echo ${myvar[5]}
    #
    #   # Put output into $var_a $var_b $var_c
    #   varnames=(var_a var_b var_c)
    #   parset "${varnames[*]}" echo ::: {1..3}
    #   echo $var_c
    #
    #   # Put output into $var_a4 $var_b4 $var_c4
    #   parset "var_a4 var_b4 var_c4" echo ::: {1..3}
    #   echo $var_c4

    _parset_NAME="$1"
    if [ "$_parset_NAME" = "" ] ; then
	echo parset: Error: No destination variable given. >&2
	echo parset: Error: Try: >&2
	echo parset: Error: ' ' parset myarray echo ::: foo bar >&2
	return 255
    fi
    if [ "$_parset_NAME" = "--help" ] ; then
	echo parset: Error: Usage: >&2
	echo parset: Error: ' ' parset varname GNU Parallel options and command >&2
	echo
	parallel --help
	return 255
    fi
    if [ "$_parset_NAME" = "--version" ] ; then
	# shellcheck disable=SC2006
	echo "parset 20220323 (GNU parallel `parallel --minversion 1`)"
	echo "Copyright (C) 2007-2022 Ole Tange, http://ole.tange.dk and Free Software"
	echo "Foundation, Inc."
	echo "License GPLv3+: GNU GPL version 3 or later <https://gnu.org/licenses/gpl.html>"
	echo "This is free software: you are free to change and redistribute it."
	echo "GNU parallel comes with no warranty."
	echo
	echo "Web site: https://www.gnu.org/software/parallel"
	echo
	echo "When using programs that use GNU Parallel to process data for publication"
	echo "please cite as described in 'parallel --citation'."
	echo
	return 255
    fi
    shift

    # Bash: declare -A myassoc=( )
    # Zsh: typeset -A myassoc=( )
    # Ksh: typeset -A myassoc=( )
    # shellcheck disable=SC2039,SC2169
    if (typeset -p "$_parset_NAME" 2>/dev/null; echo) |
	    perl -ne 'exit not (/^declare[^=]+-A|^typeset[^=]+-A/)' ; then
	# This is an associative array
	# shellcheck disable=SC2006
	eval "`$_parset_PARALLEL_PRG -k --_parset assoc,"$_parset_NAME" "$@"`"
	# The eval returns the function!
    else
	# This is a normal array or a list of variable names
	# shellcheck disable=SC2006
	eval "`$_parset_PARALLEL_PRG -k --_parset var,"$_parset_NAME" "$@"`"
	# The eval returns the function!
    fi
}
