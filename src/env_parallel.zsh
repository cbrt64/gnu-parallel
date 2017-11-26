#!/usr/bin/env zsh

# This file must be sourced in zsh:
#
#   source =env_parallel.zsh
#
# after which 'env_parallel' works
#
#
# Copyright (C) 2016,2017
# Ole Tange and Free Software Foundation, Inc.
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

env_parallel() {
    # env_parallel.zsh

    _names_of_ALIASES() {
	print -l ${(k)aliases}
    }
    _bodies_of_ALIASES() {
	echo "alias "$(echo "$@"|xargs)" | perl -pe 's/^/alias /'"
    }
    _names_of_FUNCTIONS() {
	print -l ${(k)functions}
    }
    _bodies_of_FUNCTIONS() {
	echo "typeset -f "$(echo "$@"|xargs)
    }
    _names_of_VARIABLES() {
	print -l ${(k)parameters}
    }
    _bodies_of_VARIABLES() {
	echo typeset -p "$(echo $@|xargs)" '| grep -aFvf <(typeset -pr)'
    }
    _remove_bad_NAMES() {
	# Do not transfer vars and funcs from env_parallel
	grep -Ev '^(_names_of_ALIASES|_bodies_of_ALIASES|_names_of_maybe_FUNCTIONS|_names_of_FUNCTIONS|_bodies_of_FUNCTIONS|_names_of_VARIABLES|_bodies_of_VARIABLES|_remove_bad_NAMES|_prefix_PARALLEL_ENV|_get_ignored_VARS|_make_grep_REGEXP|_ignore_UNDERSCORE|_alias_NAMES|_list_alias_BODIES|_function_NAMES|_list_function_BODIES|_variable_NAMES|_list_variable_VALUES|_prefix_PARALLEL_ENV|PARALLEL_TMP)$' |
	    # Filter names matching --env
	    grep -E "^$_grep_REGEXP"\$ | grep -vE "^$_ignore_UNDERSCORE"\$ |
	    grep -v '=' |
            grep -Ev '^([-?#!$*@_0]|zsh_eval_context|ZSH_EVAL_CONTEXT|LINENO|IFS|commands|functions|options|aliases|EUID|EGID|UID|GID)$' |
            grep -Ev '^(dis_patchars|patchars|terminfo|funcstack|galiases|keymaps|parameters|jobdirs|dirstack|functrace|funcsourcetrace|zsh_scheduled_events|dis_aliases|dis_reswords|dis_saliases|modules|reswords|saliases|widgets|userdirs|historywords|nameddirs|termcap|dis_builtins|dis_functions|jobtexts|funcfiletrace|dis_galiases|builtins|history|jobstates)$'
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
            	    $vars = join "|",map { quotemeta $_ } "env_parallel", @ignored_vars;
		    print $vars ? "($vars)" : "(,,nO,,VaRs,,)";
                }
            }
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

    if which parallel | grep 'no parallel in' >/dev/null; then
	echo 'env_parallel: Error: parallel must be in $PATH.' >&2
	return 1
    fi
    if which parallel >/dev/null; then
	true which on linux
    else
	echo 'env_parallel: Error: parallel must be in $PATH.' >&2
	return 1
    fi

    # Grep regexp for vars given by --env
    _grep_REGEXP="`_make_grep_REGEXP \"$@\"`"

    # Deal with --env _
    _ignore_UNDERSCORE="`_get_ignored_VARS \"$@\"`"

    # --record-env
    if perl -e 'exit grep { /^--record-env$/ } @ARGV' -- "$@"; then
	true skip
    else
	(_names_of_ALIASES;
	 _names_of_FUNCTIONS;
	 _names_of_VARIABLES) |
	    cat > $HOME/.parallel/ignored_vars
	return 0
    fi
    
    # Grep alias names
    _alias_NAMES="`_names_of_ALIASES | _remove_bad_NAMES`"
    _list_alias_BODIES="alias "$(echo $_alias_NAMES|xargs)" | perl -pe 's/^/alias /'"
    if [ "$_alias_NAMES" = "" ] ; then
	# no aliases selected
	_list_alias_BODIES="true"
    fi
    unset _alias_NAMES

    # Grep function names
    _function_NAMES="`_names_of_FUNCTIONS | _remove_bad_NAMES`"
    _list_function_BODIES="typeset -f "$(echo $_function_NAMES|xargs)
    if [ "$_function_NAMES" = "" ] ; then
	# no functions selected
	_list_function_BODIES="true"
    fi
    unset _function_NAMES

    # Grep variable names
    _variable_NAMES="`_names_of_VARIABLES | _remove_bad_NAMES`"
    _list_variable_VALUES="typeset -p "$(echo $_variable_NAMES|xargs)" |
        grep -aFvf <(typeset -pr)
    "
    if [ "$_variable_NAMES" = "" ] ; then
	# no variables selected
	_list_variable_VALUES="true"
    fi
    unset _variable_NAMES

    PARALLEL_ENV="`
        eval $_list_alias_BODIES;
        eval $_list_function_BODIES;
        eval $_list_variable_VALUES;
    `"
    export PARALLEL_ENV
    unset _list_alias_BODIES
    unset _list_variable_VALUES
    unset _list_function_BODIES
    `which parallel` "$@";
    _parallel_exit_CODE=$?
    unset PARALLEL_ENV;
    return $_parallel_exit_CODE
}

parset() {
    _parset_parallel_prg=parallel
    _parset_main "$@"
}

env_parset() {
    _parset_parallel_prg=env_parallel
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

    _parset_name="$1"
    if [ "$_parset_name" = "" ] ; then
	echo parset: Error: No destination variable given. >&2
	echo parset: Error: Try: >&2
	echo parset: Error: ' ' parset myarray echo ::: foo bar >&2
	return 255
    fi
    shift
    echo "$_parset_name" |
	perl -ne 'chomp;for (split /[, ]/) {
            # Allow: var_32 var[3]
	    if(not /^[a-zA-Z_][a-zA-Z_0-9]*(\[\d+\])?$/) {
                print STDERR "parset: Error: $_ is an invalid variable name.\n";
                print STDERR "parset: Error: Variable names must be letter followed by letters or digits.\n";
                $exitval = 255;
            }
        }
        exit $exitval;
        ' || return 255
    if echo "$_parset_name" | grep -E ',| ' >/dev/null ; then
	# $1 contains , or space
	# Split on , or space to get the names
	eval "$(
	    # Compute results into files
	    $_parset_parallel_prg --files -k "$@" |
		# var1=`cat tmpfile1; rm tmpfile1`
		# var2=`cat tmpfile2; rm tmpfile2`
		parallel -q echo {2}='`cat {1}; rm {1}`' :::: - :::+ $(
		    echo "$_parset_name" |
			perl -pe 's/,/ /g'
			 )
	    )"
    else
	# $1 contains no space or ,
	# => $1 is the name of the array to put data into
	# Supported in: bash
	# Arrays do not work in: ash dash
	eval $_parset_name="( $( $_parset_parallel_prg --files -k "$@" |
              perl -pe 'chop;$_="\"\`cat $_; rm $_\`\" "' ) )"
    fi
}

