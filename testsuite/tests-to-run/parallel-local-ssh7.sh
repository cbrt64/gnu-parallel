#!/bin/bash

echo '### test --env _, env_parallel for different shells'

#
## par_*_man = tests from the man page
#

par_ash_man() {
  echo '### ash'

  myscript=$(cat <<'_EOF'
    echo "### From man env_parallel"

    . `which env_parallel.ash`;

    alias myecho='echo aliases with \= \& \" \!'" \'"
    myecho work
    env_parallel myecho ::: work
    env_parallel -S server myecho ::: work
    env_parallel --env myecho myecho ::: work
    env_parallel --env myecho -S server myecho ::: work

    alias multiline='echo multiline
      echo aliases with \= \& \" \!'" \'"
    multiline work
    env_parallel multiline ::: work
    env_parallel -S server multiline ::: work
    env_parallel --env multiline multiline ::: work
    env_parallel --env multiline -S server multiline ::: work
    alias multiline="dummy"

    # Functions are not supported in ash

    myvar='variables with  = & " !'" '"
    echo "$myvar" work
    env_parallel echo '"$myvar"' ::: work
    env_parallel -S server echo '"$myvar"' ::: work
    env_parallel --env myvar echo '"$myvar"' ::: work
    env_parallel --env myvar -S server echo '"$myvar"' ::: work

    multivar='multiline
    variables with  = & " !'" '"
    echo "$multivar" work
    env_parallel echo '"$multivar"' ::: work
    env_parallel -S server echo '"$multivar"' ::: work
    env_parallel --env multivar echo '"$multivar"' ::: work
    env_parallel --env multivar -S server echo '"$multivar"' ::: work

    # Arrays are not supported in ash

    # Exporting of functions is not supported
    # env_parallel --argsep --- env_parallel -k echo ::: multi level --- env_parallel

    env_parallel ::: true false true false
    echo exit value $? should be 2

    env_parallel --no-such-option 2>&1 >/dev/null
    # Sleep 1 to delay output to stderr to avoid race
    echo exit value $? should be 255 `sleep 1`
_EOF
  )
  ssh ash@lo "$myscript"
}

par_bash_man() {
  echo '### bash'

  myscript=$(cat <<'_EOF'
    echo "### From man env_parallel"

    . `which env_parallel.bash`;
    shopt -s expand_aliases&>/dev/null;

    alias myecho='echo aliases with \= \& \" \!'" \'"
    myecho work
    env_parallel myecho ::: work
    env_parallel -S server myecho ::: work
    env_parallel --env myecho myecho ::: work
    env_parallel --env myecho -S server myecho ::: work

    # multiline aliases with when followed by newline
    alias multiline='echo multiline
      echo aliases with \= \& \" \!'" \'"
    multiline work
    env_parallel 'multiline {};
      echo but only when followed by a newline' ::: work
    env_parallel -S server 'multiline {};
      echo but only when followed by a newline' ::: work
    env_parallel --env multiline 'multiline {};
      echo but only when followed by a newline' ::: work
    env_parallel --env multiline -S server 'multiline {};
      echo but only when followed by a newline' ::: work
    alias multiline="dummy"

    myfunc() { echo functions 'with  = & " !'" '" $*; }
    myfunc work
    env_parallel myfunc ::: work
    env_parallel -S server myfunc ::: work
    env_parallel --env myfunc myfunc ::: work
    env_parallel --env myfunc -S server myfunc ::: work

    myvar='variables with  = & " !'" '"
    echo "$myvar" work
    env_parallel echo '"$myvar"' ::: work
    env_parallel -S server echo '"$myvar"' ::: work
    env_parallel --env myvar echo '"$myvar"' ::: work
    env_parallel --env myvar -S server echo '"$myvar"' ::: work

    multivar='multiline
    variables with  = & " !'" '"
    echo "$multivar" work
    env_parallel echo '"$multivar"' ::: work
    env_parallel -S server echo '"$multivar"' ::: work
    env_parallel --env multivar echo '"$multivar"' ::: work
    env_parallel --env multivar -S server echo '"$multivar"' ::: work

    myarray=(arrays 'with = & " !'" '" work, too)
    echo "${myarray[0]}" "${myarray[1]}" "${myarray[2]}" "${myarray[3]}"
    env_parallel -k echo '"${myarray[{}]}"' ::: 0 1 2 3
    env_parallel -k -S server echo '"${myarray[{}]}"' ::: 0 1 2 3
    env_parallel -k --env myarray echo '"${myarray[{}]}"' ::: 0 1 2 3
    env_parallel -k --env myarray -S server echo '"${myarray[{}]}"' ::: 0 1 2 3

    env_parallel --argsep --- env_parallel -k echo ::: multi level --- env_parallel

    env_parallel ::: true false true false
    echo exit value $? should be 2

    env_parallel --no-such-option 2>&1 >/dev/null
    # Sleep 1 to delay output to stderr to avoid race
    echo exit value $? should be 255 `sleep 1`
_EOF
  )
  ssh bash@lo "$myscript"
}

par_csh_man() {
  echo '### csh'
  myscript=$(cat <<'_EOF'
    echo "### From man env_parallel"

#    source `which env_parallel.csh`;

    alias myecho 'echo aliases with \= \& \"'
    env_parallel myecho ::: work
    env_parallel -S server myecho ::: work
    env_parallel --env myecho myecho ::: work
    env_parallel --env myecho -S server myecho ::: work

    # Functions not supported

    # TODO This does not work
    # set myvar='variables with = & "'" '"
    set myvar='variables with \= \& \"'
    env_parallel echo '$myvar' ::: work
    env_parallel -S server echo '$myvar' ::: work
    env_parallel --env myvar echo '$myvar' ::: work
    env_parallel --env myvar -S server echo '$myvar' ::: work

    # Space is not supported in arrays

    set myarray=(arrays with\=\&\""'" work, too)
    env_parallel -k echo \$'{myarray[{}]}' ::: 1 2 3 4
    env_parallel -k -S server echo \$'{myarray[{}]}' ::: 1 2 3 4
    env_parallel -k --env myarray echo \$'{myarray[{}]}' ::: 1 2 3 4
    env_parallel -k --env myarray -S server echo \$'{myarray[{}]}' ::: 1 2 3 4

    env_parallel --argsep --- env_parallel -k echo ::: multi level --- env_parallel

    env_parallel ::: true false true false
    echo exit value $status should be 2

    env_parallel --no-such-option >/dev/null
    echo exit value $status should be 255 `sleep 1`
_EOF
  )
  # Sometimes the order f*cks up
  stdout ssh csh@lo "$myscript" | LC_ALL=C sort
}

par_dash_man() {
  echo '### dash'

  myscript=$(cat <<'_EOF'
    echo "### From man env_parallel"

    . `which env_parallel.dash`;

    alias myecho='echo aliases with \= \& \" \!'" \'"
    myecho work
    env_parallel myecho ::: work
    env_parallel -S server myecho ::: work
    env_parallel --env myecho myecho ::: work
    env_parallel --env myecho -S server myecho ::: work

    alias multiline='echo multiline
      echo aliases with \= \& \" \!'" \'"
    multiline work
    env_parallel multiline ::: work
    env_parallel -S server multiline ::: work
    env_parallel --env multiline multiline ::: work
    env_parallel --env multiline -S server multiline ::: work
    alias multiline="dummy"

    # Functions are not supported in dash

    myvar='variables with  = & " !'" '"
    echo "$myvar" work
    env_parallel echo '"$myvar"' ::: work
    env_parallel -S server echo '"$myvar"' ::: work
    env_parallel --env myvar echo '"$myvar"' ::: work
    env_parallel --env myvar -S server echo '"$myvar"' ::: work

    multivar='multiline
    variables with  = & " !'" '"
    echo "$multivar" work
    env_parallel echo '"$multivar"' ::: work
    env_parallel -S server echo '"$multivar"' ::: work
    env_parallel --env multivar echo '"$multivar"' ::: work
    env_parallel --env multivar -S server echo '"$multivar"' ::: work

    # Arrays are not supported in dash

    # Exporting of functions is not supported
    # env_parallel --argsep --- env_parallel -k echo ::: multi level --- env_parallel

    env_parallel ::: true false true false
    echo exit value $? should be 2

    env_parallel --no-such-option 2>&1 >/dev/null
    # Sleep 1 to delay output to stderr to avoid race
    echo exit value $? should be 255 `sleep 1`
_EOF
  )
  ssh dash@lo "$myscript"
}

par_fish_man() {
  echo '### fish'
  myscript=$(cat <<'_EOF'
    echo "### From man env_parallel"

    env_parallel --session
    alias myecho='echo aliases with \= \& \" \!'" \'"
    myecho work
    env_parallel myecho ::: work
    env_parallel -S server myecho ::: work
    env_parallel --env myecho myecho ::: work
    env_parallel --env myecho -S server myecho ::: work

    # multiline aliases does not work in fish

    function myfunc
      echo functions 'with  = & " !'" '" $argv;
    end
    myfunc work
    env_parallel myfunc ::: work
    env_parallel -S server myfunc ::: work
    env_parallel --env myfunc myfunc ::: work
    env_parallel --env myfunc -S server myfunc ::: work

    set myvar 'variables with  = & " !'" '"
    echo "$myvar" work
    env_parallel echo '$myvar' ::: work
    env_parallel -S server echo '$myvar' ::: work
    env_parallel --env myvar echo '$myvar' ::: work
    env_parallel --env myvar -S server echo '$myvar' ::: work

    set multivar 'multiline
    variables with  = & " !'" '"
    echo "$multivar" work
    env_parallel echo '"$multivar"' ::: work
    env_parallel -S server echo '"$multivar"' ::: work
    env_parallel --env multivar echo '"$multivar"' ::: work
    env_parallel --env multivar -S server echo '"$multivar"' ::: work

    set myarray arrays 'with  = & " !'" '" work, too
    echo $myarray[1] $myarray[2] $myarray[3] $myarray[4]
    env_parallel -k echo '$myarray[{}]' ::: 1 2 3 4
    env_parallel -k -S server echo '$myarray[{}]' ::: 1 2 3 4
    env_parallel -k --env myarray echo '$myarray[{}]' ::: 1 2 3 4
    env_parallel -k --env myarray -S server echo '$myarray[{}]' ::: 1 2 3 4

    env_parallel --argsep --- env_parallel -k echo ::: multi level --- env_parallel

    env_parallel ::: true false true false
    echo exit value $status should be 2

    env_parallel --no-such-option >/dev/null
    echo exit value $status should be 255 `sleep 1`
_EOF
  )
  ssh fish@lo "$myscript" | LC_ALL=C sort
}

par_ksh_man() {
  echo '### ksh'
  myscript=$(cat <<'_EOF'
    echo "### From man env_parallel"

    . `which env_parallel.ksh`;

    alias myecho='echo aliases with \= \& \" \!'" \'"
    myecho work
    env_parallel myecho ::: work
    env_parallel -S server myecho ::: work
    env_parallel --env myecho myecho ::: work
    env_parallel --env myecho -S server myecho ::: work

    alias multiline='echo multiline
      echo aliases with \= \& \" \!'" \'"
    multiline work
    env_parallel multiline ::: work
    env_parallel -S server multiline ::: work
    env_parallel --env multiline multiline ::: work
    env_parallel --env multiline -S server multiline ::: work
    alias multiline='dummy'

    myfunc() { echo functions 'with  = & " !'" '" $*; }
    myfunc work
    env_parallel myfunc ::: work
    env_parallel -S server myfunc ::: work
    env_parallel --env myfunc myfunc ::: work
    env_parallel --env myfunc -S server myfunc ::: work

    myvar='variables with  = & " !'" '"
    echo "$myvar" work
    env_parallel echo '"$myvar"' ::: work
    env_parallel -S server echo '"$myvar"' ::: work
    env_parallel --env myvar echo '"$myvar"' ::: work
    env_parallel --env myvar -S server echo '"$myvar"' ::: work

    multivar='multiline
    variables with  = & " !'" '"
    echo "$multivar" work
    env_parallel echo '"$multivar"' ::: work
    env_parallel -S server echo '"$multivar"' ::: work
    env_parallel --env multivar echo '"$multivar"' ::: work
    env_parallel --env multivar -S server echo '"$multivar"' ::: work

    myarray=(arrays 'with = & " !'" '" work, too)
    echo "${myarray[0]}" "${myarray[1]}" "${myarray[2]}" "${myarray[3]}"
    env_parallel -k echo '"${myarray[{}]}"' ::: 0 1 2 3
    env_parallel -k -S server echo '"${myarray[{}]}"' ::: 0 1 2 3
    env_parallel -k --env myarray echo '"${myarray[{}]}"' ::: 0 1 2 3
    env_parallel -k --env myarray -S server echo '"${myarray[{}]}"' ::: 0 1 2 3

    echo This may never work
    echo https://unix.stackexchange.com/questions/457031/extract-full-function-definitions
    env_parallel --argsep --- env_parallel -k echo ::: multi level --- env_parallel

    env_parallel ::: true false true false
    echo exit value $? should be 2

    env_parallel --no-such-option 2>&1 >/dev/null
    # Sleep 1 to delay output to stderr to avoid race
    echo exit value $? should be 255 `sleep 1`
_EOF
  )
  ssh ksh@lo "$myscript"
}

par_mksh_man() {
  echo '### mksh'
  myscript=$(cat <<'_EOF'
    echo "### From man env_parallel"

    . `which env_parallel.mksh`;

    alias myecho='echo aliases with \= \& \" \!'" \'"
    myecho work
    env_parallel myecho ::: work
    env_parallel -S server myecho ::: work
    env_parallel --env myecho myecho ::: work
    env_parallel --env myecho -S server myecho ::: work

    alias multiline='echo multiline
      echo aliases with \= \& \" \!'" \'"
    multiline work
    env_parallel multiline ::: work
    env_parallel -S server multiline ::: work
    env_parallel --env multiline multiline ::: work
    env_parallel --env multiline -S server multiline ::: work
    alias multiline='dummy'

    myfunc() { echo functions 'with  = & " !'" '" $*; }
    myfunc work
    env_parallel myfunc ::: work
    env_parallel -S server myfunc ::: work
    env_parallel --env myfunc myfunc ::: work
    env_parallel --env myfunc -S server myfunc ::: work

    myvar='variables with  = & " !'" '"
    echo "$myvar" work
    env_parallel echo '"$myvar"' ::: work
    env_parallel -S server echo '"$myvar"' ::: work
    env_parallel --env myvar echo '"$myvar"' ::: work
    env_parallel --env myvar -S server echo '"$myvar"' ::: work

    multivar='multiline
    variables with  = & " !'" '"
    echo "$multivar" work
    env_parallel echo '"$multivar"' ::: work
    env_parallel -S server echo '"$multivar"' ::: work
    env_parallel --env multivar echo '"$multivar"' ::: work
    env_parallel --env multivar -S server echo '"$multivar"' ::: work

    myarray=(arrays 'with = & " !'" '" work, too)
    echo "${myarray[0]}" "${myarray[1]}" "${myarray[2]}" "${myarray[3]}"
    env_parallel -k echo '"${myarray[{}]}"' ::: 0 1 2 3
    env_parallel -k -S server echo '"${myarray[{}]}"' ::: 0 1 2 3
    env_parallel -k --env myarray echo '"${myarray[{}]}"' ::: 0 1 2 3
    env_parallel -k --env myarray -S server echo '"${myarray[{}]}"' ::: 0 1 2 3

    env_parallel --argsep --- env_parallel -k echo ::: multi level --- env_parallel

    env_parallel ::: true false true false
    echo exit value $? should be 2

    env_parallel --no-such-option 2>&1 >/dev/null
    # Sleep 1 to delay output to stderr to avoid race
    echo exit value $? should be 255 `sleep 1`
_EOF
  )
  ssh mksh@lo "$myscript"
}

par_sh_man() {
  echo '### sh'

  myscript=$(cat <<'_EOF'
    echo "### From man env_parallel"

    . `which env_parallel.sh`;

    alias myecho='echo aliases with \= \& \" \!'" \'"
    myecho work
    env_parallel myecho ::: work
    env_parallel -S server myecho ::: work
    env_parallel --env myecho myecho ::: work
    env_parallel --env myecho -S server myecho ::: work

    alias multiline='echo multiline
      echo aliases with \= \& \" \!'" \'"
    multiline work
    env_parallel multiline ::: work
    env_parallel -S server multiline ::: work
    env_parallel --env multiline multiline ::: work
    env_parallel --env multiline -S server multiline ::: work
    alias multiline="dummy"

    # Functions not supported

    myvar='variables with  = & " !'" '"
    echo "$myvar" work
    env_parallel echo '"$myvar"' ::: work
    env_parallel -S server echo '"$myvar"' ::: work
    env_parallel --env myvar echo '"$myvar"' ::: work
    env_parallel --env myvar -S server echo '"$myvar"' ::: work

    multivar='multiline
    variables with  = & " !'" '"
    echo "$multivar" work
    env_parallel echo '"$multivar"' ::: work
    env_parallel -S server echo '"$multivar"' ::: work
    env_parallel --env multivar echo '"$multivar"' ::: work
    env_parallel --env multivar -S server echo '"$multivar"' ::: work

    # Arrays are not supported

    # Exporting of functions is not supported
    # env_parallel --argsep --- env_parallel -k echo ::: multi level --- env_parallel

    env_parallel ::: true false true false
    echo exit value $? should be 2

    env_parallel --no-such-option 2>&1 >/dev/null
    # Sleep 1 to delay output to stderr to avoid race
    echo exit value $? should be 255 `sleep 1`
_EOF
  )
  ssh sh@lo "$myscript"
}

par_tcsh_man() {
  echo '### tcsh'
  myscript=$(cat <<'_EOF'
    echo "### From man env_parallel"

#    source `which env_parallel.tcsh`

    alias myecho 'echo aliases with \= \& \"'
    env_parallel myecho ::: work
    env_parallel -S server myecho ::: work
    env_parallel --env myecho myecho ::: work
    env_parallel --env myecho -S server myecho ::: work

    echo Functions not supported

    # TODO This does not work
    # set myvar='variables with = & "'" '"
    set myvar='variables with \= \& \"'
    env_parallel echo '$myvar' ::: work
    env_parallel -S server echo '$myvar' ::: work
    env_parallel --env myvar echo '$myvar' ::: work
    env_parallel --env myvar -S server echo '$myvar' ::: work

    # Space is not supported in arrays

    set myarray=(arrays with\=\&\""'" work, too)
    env_parallel -k echo \$'{myarray[{}]}' ::: 1 2 3 4
    env_parallel -k -S server echo \$'{myarray[{}]}' ::: 1 2 3 4
    env_parallel -k --env myarray echo \$'{myarray[{}]}' ::: 1 2 3 4
    env_parallel -k --env myarray -S server echo \$'{myarray[{}]}' ::: 1 2 3 4

    echo 'Segmentation faults? Are you running bsd-csh version 20110502-3?'
    env_parallel --argsep --- env_parallel -k echo ::: multi level --- env_parallel

    env_parallel ::: true false true false
    echo exit value $status should be 2

    env_parallel --no-such-option >/dev/null
    echo exit value $status should be 255 `sleep 1`
_EOF
  )
  ssh -tt tcsh@lo "$myscript"
}

par_zsh_man() {
  echo '### zsh'
  # eval is needed make aliases work
  myscript=$(cat <<'_EOF'
    echo "### From man env_parallel"

    . `which env_parallel.zsh`;

    alias myecho='echo aliases with \= \& \" \!'" \'"
    # eval is needed make aliases work
    eval myecho work
    env_parallel myecho ::: work
    env_parallel -S server myecho ::: work
    env_parallel --env myecho myecho ::: work
    env_parallel --env myecho -S server myecho ::: work

    alias multiline='echo multiline
      echo aliases with \= \& \" \!'" \'"
    eval multiline work
    # Zsh-5.4.2 requires additional quoting when multiline
    # Looks like a bug
    alias multiline='echo multiline
      echo aliases with \\= \\& \\" \\!'" \\\'"
    # eval is needed make aliases work
    env_parallel multiline ::: work
    env_parallel -S server multiline ::: work
    env_parallel --env multiline multiline ::: work
    env_parallel --env multiline -S server multiline ::: work
    alias multiline="dummy"

    myfunc() { echo functions 'with  = & " !'" '" $*; }
    myfunc work
    env_parallel myfunc ::: work
    env_parallel -S server myfunc ::: work
    env_parallel --env myfunc myfunc ::: work
    env_parallel --env myfunc -S server myfunc ::: work

    myvar='variables with  = & " !'" '"
    echo "$myvar" work
    env_parallel echo '"$myvar"' ::: work
    env_parallel -S server echo '"$myvar"' ::: work
    env_parallel --env myvar echo '"$myvar"' ::: work
    env_parallel --env myvar -S server echo '"$myvar"' ::: work

    multivar='multiline
    variables with  = & " !'" '"
    echo "$multivar" work
    env_parallel echo '"$multivar"' ::: work
    env_parallel -S server echo '"$multivar"' ::: work
    env_parallel --env multivar echo '"$multivar"' ::: work
    env_parallel --env multivar -S server echo '"$multivar"' ::: work

    myarray=(arrays 'with = & " !'" '" work, too)
    # zsh counts from 1 - not 0
    echo "${myarray[1]}" "${myarray[2]}" "${myarray[3]}" "${myarray[4]}"
    env_parallel -k echo '"${myarray[{}]}"' ::: 1 2 3 4
    env_parallel -k -S server echo '"${myarray[{}]}"' ::: 1 2 3 4
    env_parallel -k --env myarray echo '"${myarray[{}]}"' ::: 1 2 3 4
    env_parallel -k --env myarray -S server echo '"${myarray[{}]}"' ::: 1 2 3 4

    env_parallel --argsep --- env_parallel -k echo ::: multi level --- env_parallel

    env_parallel ::: true false true false
    echo exit value $? should be 2

    env_parallel --no-such-option 2>&1 >/dev/null
    # Sleep 1 to delay output to stderr to avoid race
    echo exit value $? should be 255 `sleep 1`
_EOF
  )
  ssh zsh@lo "$myscript"
}


par_ash_underscore() {
  echo '### ash'
  myscript=$(cat <<'_EOF'
    echo "### Testing of --env _"

    alias not_copied_alias="echo BAD"
#    not_copied_func() { echo BAD; };
    not_copied_var=BAD
#    not_copied_array=(BAD BAD BAD);
    . `which env_parallel.ash`;
    env_parallel --record-env;
    alias myecho="echo \$myvar aliases";
#    myfunc() { myecho functions $*; };
    myvar="variables in";
#    myarray=(and arrays in);
#    env_parallel myfunc ::: work;
#    env_parallel -S server myfunc ::: work;
    env_parallel --env myvar,myecho myecho ::: work;
    env_parallel --env myvar,myecho -S server myecho ::: work;
    env_parallel --env _ myecho ::: work;
    env_parallel --env _ -S server myecho ::: work;

    env_parallel --env _ -S server not_copied_alias ::: error=OK;
#    env_parallel --env _ -S server not_copied_func ::: error=OK;
    env_parallel --env _ -S server echo \$not_copied_var ::: error=OK;
#    env_parallel --env _ -S server echo \${not_copied_array[@]} ::: error=OK;

    echo myvar >> ~/.parallel/ignored_vars;
    env_parallel --env _ myecho ::: work;
    env_parallel --env _ -S server myecho ::: work;
#    echo myarray >> ~/.parallel/ignored_vars;
#    env_parallel --env _ myfunc ::: work;
#    env_parallel --env _ -S server myfunc ::: work;
    echo myecho >> ~/.parallel/ignored_vars;
    env_parallel --env _ myecho ::: work;
    echo "OK if no myecho    ^^^^^^^^^^^^^^^^^" >&2;
    env_parallel --env _ -S server myecho ::: work;
    echo "OK if no myecho    ^^^^^^^^^^^^^^^^^" >&2;
#    echo myfunc >> ~/.parallel/ignored_vars;
#    env_parallel --env _ myfunc ::: work;
#    echo "OK if no myfunc         ^^^^^^^^^^^^^^^^^" >&2;
#    env_parallel --env _ -S server myfunc ::: work;
#    echo "OK if no myfunc         ^^^^^^^^^^^^^^^^^" >&2;
_EOF
  )
  ssh ash@lo "$myscript"
}

par_bash_underscore() {
  echo '### bash'
  myscript=$(cat <<'_EOF'
    echo "### Testing of --env _"

    . `which env_parallel.bash`;

    alias not_copied_alias="echo BAD"
    not_copied_func() { echo BAD; };
    not_copied_var=BAD
    not_copied_array=(BAD BAD BAD);
    env_parallel --record-env;
    alias myecho="echo \$myvar aliases in";
    myfunc() { myecho ${myarray[@]} functions $*; };
    myvar="variables in";
    myarray=(and arrays in);
    env_parallel myfunc ::: work;
    env_parallel -S server myfunc ::: work;
    env_parallel --env myfunc,myvar,myarray,myecho myfunc ::: work;
    env_parallel --env myfunc,myvar,myarray,myecho -S server myfunc ::: work;
    env_parallel --env _ myfunc ::: work;
    env_parallel --env _ -S server myfunc ::: work;

    env_parallel --env _ -S server not_copied_alias ::: error=OK;
    env_parallel --env _ -S server not_copied_func ::: error=OK;
    env_parallel --env _ -S server echo \$not_copied_var ::: error=OK;
    env_parallel --env _ -S server echo \${not_copied_array[@]} ::: error=OK;

    echo myvar >> ~/.parallel/ignored_vars;
    env_parallel --env _ myfunc ::: work;
    env_parallel --env _ -S server myfunc ::: work;
    echo myarray >> ~/.parallel/ignored_vars;
    env_parallel --env _ myfunc ::: work;
    env_parallel --env _ -S server myfunc ::: work;
    echo myecho >> ~/.parallel/ignored_vars;
    env_parallel --env _ myfunc ::: work;
    echo "OK if no myecho      ^^^^^^^^^^^^^^^^^^^^^^^^^" >&2;
    env_parallel --env _ -S server myfunc ::: work;
    echo "OK if no myecho      ^^^^^^^^^^^^^^^^^^^^^^^^^" >&2;
    echo myfunc >> ~/.parallel/ignored_vars;
    env_parallel --env _ myfunc ::: work;
    echo "OK if no myfunc      ^^^^^^^^^^^^^^^^^^^^^^^^^" >&2;
    env_parallel --env _ -S server myfunc ::: work;
    echo "OK if no myfunc      ^^^^^^^^^^^^^^^^^^^^^^^^^" >&2;
_EOF
  )
  stdout ssh bash@lo "$myscript" |
      perl -pe 's/line ..:/line XX:/;
                s@environment:@/bin/bash:@;'
}

par_csh_underscore() {
  echo '### csh'
  myscript=$(cat <<'_EOF'
    echo "### Testing of --env _"

#    source `which env_parallel.csh`;

    env_parallel --record-env;
    alias myecho "echo "\$"myvar "\$'myarray'" aliases";
    set myvar="variables";
    set myarray=(and arrays in);
    env_parallel myecho ::: work;
    env_parallel -S server myecho ::: work;
    env_parallel --env myvar,myarray,myecho myecho ::: work;
    env_parallel --env myvar,myarray,myecho -S server myecho ::: work;
    env_parallel --env _ myecho ::: work;
    env_parallel --env _ -S server myecho ::: work;

    echo myvar >> ~/.parallel/ignored_vars;
    env_parallel --env _ myecho ::: work;
    env_parallel --env _ -S server myecho ::: work;
    alias myecho "echo "\$'myarray'" aliases";
    echo myarray >> ~/.parallel/ignored_vars;
    env_parallel --env _ myecho ::: work;
    env_parallel --env _ -S server myecho ::: work;
    echo myecho >> ~/.parallel/ignored_vars;
    env_parallel --env _ myecho ::: work;
    echo "OK      ^^^^^^^^^^^^^^^^^ if no myecho" >/dev/stderr;
    env_parallel --env _ -S server myecho ::: work;
    echo "OK      ^^^^^^^^^^^^^^^^^ if no myecho" >/dev/stderr;
_EOF
  )
  ssh -tt csh@lo "$myscript"
}

par_dash_underscore() {
  echo '### dash'
  myscript=$(cat <<'_EOF'
    echo "### Testing of --env _"

    alias not_copied_alias="echo BAD"
#    not_copied_func() { echo BAD; };
    not_copied_var=BAD
#    not_copied_array=(BAD BAD BAD);
    . `which env_parallel.dash`;
    env_parallel --record-env;
    alias myecho="echo \$myvar aliases";
#    myfunc() { myecho functions $*; };
    myvar="variables in";
#    myarray=(and arrays in);
#    env_parallel myfunc ::: work;
#    env_parallel -S server myfunc ::: work;
    env_parallel --env myvar,myecho myecho ::: work;
    env_parallel --env myvar,myecho -S server myecho ::: work;
    env_parallel --env _ myecho ::: work;
    env_parallel --env _ -S server myecho ::: work;

    env_parallel --env _ -S server not_copied_alias ::: error=OK;
#    env_parallel --env _ -S server not_copied_func ::: error=OK;
    env_parallel --env _ -S server echo \$not_copied_var ::: error=OK;
#    env_parallel --env _ -S server echo \${not_copied_array[@]} ::: error=OK;

    echo myvar >> ~/.parallel/ignored_vars;
    env_parallel --env _ myecho ::: work;
    env_parallel --env _ -S server myecho ::: work;
#    echo myarray >> ~/.parallel/ignored_vars;
#    env_parallel --env _ myfunc ::: work;
#    env_parallel --env _ -S server myfunc ::: work;
    echo myecho >> ~/.parallel/ignored_vars;
    env_parallel --env _ myecho ::: work;
    echo "OK if no myecho    ^^^^^^^^^^^^^^^^^" >&2;
    env_parallel --env _ -S server myecho ::: work;
    echo "OK if no myecho    ^^^^^^^^^^^^^^^^^" >&2;
#    echo myfunc >> ~/.parallel/ignored_vars;
#    env_parallel --env _ myfunc ::: work;
#    echo "OK if no myfunc         ^^^^^^^^^^^^^^^^^" >&2;
#    env_parallel --env _ -S server myfunc ::: work;
#    echo "OK if no myfunc         ^^^^^^^^^^^^^^^^^" >&2;
_EOF
  )
  ssh dash@lo "$myscript"
}

par_fish_underscore() {
  echo '### fish'
  myscript=$(cat <<'_EOF'
    echo "Fish is broken"
    echo "### Testing of --env _"

#    . `which env_parallel.fish`;
    true > ~/.parallel/ignored_vars;

    alias not_copied_alias="echo BAD"
    function not_copied_func
      echo BAD
    end
    set not_copied_var "BAD";
    set not_copied_array BAD BAD BAD;
#    env_parallel --record-env;
    env_parallel --session;
    alias myecho="echo \$myvar aliases";
    function myfunc
      myecho $myarray functions $argv
    end
    set myvar "variables in";
    set myarray and arrays in;
    env_parallel myfunc ::: work;
    env_parallel -S server myfunc ::: work;
    env_parallel --env myfunc,myvar,myarray,myecho myfunc ::: work;
    env_parallel --env myfunc,myvar,myarray,myecho -S server myfunc ::: work;
    env_parallel --env _ myfunc ::: work;
    env_parallel --env _ -S server myfunc ::: work;

    env_parallel --env _ -S server not_copied_alias ::: error=OK;
    env_parallel --env _ -S server not_copied_func ::: error=OK;
    env_parallel --env _ -S server echo \$not_copied_var ::: error=OK;
    env_parallel --env _ -S server echo \$not_copied_array ::: error=OK;

    echo myvar > ~/.parallel/ignored_vars;
    env_parallel --env _ myfunc ::: work;
    env_parallel --env _ -S server myfunc ::: work;
    echo myarray >> ~/.parallel/ignored_vars;
    env_parallel --env _ myfunc ::: work;
    env_parallel --env _ -S server myfunc ::: work;
    echo myecho >> ~/.parallel/ignored_vars;
    env_parallel --env _ myfunc ::: work;
    echo "OK if   ^^^^^^^^^^^^^^^^^ no myecho" >&2;
    env_parallel --env _ -S server myfunc ::: work;
    echo "OK if   ^^^^^^^^^^^^^^^^^ no myecho" >&2;
    echo myfunc >> ~/.parallel/ignored_vars;
    env_parallel --env _ myfunc ::: work;
    echo "OK if   ^^^^^^^^^^^^^^^^^ no myfunc" >&2;
    env_parallel --env _ -S server myfunc ::: work;
    echo "OK if   ^^^^^^^^^^^^^^^^^ no myfunc" >&2;
_EOF
  )

  # Old versions of fish sometimes throw up bugs all over,
  # but seem to work OK otherwise. So ignore these errors.
  ssh fish@lo "$myscript" 2>&1 |
  perl -ne '/fish:|fish\(/ and next; print'
}

par_ksh_underscore() {
  echo '### ksh'
  myscript=$(cat <<'_EOF'
    echo "### Testing of --env _"

    alias not_copied_alias="echo BAD"
    not_copied_func() { echo BAD; };
    not_copied_var=BAD
    not_copied_array=(BAD BAD BAD);
    . `which env_parallel.ksh`;
    env_parallel --record-env;
    alias myecho="echo \$myvar aliases in";
    myfunc() { myecho ${myarray[@]} functions $*; };
    myvar="variables in";
    myarray=(and arrays in);
    env_parallel myfunc ::: work;
    env_parallel -S server myfunc ::: work;
    env_parallel --env myfunc,myvar,myarray,myecho myfunc ::: work;
    env_parallel --env myfunc,myvar,myarray,myecho -S server myfunc ::: work;
    env_parallel --env _ myfunc ::: work;
    env_parallel --env _ -S server myfunc ::: work;

    env_parallel --env _ -S server not_copied_alias ::: error=OK;
    env_parallel --env _ -S server not_copied_func ::: error=OK;
    env_parallel --env _ -S server echo \$not_copied_var ::: error=OK;
    env_parallel --env _ -S server echo \${not_copied_array[@]} ::: error=OK;

    echo myvar >> ~/.parallel/ignored_vars;
    env_parallel --env _ myfunc ::: work;
    env_parallel --env _ -S server myfunc ::: work;
    echo myarray >> ~/.parallel/ignored_vars;
    env_parallel --env _ myfunc ::: work;
    env_parallel --env _ -S server myfunc ::: work;
    echo myecho >> ~/.parallel/ignored_vars;
    env_parallel --env _ myfunc ::: work;
    echo "OK if no myecho    ^^^^^^^^^^^^^^^^^" >&2;
    env_parallel --env _ -S server myfunc ::: work;
    echo "OK if no myecho    ^^^^^^^^^^^^^^^^^" >&2;
    echo myfunc >> ~/.parallel/ignored_vars;
    env_parallel --env _ myfunc ::: work;
    echo "OK if no myfunc         ^^^^^^^^^^^^^^^^^" >&2;
    env_parallel --env _ -S server myfunc ::: work;
    echo "OK if no myfunc         ^^^^^^^^^^^^^^^^^" >&2;
_EOF
  )
  ssh ksh@lo "$myscript"
}

par_mksh_underscore() {
  echo '### mksh'
  myscript=$(cat <<'_EOF'
    echo "### Testing of --env _"

    alias not_copied_alias="echo BAD"
    not_copied_func() { echo BAD; };
    not_copied_var=BAD
    not_copied_array=(BAD BAD BAD);
    . `which env_parallel.mksh`;
    env_parallel --record-env;
    alias myecho="echo \$myvar aliases in";
    myfunc() { myecho ${myarray[@]} functions $*; };
    myvar="variables in";
    myarray=(and arrays in);
    env_parallel myfunc ::: work;
    env_parallel -S server myfunc ::: work;
    env_parallel --env myfunc,myvar,myarray,myecho myfunc ::: work;
    env_parallel --env myfunc,myvar,myarray,myecho -S server myfunc ::: work;
    env_parallel --env _ myfunc ::: work;
    env_parallel --env _ -S server myfunc ::: work;

    env_parallel --env _ -S server not_copied_alias ::: error=OK;
    env_parallel --env _ -S server not_copied_func ::: error=OK;
    env_parallel --env _ -S server echo \$not_copied_var ::: error=OK;
    env_parallel --env _ -S server echo \${not_copied_array[@]} ::: error=OK;

    echo myvar >> ~/.parallel/ignored_vars;
    env_parallel --env _ myfunc ::: work;
    env_parallel --env _ -S server myfunc ::: work;
    echo myarray >> ~/.parallel/ignored_vars;
    env_parallel --env _ myfunc ::: work;
    env_parallel --env _ -S server myfunc ::: work;
    echo myecho >> ~/.parallel/ignored_vars;
    env_parallel --env _ myfunc ::: work;
    echo "OK if no myecho    ^^^^^^^^^^^^^^^^^" >&2;
    env_parallel --env _ -S server myfunc ::: work;
    echo "OK if no myecho    ^^^^^^^^^^^^^^^^^" >&2;
    echo myfunc >> ~/.parallel/ignored_vars;
    env_parallel --env _ myfunc ::: work;
    echo "OK if no myfunc         ^^^^^^^^^^^^^^^^^" >&2;
    env_parallel --env _ -S server myfunc ::: work;
    echo "OK if no myfunc         ^^^^^^^^^^^^^^^^^" >&2;
_EOF
  )
  ssh mksh@lo "$myscript"
}

par_sh_underscore() {
  echo '### sh'
  myscript=$(cat <<'_EOF'
    echo "### Testing of --env _"

    alias not_copied_alias="echo BAD"
#    not_copied_func() { echo BAD; };
    not_copied_var=BAD
#    not_copied_array=(BAD BAD BAD);
    . `which env_parallel.sh`;
    env_parallel --record-env;
    alias myecho="echo \$myvar aliases";
#    myfunc() { myecho functions $*; };
    myvar="variables in";
#    myarray=(and arrays in);
#    env_parallel myfunc ::: work;
#    env_parallel -S server myfunc ::: work;
    env_parallel --env myvar,myecho myecho ::: work;
    env_parallel --env myvar,myecho -S server myecho ::: work;
    env_parallel --env _ myecho ::: work;
    env_parallel --env _ -S server myecho ::: work;

    env_parallel --env _ -S server not_copied_alias ::: error=OK;
#    env_parallel --env _ -S server not_copied_func ::: error=OK;
    env_parallel --env _ -S server echo \$not_copied_var ::: error=OK;
#    env_parallel --env _ -S server echo \${not_copied_array[@]} ::: error=OK;

    echo myvar >> ~/.parallel/ignored_vars;
    env_parallel --env _ myecho ::: work;
    env_parallel --env _ -S server myecho ::: work;
#    echo myarray >> ~/.parallel/ignored_vars;
#    env_parallel --env _ myfunc ::: work;
#    env_parallel --env _ -S server myfunc ::: work;
    echo myecho >> ~/.parallel/ignored_vars;
    env_parallel --env _ myecho ::: work;
    echo "OK if no myecho    ^^^^^^^^^^^^^^^^^" >&2;
    env_parallel --env _ -S server myecho ::: work;
    echo "OK if no myecho    ^^^^^^^^^^^^^^^^^" >&2;
#    echo myfunc >> ~/.parallel/ignored_vars;
#    env_parallel --env _ myfunc ::: work;
#    echo "OK if no myfunc         ^^^^^^^^^^^^^^^^^" >&2;
#    env_parallel --env _ -S server myfunc ::: work;
#    echo "OK if no myfunc         ^^^^^^^^^^^^^^^^^" >&2;
_EOF
  )
  ssh sh@lo "$myscript"
}

par_tcsh_underscore() {
  echo '### tcsh'
  myscript=$(cat <<'_EOF'
    echo "### Testing of --env _"

#    source `which env_parallel.tcsh`;

    env_parallel --record-env;
    alias myecho "echo "\$"myvar "\$'myarray'" aliases";
    set myvar="variables";
    set myarray=(and arrays in);
    env_parallel myecho ::: work;
    env_parallel -S server myecho ::: work;
    env_parallel --env myvar,myarray,myecho myecho ::: work;
    env_parallel --env myvar,myarray,myecho -S server myecho ::: work;
    env_parallel --env _ myecho ::: work;
    env_parallel --env _ -S server myecho ::: work;

    echo myvar >> ~/.parallel/ignored_vars;
    env_parallel --env _ myecho ::: work;
    env_parallel --env _ -S server myecho ::: work;
    alias myecho "echo "\$'myarray'" aliases";
    echo myarray >> ~/.parallel/ignored_vars;
    env_parallel --env _ myecho ::: work;
    env_parallel --env _ -S server myecho ::: work;
    echo myecho >> ~/.parallel/ignored_vars;
    env_parallel --env _ myecho ::: work;
    echo "OK      ^^^^^^^^^^^^^^^^^ if no myecho" >/dev/stderr;
    env_parallel --env _ -S server myecho ::: work;
    echo "OK      ^^^^^^^^^^^^^^^^^ if no myecho" >/dev/stderr;
_EOF
  )
  ssh -tt tcsh@lo "$myscript"
}

par_zsh_underscore() {
  echo '### zsh'
  myscript=$(cat <<'_EOF'
    echo "### Testing of --env _"

    . `which env_parallel.zsh`;

    alias not_copied_alias="echo BAD"
    not_copied_func() { echo BAD; };
    not_copied_var=BAD
    not_copied_array=(BAD BAD BAD);
    env_parallel --record-env;
    alias myecho="echo \$myvar aliases in";
    eval `cat <<"_EOS";
    myfunc() { myecho ${myarray[@]} functions $*; };
    myvar="variables in";
    myarray=(and arrays in);
    env_parallel myfunc ::: work;
    env_parallel -S server myfunc ::: work;
    env_parallel --env myfunc,myvar,myarray,myecho myfunc ::: work;
    env_parallel --env myfunc,myvar,myarray,myecho -S server myfunc ::: work;
    env_parallel --env _ myfunc ::: work;
    env_parallel --env _ -S server myfunc ::: work;

    env_parallel --env _ -S server not_copied_alias ::: error=OK;
    env_parallel --env _ -S server not_copied_func ::: error=OK;
    env_parallel --env _ -S server echo \$not_copied_var ::: error=OK;
    env_parallel --env _ -S server echo \$\{not_copied_array\[\@\]\} ::: error=OK;

    echo myvar >> ~/.parallel/ignored_vars;
    env_parallel --env _ myfunc ::: work;
    env_parallel --env _ -S server myfunc ::: work;
    echo myarray >> ~/.parallel/ignored_vars;
    env_parallel --env _ myfunc ::: work;
    env_parallel --env _ -S server myfunc ::: work;
    echo myecho >> ~/.parallel/ignored_vars;
    : Not using the function, because aliases are expanded in functions;
    env_parallel --env _ myecho ::: work;
    echo OK if no .^^^^^^^^^^^^^^^^^^^^^^^^^ myecho >&2;
    env_parallel --env _ -S server myecho ::: work;
    echo OK if no .^^^^^^^^^^^^^^^^^^^^^^^^^ myecho >&2;
    echo myfunc >> ~/.parallel/ignored_vars;
    env_parallel --env _ myfunc ::: work;
    echo OK if no .^^^^^^^^^^^^^^^^^^^^^^^^^ myfunc >&2;
    env_parallel --env _ -S server myfunc ::: work;
    echo OK if no .^^^^^^^^^^^^^^^^^^^^^^^^^ myfunc >&2;
_EOS`
_EOF
  )
  ssh zsh@lo "$myscript"
}


# Test env_parallel:
# + for each shell
# + remote, locally
# + variables, variables with funky content, arrays, assoc array, functions, aliases

par_ash_funky() {
  myscript=$(cat <<'_EOF'
    . `which env_parallel.ash`;

    myvar="myvar  works"
    funky=`perl -e "print pack \"c*\", 2..255"`
# Arrays not supported
#    myarray=("" array_val2 3 "" 5 "  space  6  ")
#    typeset -A assocarr
#    assocarr[a]=assoc_val_a
#    assocarr[b]=assoc_val_b
    alias alias_echo="echo 3 arg";

    func_echo() {
      echo $*;
      echo "$myvar"
#      echo "${myarray[5]}"
#      echo ${assocarr[a]}
      echo Funky-"$funky"-funky
    }

    env_parallel alias_echo ::: alias_works
#    env_parallel func_echo ::: function_works
    env_parallel -S ash@lo alias_echo ::: alias_works_over_ssh
#    env_parallel -S ash@lo func_echo ::: function_works_over_ssh
    echo
    echo "$funky" | parallel --shellquote
_EOF
  )
  # Order is often different. Dunno why. So sort
  ssh ash@lo "$myscript" 2>&1 | LC_ALL=C sort
}

par_bash_funky() {
  myscript=$(cat <<'_EOF'
    . `which env_parallel.bash`;

    myvar="myvar  works"
    funky_single_line=$(perl -e "print pack \"c*\", 13..126,128..255")
    funky_multi_line=$(perl -e "print pack \"c*\", 1..12,127")
    myarray=("" array_val2 3 "" 5 "  space  6  ")
    declare -A assocarr
    assocarr[a]=assoc_val_a
    assocarr[b]=assoc_val_b
    alias alias_echo="echo 3 arg";
    func_echo() {
      echo $*;
      echo "$myvar"
      echo "${myarray[5]}"
      echo ${assocarr[a]}
      echo Funkyline-"$funky_single_line"-funkyline
      echo Funkymultiline-"$funky_multi_line"-funkymultiline
    }
    env_parallel alias_echo ::: alias_works
    env_parallel func_echo ::: function_works
    env_parallel -S lo alias_echo ::: alias_works_over_ssh
    env_parallel -S lo func_echo ::: function_works_over_ssh
    echo
    echo "$funky_single_line" | parallel --shellquote
    echo "$funky_multi_line" | parallel --shellquote
_EOF
  )
  # Order is often different. Dunno why. So sort
  ssh bash@lo "$myscript" 2>&1 | LC_ALL=C sort
}

par_csh_funky() {
  myscript=$(cat <<'_EOF'
    set myvar = "myvar  works"
    set funky = "`perl -e 'print pack q(c*), 2..255'`"
    set myarray = ('' 'array_val2' '3' '' '5' '  space  6  ')
    #declare -A assocarr
    #assocarr[a]=assoc_val_a
    #assocarr[b]=assoc_val_b
    alias alias_echo echo 3 arg;
    alias alias_echo_var 'echo $argv; echo "$myvar"; echo "${myarray[4]} special chars problem"; echo Funky-"$funky"-funky'

    #function func_echo
    #  echo $argv;
    #  echo $myvar;
    #  echo ${myarray[2]}
    #  #echo ${assocarr[a]}
    #  echo Funky-"$funky"-funky
    #end

    env_parallel alias_echo ::: alias_works
    env_parallel alias_echo_var ::: alias_var_works
    env_parallel func_echo ::: function_does_not_work
    env_parallel -S csh@lo alias_echo ::: alias_works_over_ssh
    env_parallel -S csh@lo alias_echo_var ::: alias_var_works_over_ssh
    env_parallel -S csh@lo func_echo ::: function_does_not_work_over_ssh
    echo
    echo "$funky" | parallel --shellquote
_EOF
  )
  ssh csh@lo "$myscript"
}

par_dash_funky() {
  myscript=$(cat <<'_EOF'
    . `which env_parallel.dash`;

    myvar="myvar  works"
    funky=`perl -e "print pack \"c*\", 2..255"`
# Arrays not supported
#    myarray=("" array_val2 3 "" 5 "  space  6  ")
#    typeset -A assocarr
#    assocarr[a]=assoc_val_a
#    assocarr[b]=assoc_val_b
    alias alias_echo="echo 3 arg";

    func_echo() {
      echo $*;
      echo "$myvar"
#      echo "${myarray[5]}"
#      echo ${assocarr[a]}
      echo Funky-"$funky"-funky
    }

    env_parallel alias_echo ::: alias_works
#    env_parallel func_echo ::: function_works
    env_parallel -S dash@lo alias_echo ::: alias_works_over_ssh
#    env_parallel -S dash@lo func_echo ::: function_works_over_ssh
    echo
    echo "$funky" | parallel --shellquote
_EOF
  )
  # Order is often different. Dunno why. So sort
  ssh dash@lo "$myscript" 2>&1 | LC_ALL=C sort
}

par_fish_funky() {
  myscript=$(cat <<'_EOF'
    env_parallel --session
    set myvar "myvar  works"
    setenv myenvvar "myenvvar  works"

    set funky (perl -e "print pack \"c*\", 1..255")
    # 10 and 30 cause problems
    setenv funkyenv (perl -e "print pack \"c*\", 1..9,11..29,31..255")

    set myarray "" array_val2 3 "" 5 "  space  6  "

    # Assoc arrays do not exist
    #typeset -A assocarr
    #assocarr[a]=assoc_val_a
    #assocarr[b]=assoc_val_b
    alias alias_echo="echo 3 arg";

    function func_echo
      echo $argv;
      echo "$myvar"
      echo "$myenvvar"
      echo "$myarray[6]"
    # Assoc arrays do not exist in fish
    #  echo ${assocarr[a]}
      echo
      echo
      echo
      echo Funky-"$funky"-funky
      echo Funkyenv-"$funkyenv"-funkyenv
      echo
      echo
      echo
    end

    env_parallel alias_echo ::: alias_works
    env_parallel func_echo ::: function_works
    env_parallel -S fish@lo alias_echo ::: alias_works_over_ssh
    env_parallel -S fish@lo func_echo ::: function_works_over_ssh
    echo
    echo "$funky" | parallel --shellquote
_EOF
  )
  ssh fish@lo "$myscript"
}

par_ksh_funky() {
  myscript=$(cat <<'_EOF'
    . `which env_parallel.ksh`;

    myvar="myvar  works"
    funky=$(perl -e "print pack \"c*\", 1..255")
    myarray=("" array_val2 3 "" 5 "  space  6  ")
    typeset -A assocarr
    assocarr[a]=assoc_val_a
    assocarr[b]=assoc_val_b
    alias alias_echo="echo 3 arg";

    func_echo() {
      echo $*;
      echo "$myvar"
      echo "${myarray[5]}"
      echo ${assocarr[a]}
      echo Funky-"$funky"-funky
    }

    env_parallel alias_echo ::: alias_works
    env_parallel func_echo ::: function_works
    env_parallel -S ksh@lo alias_echo ::: alias_works_over_ssh
    env_parallel -S ksh@lo func_echo ::: function_works_over_ssh
    echo
    echo "$funky" | parallel --shellquote
_EOF
  )
  # Order is often different. Dunno why. So sort
  ssh ksh@lo "$myscript" 2>&1 | LC_ALL=C sort
}

par_mksh_funky() {
  myscript=$(cat <<'_EOF'
    . `which env_parallel.mksh`;

    myvar="myvar  works"
    funky=$(perl -e "print pack \"c*\", 1..255")
    myarray=("" array_val2 3 "" 5 "  space  6  ")
# Assoc arrays not supported
#    typeset -A assocarr
#    assocarr[a]=assoc_val_a
#    assocarr[b]=assoc_val_b
    alias alias_echo="echo 3 arg";

    func_echo() {
      echo $*;
      echo "$myvar"
      echo "${myarray[5]}"
#      echo ${assocarr[a]}
      echo Funky-"$funky"-funky
    }

    env_parallel alias_echo ::: alias_works
    env_parallel func_echo ::: function_works
    env_parallel -S mksh@lo alias_echo ::: alias_works_over_ssh
    env_parallel -S mksh@lo func_echo ::: function_works_over_ssh
    echo
    echo "$funky" | parallel --shellquote
_EOF
  )
  # Order is often different. Dunno why. So sort
  ssh mksh@lo "$myscript" 2>&1 | LC_ALL=C sort
}

par_sh_funky() {
  myscript=$(cat <<'_EOF'
    . `which env_parallel.sh`;

    myvar="myvar  works"
    funky=`perl -e "print pack \"c*\", 2..255"`
# Arrays not supported
#    myarray=("" array_val2 3 "" 5 "  space  6  ")
#    typeset -A assocarr
#    assocarr[a]=assoc_val_a
#    assocarr[b]=assoc_val_b
    alias alias_echo="echo 3 arg";

    func_echo() {
      echo $*;
      echo "$myvar"
#      echo "${myarray[5]}"
#      echo ${assocarr[a]}
      echo Funky-"$funky"-funky
    }

    env_parallel alias_echo ::: alias_works
#    env_parallel func_echo ::: function_works
    env_parallel -S sh@lo alias_echo ::: alias_works_over_ssh
#    env_parallel -S sh@lo func_echo ::: function_works_over_ssh
    echo
    echo "$funky" | parallel --shellquote
_EOF
  )
  # Order is often different. Dunno why. So sort
  ssh sh@lo "$myscript" 2>&1 | LC_ALL=C sort
}

par_tcsh_funky() {
  myscript=$(cat <<'_EOF'
    # funky breaks with different LC_ALL
    setenv LC_ALL C
    set myvar = "myvar  works"
    set funky = "`perl -e 'print pack q(c*), 2..255'`"
    set myarray = ('' 'array_val2' '3' '' '5' '  space  6  ')
    # declare -A assocarr
    # assocarr[a]=assoc_val_a
    # assocarr[b]=assoc_val_b
    alias alias_echo echo 3 arg;
    alias alias_echo_var 'echo $argv; echo "$myvar"; echo "${myarray[4]} special chars problem"; echo Funky-"$funky"-funky'

    # function func_echo
    #  echo $argv;
    #  echo $myvar;
    #  echo ${myarray[2]}
    #  #echo ${assocarr[a]}
    #  echo Funky-"$funky"-funky
    # end

    env_parallel alias_echo ::: alias_works
    env_parallel alias_echo_var ::: alias_var_works
    env_parallel func_echo ::: function_does_not_work
    env_parallel -S tcsh@lo alias_echo ::: alias_works_over_ssh
    env_parallel -S tcsh@lo alias_echo_var ::: alias_var_works_over_ssh
    env_parallel -S tcsh@lo func_echo ::: function_does_not_work_over_ssh
    echo
    echo "$funky" | parallel --shellquote
_EOF
  )
  # Order is often different. Dunno why. So sort
  ssh tcsh@lo "$myscript" 2>&1 | LC_ALL=C sort
}

par_zsh_funky() {
  myscript=$(cat <<'_EOF'

    . `which env_parallel.zsh`;

    myvar="myvar  works"
    # Zsh-5.4.2 fails for ascii 167
    funky=$(perl -e "print pack \"c*\", 1..166,168..255")
    myarray=("" array_val2 3 "" 5 "  space  6  ")
    declare -A assocarr
    assocarr[a]=assoc_val_a
    assocarr[b]=assoc_val_b
    alias alias_echo="echo 3 arg";
    func_echo() {
      echo $*;
      echo "$myvar"
      echo "$myarray[6]"
      echo ${assocarr[a]}
      echo Funky-"$funky"-funky
    }
    env_parallel alias_echo ::: alias_works
    env_parallel func_echo ::: function_works
    env_parallel -S zsh@lo alias_echo ::: alias_works_over_ssh
    env_parallel -S zsh@lo func_echo ::: function_works_over_ssh
    echo
    echo "$funky" | parallel --shellquote
_EOF
  )
  # Order is often different. Dunno why. So sort
  ssh zsh@lo "$myscript" 2>&1 | LC_ALL=C sort
}

par_ash_env_parallel() {
  myscript=$(cat <<'_EOF'
    . `which env_parallel.ash`;
    echo 'bug #50435: Remote fifo broke in 20150522'
    # Due to $PARALLEL_TMP being transferred
    OK=OK
    echo data from stdin | env_parallel --pipe -S lo --fifo 'cat {} && echo $OK'
    echo data from stdin | env_parallel --pipe -S lo --cat 'cat {} && echo $OK'

    echo 'bug #52534: Tail of multiline alias is ignored'
    alias myalias='echo alias line 1
      echo alias line 2
      echo alias line 3
    '
    alias myalias2='echo alias2 line 1
      echo alias2 line 2
    '
    env_parallel myalias ::: myalias2
    env_parallel -S lo myalias ::: myalias2
_EOF
  )
  # Order is often different. Dunno why. So sort
  ssh ash@lo "$myscript" 2>&1 | LC_ALL=C sort
}

par_bash_env_parallel() {
  myscript=$(cat <<'_EOF'
    echo 'bug #50435: Remote fifo broke in 20150522'
    # Due to $PARALLEL_TMP being transferred
    . `which env_parallel.bash`
    OK=OK
    echo data from stdin | env_parallel --pipe -S lo --fifo 'cat {} && echo $OK'
    echo data from stdin | env_parallel --pipe -S lo --cat 'cat {} && echo $OK'

    echo 'bug #52534: Tail of multiline alias is ignored'
    alias myalias='echo alias line 1
      echo alias line 2
      echo alias line 3
    '
    alias myalias2='echo alias2 line 1
      echo alias2 line 2
    '
    env_parallel myalias ::: myalias2
    env_parallel -S lo myalias ::: myalias2
_EOF
  )
  # Order is often different. Dunno why. So sort
  ssh bash@lo "$myscript" 2>&1 | LC_ALL=C sort
}

par_csh_env_parallel() {
  myscript=$(cat <<'_EOF'
    echo 'bug #50435: Remote fifo broke in 20150522'
    # Due to $PARALLEL_TMP being transferred
    set OK=OK
    echo data from stdin | env_parallel --pipe -S lo --fifo 'cat {} && echo $OK'
    echo data from stdin | env_parallel --pipe -S lo --cat 'cat {} && echo $OK'
_EOF
  )
  ssh csh@lo "$myscript"
}

par_dash_env_parallel() {
  myscript=$(cat <<'_EOF'
    . `which env_parallel.dash`;
    echo 'bug #50435: Remote fifo broke in 20150522'
    # Due to $PARALLEL_TMP being transferred
    OK=OK
    echo data from stdin | env_parallel --pipe -S lo --fifo 'cat {} && echo $OK'
    echo data from stdin | env_parallel --pipe -S lo --cat 'cat {} && echo $OK'

    echo 'bug #52534: Tail of multiline alias is ignored'
    alias myalias='echo alias line 1
      echo alias line 2
      echo alias line 3
    '
    alias myalias2='echo alias2 line 1
      echo alias2 line 2
    '
    env_parallel myalias ::: myalias2
    env_parallel -S lo myalias ::: myalias2
_EOF
  )
  # Order is often different. Dunno why. So sort
  ssh dash@lo "$myscript" 2>&1 | LC_ALL=C sort
}

par_fish_env_parallel() {
  myscript=$(cat <<'_EOF'
    echo 'bug #50435: Remote fifo broke in 20150522'
    # Due to $PARALLEL_TMP being transferred
    env_parallel --session
    set OK OK
    echo data from stdin | env_parallel --pipe -S lo --fifo 'cat {}; and echo $OK'
    echo data from stdin | env_parallel --pipe -S lo --cat 'cat {}; and echo $OK'
_EOF
  )
  ssh fish@lo "$myscript"
}

par_ksh_env_parallel() {
  myscript=$(cat <<'_EOF'
    . `which env_parallel.ksh`;
    echo 'bug #50435: Remote fifo broke in 20150522'
    # Due to $PARALLEL_TMP being transferred
    OK=OK
    echo data from stdin | env_parallel --pipe -S lo --fifo 'cat {} && echo $OK'
    echo data from stdin | env_parallel --pipe -S lo --cat 'cat {} && echo $OK'

    echo 'bug #52534: Tail of multiline alias is ignored'
    alias myalias='echo alias line 1
      echo alias line 2
      echo alias line 3
    '
    alias myalias2='echo alias2 line 1
      echo alias2 line 2
    '
    env_parallel myalias ::: myalias2
    env_parallel -S lo myalias ::: myalias2
_EOF
  )
  # Order is often different. Dunno why. So sort
  ssh ksh@lo "$myscript" 2>&1 | LC_ALL=C sort
}

par_mksh_env_parallel() {
  myscript=$(cat <<'_EOF'
    . `which env_parallel.mksh`;
    echo 'bug #50435: Remote fifo broke in 20150522'
    # Due to $PARALLEL_TMP being transferred
    OK=OK
    echo data from stdin | env_parallel --pipe -S lo --fifo 'cat {} && echo $OK'
    echo data from stdin | env_parallel --pipe -S lo --cat 'cat {} && echo $OK'

    echo 'bug #52534: Tail of multiline alias is ignored'
    alias myalias='echo alias line 1
      echo alias line 2
      echo alias line 3
    '
    alias myalias2='echo alias2 line 1
      echo alias2 line 2
    '
    env_parallel myalias ::: myalias2
    env_parallel -S lo myalias ::: myalias2
_EOF
  )
  # Order is often different. Dunno why. So sort
  ssh mksh@lo "$myscript" 2>&1 | LC_ALL=C sort
}

par_sh_env_parallel() {
  myscript=$(cat <<'_EOF'
    . `which env_parallel.sh`;
    echo 'bug #50435: Remote fifo broke in 20150522'
    # Due to $PARALLEL_TMP being transferred
    OK=OK
    echo data from stdin | env_parallel --pipe -S lo --fifo 'cat {} && echo $OK'
    echo data from stdin | env_parallel --pipe -S lo --cat 'cat {} && echo $OK'

    echo 'bug #52534: Tail of multiline alias is ignored'
    alias myalias='echo alias line 1
      echo alias line 2
      echo alias line 3
    '
    alias myalias2='echo alias2 line 1
      echo alias2 line 2
    '
    env_parallel myalias ::: myalias2
    env_parallel -S lo myalias ::: myalias2
_EOF
  )
  # Order is often different. Dunno why. So sort
  ssh sh@lo "$myscript" 2>&1 | LC_ALL=C sort
}

par_tcsh_env_parallel() {
  myscript=$(cat <<'_EOF'
    echo 'bug #50435: Remote fifo broke in 20150522'
    # Due to $PARALLEL_TMP being transferred
    set OK=OK
    echo data from stdin | env_parallel --pipe -S lo --fifo 'cat {} && echo $OK'
    echo data from stdin | env_parallel --pipe -S lo --cat 'cat {} && echo $OK'
_EOF
  )
  # Order is often different. Dunno why. So sort
  ssh tcsh@lo "$myscript" 2>&1 | LC_ALL=C sort
}

par_zsh_env_parallel() {
  myscript=$(cat <<'_EOF'
    echo 'bug #50435: Remote fifo broke in 20150522'
    # Due to $PARALLEL_TMP being transferred
    OK=OK
    echo data from stdin | env_parallel --pipe -S lo --fifo 'cat {} && echo $OK'
    echo data from stdin | env_parallel --pipe -S lo --cat 'cat {} && echo $OK'

    echo 'bug #52534: Tail of multiline alias is ignored'
    alias myalias='echo alias line 1
      echo alias line 2
      echo alias line 3
    '
    alias myalias2='echo alias2 line 1
      echo alias2 line 2
    '
    env_parallel myalias ::: myalias2
    env_parallel -S lo myalias ::: myalias2
_EOF
  )
  # Order is often different. Dunno why. So sort
  ssh zsh@lo "$myscript" 2>&1 | LC_ALL=C sort
}

par_ash_environment_too_big() {
  myscript=$(cat <<'_EOF'
    echo 'bug #50815: env_parallel should warn if the environment is too big'
    len_var=100+50-25
    len_var_remote=100-50+25+12+6+3
    len_var_quote=100-50+25-12-6+3-2
    len_var_quote_remote=100-50-25+12+6-3
    len_fun=100+50+25+12+6-3
    len_fun_remote=100-50+25+12-6+3
    len_fun_quote=100+50-25-12
    len_fun_quote_remote=100-50+25+12-6
    
    . `which env_parallel.ash`;

    repeat() {
      # Repeat input string n*1000 times
      perl -e 'print ((shift)x(eval "1000*(".shift.")"))' "$@"
    }

    bigvar=$(repeat x $len_var)
    env_parallel echo ::: OK_bigvar
    bigvar=$(repeat x $len_var_remote)
    env_parallel -S lo echo ::: OK_bigvar_remote

    bigvar=$(repeat \" $len_var_quote)
    env_parallel echo ::: OK_bigvar_quote
    bigvar=$(repeat \" $len_var_quote_remote)
    env_parallel -S lo echo ::: OK_bigvar_quote_remote

    bigvar=u
    eval 'bigfunc() { a="'"$(repeat x $len_fun)"'"; };'
    env_parallel echo ::: OK_bigfunc
    eval 'bigfunc() { a="'"$(repeat x $len_fun_remote)"'"; };'
    env_parallel -S lo echo ::: OK_bigfunc_remote

    eval 'bigfunc() { a="'"$(repeat \" $len_fun_quote)"'"; };'
    env_parallel echo ::: OK_bigfunc_quote
    eval 'bigfunc() { a="'"$(repeat \" $len_fun_quote_remote)"'"; };'
    env_parallel -S lo echo ::: OK_bigfunc_quote_remote
    bigfunc() { true; }

    echo Rest should fail - functions not supported in ash

    bigvar=$(repeat x $len_var+10)
    env_parallel echo ::: fail_bigvar
    bigvar=$(repeat x $len_var_remote+10)
    env_parallel -S lo echo ::: fail_bigvar_remote

    bigvar=$(repeat \" $len_var_quote+10)
    env_parallel echo ::: fail_bigvar_quote
    bigvar=$(repeat \" $len_var_quote_remote+10)
    env_parallel -S lo echo ::: fail_bigvar_quote_remote

    bigvar=u
    eval 'bigfunc() { a="'"$(repeat x $len_fun+10)"'"; };'
    env_parallel echo ::: fail_bigfunc-not-supported
    eval 'bigfunc() { a="'"$(repeat x $len_fun_remote+10)"'"; };'
    env_parallel -S lo echo ::: fail_bigfunc_remote-not-supported

    eval 'bigfunc() { a="'"$(repeat \" $len_fun_quote+10)"'"; };'
    env_parallel echo ::: fail_bigfunc_quote-not-supported
    eval 'bigfunc() { a="'"$(repeat \" $len_fun_quote+10)"'"; };'
    env_parallel -S lo echo ::: fail_bigfunc_quote_remote-not-supported

    bigfunc() { true; }
_EOF
  )
  ssh ash@lo "$myscript"
}

par_bash_environment_too_big() {
  myscript=$(cat <<'_EOF'
    echo 'bug #50815: env_parallel should warn if the environment is too big'
    len_functions=-$(typeset -f | wc -c)/1000
    len_variables=-$(typeset -p | wc -c)/1000
    len_var=$len_variables+110
    len_var_remote=$len_variables+100-50+25-12+6
    len_var_quote=$len_variables+100-50
    len_var_quote_remote=$len_variables+100-50-25+12
    len_fun=$len_functions+100
    len_fun_remote=$len_functions+100-50+25-12+6
    len_fun_quote=$len_functions+100
    len_fun_quote_remote=$len_functions+100-50
    
    . `which env_parallel.bash`;

    repeat() {
      # Repeat input string n*1000 times
      perl -e 'print ((shift)x(eval "1000*(".shift.")"))' "$@"
    }

    bigvar=$(repeat x $len_var)
    env_parallel echo ::: OK_bigvar
    bigvar=$(repeat x $len_var_remote)
    env_parallel -S lo echo ::: OK_bigvar_remote

    bigvar=$(repeat \" $len_var_quote)
    env_parallel echo ::: OK_bigvar_quote
    bigvar=$(repeat \" $len_var_quote_remote)
    env_parallel -S lo echo ::: OK_bigvar_quote_remote

    bigvar=u
    eval 'bigfunc() { a="'"$(repeat x $len_fun)"'"; };'
    env_parallel echo ::: OK_bigfunc
    eval 'bigfunc() { a="'"$(repeat x $len_fun_remote)"'"; };'
    env_parallel -S lo echo ::: OK_bigfunc_remote

    eval 'bigfunc() { a="'"$(repeat \" $len_fun_quote)"'"; };'
    env_parallel echo ::: OK_bigfunc_quote
    eval 'bigfunc() { a="'"$(repeat \" $len_fun_quote_remote)"'"; };'
    env_parallel -S lo echo ::: OK_bigfunc_quote_remote
    bigfunc() { true; }

    echo Rest should fail

    bigvar=$(repeat x $len_var+20)
    env_parallel echo ::: fail_bigvar
    bigvar=$(repeat x $len_var_remote+20)
    env_parallel -S lo echo ::: fail_bigvar_remote

    bigvar=$(repeat \" $len_var_quote+20)
    env_parallel echo ::: fail_bigvar_quote
    bigvar=$(repeat \" $len_var_quote_remote+20)
    env_parallel -S lo echo ::: fail_bigvar_quote_remote

    bigvar=u
    eval 'bigfunc() { a="'"$(repeat x $len_fun+20)"'"; };'
    env_parallel echo ::: fail_bigfunc
    eval 'bigfunc() { a="'"$(repeat x $len_fun_remote+20)"'"; };'
    env_parallel -S lo echo ::: fail_bigfunc_remote

    eval 'bigfunc() { a="'"$(repeat \" $len_fun_quote+20)"'"; };'
    env_parallel echo ::: fail_bigfunc_quote
    eval 'bigfunc() { a="'"$(repeat \" $len_fun_quote+20)"'"; };'
    env_parallel -S lo echo ::: fail_bigfunc_quote_remote

    bigfunc() { true; }
_EOF
  )
  ssh bash@lo "$myscript"
}

par_csh_environment_too_big() {
    echo Not implemented
}

par_dash_environment_too_big() {
  myscript=$(cat <<'_EOF'
    echo 'bug #50815: env_parallel should warn if the environment is too big'
    len_var=100+50-25
    len_var_remote=100-50+25+12+6+3
    len_var_quote=100-50+25-12-6+3-2
    len_var_quote_remote=100-50-25+12+6-3
    len_fun=100+50+25+12+6-3
    len_fun_remote=100-50+25+12-6+3
    len_fun_quote=100+50-25-12
    len_fun_quote_remote=100-50+25+12-6
    
    . `which env_parallel.dash`;

    repeat() {
      # Repeat input string n*1000 times
      perl -e 'print ((shift)x(eval "1000*(".shift.")"))' "$@"
    }

    bigvar=$(repeat x $len_var)
    env_parallel echo ::: OK_bigvar
    bigvar=$(repeat x $len_var_remote)
    env_parallel -S lo echo ::: OK_bigvar_remote

    bigvar=$(repeat \" $len_var_quote)
    env_parallel echo ::: OK_bigvar_quote
    bigvar=$(repeat \" $len_var_quote_remote)
    env_parallel -S lo echo ::: OK_bigvar_quote_remote

    bigvar=u
    eval 'bigfunc() { a="'"$(repeat x $len_fun)"'"; };'
    env_parallel echo ::: OK_bigfunc
    eval 'bigfunc() { a="'"$(repeat x $len_fun_remote)"'"; };'
    env_parallel -S lo echo ::: OK_bigfunc_remote

    eval 'bigfunc() { a="'"$(repeat \" $len_fun_quote)"'"; };'
    env_parallel echo ::: OK_bigfunc_quote
    eval 'bigfunc() { a="'"$(repeat \" $len_fun_quote_remote)"'"; };'
    env_parallel -S lo echo ::: OK_bigfunc_quote_remote
    bigfunc() { true; }

    echo Rest should fail - functions not supported in dash

    bigvar=$(repeat x $len_var+10)
    env_parallel echo ::: fail_bigvar
    bigvar=$(repeat x $len_var_remote+10)
    env_parallel -S lo echo ::: fail_bigvar_remote

    bigvar=$(repeat \" $len_var_quote+10)
    env_parallel echo ::: fail_bigvar_quote
    bigvar=$(repeat \" $len_var_quote_remote+10)
    env_parallel -S lo echo ::: fail_bigvar_quote_remote

    bigvar=u
    eval 'bigfunc() { a="'"$(repeat x $len_fun+10)"'"; };'
    env_parallel echo ::: fail_bigfunc-not-supported
    eval 'bigfunc() { a="'"$(repeat x $len_fun_remote+10)"'"; };'
    env_parallel -S lo echo ::: fail_bigfunc_remote-not-supported

    eval 'bigfunc() { a="'"$(repeat \" $len_fun_quote+10)"'"; };'
    env_parallel echo ::: fail_bigfunc_quote-not-supported
    eval 'bigfunc() { a="'"$(repeat \" $len_fun_quote+10)"'"; };'
    env_parallel -S lo echo ::: fail_bigfunc_quote_remote-not-supported

    bigfunc() { true; }
_EOF
  )
  ssh dash@lo "$myscript"
}

par_fish_environment_too_big() {
    echo Not implemented
}


par_ksh_environment_too_big() {
  myscript=$(cat <<'_EOF'
    echo 'bug #50815: env_parallel should warn if the environment is too big'
    len_functions=-$(functions|wc -c)/1000
    len_variables=-$(typeset -p | wc -c)/1000
    len_var=$len_variables+100
    len_var_remote=$len_variables+100-50+25-12+6
    len_var_quote=$len_variables+100
    len_var_quote_remote=$len_variables+100-50+25
    len_fun=$len_functions+100
    len_fun_remote=$len_functions+100-50+25-12+6
    len_fun_quote=$len_functions+100
    len_fun_quote_remote=$len_functions+100-50
    
    . `which env_parallel.ksh`;

    repeat() {
      # Repeat input string n*1000 times
      perl -e 'print ((shift)x(eval "1000*(".shift.")"))' "$@"
    }

    bigvar=$(repeat x $len_var)
    env_parallel echo ::: OK_bigvar
    bigvar=$(repeat x $len_var_remote)
    env_parallel -S lo echo ::: OK_bigvar_remote

    bigvar=$(repeat \" $len_var_quote)
    env_parallel echo ::: OK_bigvar_quote
    bigvar=$(repeat \" $len_var_quote_remote)
    env_parallel -S lo echo ::: OK_bigvar_quote_remote

    bigvar=u
    eval 'bigfunc() { a="'"$(repeat x $len_fun)"'"; };'
    env_parallel echo ::: OK_bigfunc
    eval 'bigfunc() { a="'"$(repeat x $len_fun_remote)"'"; };'
    env_parallel -S lo echo ::: OK_bigfunc_remote

    eval 'bigfunc() { a="'"$(repeat \" $len_fun_quote)"'"; };'
    env_parallel echo ::: OK_bigfunc_quote
    eval 'bigfunc() { a="'"$(repeat \" $len_fun_quote_remote)"'"; };'
    env_parallel -S lo echo ::: OK_bigfunc_quote_remote
    bigfunc() { true; }

    echo Rest should fail

    bigvar=$(repeat x $len_var+20)
    env_parallel echo ::: fail_bigvar
    bigvar=$(repeat x $len_var_remote+20)
    env_parallel -S lo echo ::: fail_bigvar_remote

    bigvar=$(repeat \" $len_var_quote+20)
    env_parallel echo ::: fail_bigvar_quote
    bigvar=$(repeat \" $len_var_quote_remote+20)
    env_parallel -S lo echo ::: fail_bigvar_quote_remote

    bigvar=u
    eval 'bigfunc() { a="'"$(repeat x $len_fun+20)"'"; };'
    env_parallel echo ::: fail_bigfunc
    eval 'bigfunc() { a="'"$(repeat x $len_fun_remote+20)"'"; };'
    env_parallel -S lo echo ::: fail_bigfunc_remote

    eval 'bigfunc() { a="'"$(repeat \" $len_fun_quote+20)"'"; };'
    env_parallel echo ::: fail_bigfunc_quote
    eval 'bigfunc() { a="'"$(repeat \" $len_fun_quote+20)"'"; };'
    env_parallel -S lo echo ::: fail_bigfunc_quote_remote

    bigfunc() { true; }
_EOF
  )
  ssh ksh@lo "$myscript"
}

par_mksh_environment_too_big() {
  myscript=$(cat <<'_EOF'
    echo 'bug #50815: env_parallel should warn if the environment is too big'
    len_var=100+6
    len_var_remote=100-50+25+12-6-3
    len_var_quote=100+6
    len_var_quote_remote=100-50+25
    len_fun=100+6
    len_fun_remote=100-50+25-6+3
    len_fun_quote=100+6
    len_fun_quote_remote=100-50+25
    
    . `which env_parallel.mksh`;

    repeat() {
      # Repeat input string n*1000 times
      perl -e 'print ((shift)x(eval "1000*(".shift.")"))' "$@"
    }

    bigvar=$(repeat x $len_var)
    env_parallel echo ::: OK_bigvar
    bigvar=$(repeat x $len_var_remote)
    env_parallel -S lo echo ::: OK_bigvar_remote

    bigvar=$(repeat \" $len_var_quote)
    env_parallel echo ::: OK_bigvar_quote
    bigvar=$(repeat \" $len_var_quote_remote)
    env_parallel -S lo echo ::: OK_bigvar_quote_remote

    bigvar=u
    eval 'bigfunc() { a="'"$(repeat x $len_fun)"'"; };'
    env_parallel echo ::: OK_bigfunc
    eval 'bigfunc() { a="'"$(repeat x $len_fun_remote)"'"; };'
    env_parallel -S lo echo ::: OK_bigfunc_remote

    eval 'bigfunc() { a="'"$(repeat \" $len_fun_quote)"'"; };'
    env_parallel echo ::: OK_bigfunc_quote
    eval 'bigfunc() { a="'"$(repeat \" $len_fun_quote_remote)"'"; };'
    env_parallel -S lo echo ::: OK_bigfunc_quote_remote
    bigfunc() { true; }

    echo Rest should fail

    # Add 10 or 100. It differs a bit from system to system
    bigvar=$(repeat x $len_var+20)
    env_parallel echo ::: fail_bigvar
    bigvar=$(repeat x $len_var_remote+10)
    env_parallel -S lo echo ::: fail_bigvar_remote

    bigvar=$(repeat \" $len_var_quote+20)
    env_parallel echo ::: fail_bigvar_quote
    bigvar=$(repeat \" $len_var_quote_remote+20)
    env_parallel -S lo echo ::: fail_bigvar_quote_remote

    bigvar=u
    eval 'bigfunc() { a="'"$(repeat x $len_fun+20)"'"; };'
    env_parallel echo ::: fail_bigfunc
    eval 'bigfunc() { a="'"$(repeat x $len_fun_remote+20)"'"; };'
    env_parallel -S lo echo ::: fail_bigfunc_remote

    eval 'bigfunc() { a="'"$(repeat \" $len_fun_quote+20)"'"; };'
    env_parallel echo ::: fail_bigfunc_quote
    eval 'bigfunc() { a="'"$(repeat \" $len_fun_quote+10)"'"; };'
    env_parallel -S lo echo ::: fail_bigfunc_quote_remote

    bigfunc() { true; }
_EOF
  )
  ssh mksh@lo "$myscript"
}

par_sh_environment_too_big() {
  myscript=$(cat <<'_EOF'
    echo 'bug #50815: env_parallel should warn if the environment is too big'
    len_var=100+50-25
    len_var_remote=100-12
    len_var_quote=100-50+6
    len_var_quote_remote=100-50-6
    len_fun=100+25
    len_fun_remote=100-50+25-6+3+10
    len_fun_quote=100+6+10
    len_fun_quote_remote=100-50+25+12-6
    
    . `which env_parallel.sh`;

    repeat() {
      # Repeat input string n*1000 times
      perl -e 'print ((shift)x(eval "1000*(".shift.")"))' "$@"
    }

    bigvar=$(repeat x $len_var)
    env_parallel echo ::: OK_bigvar
    bigvar=$(repeat x $len_var_remote)
    env_parallel -S lo echo ::: OK_bigvar_remote

    bigvar=$(repeat \" $len_var_quote)
    env_parallel echo ::: OK_bigvar_quote
    bigvar=$(repeat \" $len_var_quote_remote)
    env_parallel -S lo echo ::: OK_bigvar_quote_remote

    bigvar=u
    eval 'bigfunc() { a="'"$(repeat x $len_fun)"'"; };'
    env_parallel echo ::: OK_bigfunc
    eval 'bigfunc() { a="'"$(repeat x $len_fun_remote)"'"; };'
    env_parallel -S lo echo ::: OK_bigfunc_remote

    eval 'bigfunc() { a="'"$(repeat \" $len_fun_quote)"'"; };'
    env_parallel echo ::: OK_bigfunc_quote
    eval 'bigfunc() { a="'"$(repeat \" $len_fun_quote_remote)"'"; };'
    env_parallel -S lo echo ::: OK_bigfunc_quote_remote
    bigfunc() { true; }

    echo Rest should fail - functions not supported in sh

    bigvar=$(repeat x $len_var+10)
    env_parallel echo ::: fail_bigvar
    bigvar=$(repeat x $len_var_remote+10)
    env_parallel -S lo echo ::: fail_bigvar_remote

    bigvar=$(repeat \" $len_var_quote+10)
    env_parallel echo ::: fail_bigvar_quote
    bigvar=$(repeat \" $len_var_quote_remote+10)
    env_parallel -S lo echo ::: fail_bigvar_quote_remote

    bigvar=u
    eval 'bigfunc() { a="'"$(repeat x $len_fun+10)"'"; };'
    env_parallel echo ::: fail_bigfunc-not-supported
    eval 'bigfunc() { a="'"$(repeat x $len_fun_remote+10)"'"; };'
    env_parallel -S lo echo ::: fail_bigfunc_remote-not-supported

    eval 'bigfunc() { a="'"$(repeat \" $len_fun_quote+10)"'"; };'
    env_parallel echo ::: fail_bigfunc_quote-not-supported
    eval 'bigfunc() { a="'"$(repeat \" $len_fun_quote+10)"'"; };'
    env_parallel -S lo echo ::: fail_bigfunc_quote_remote-not-supported

    bigfunc() { true; }
_EOF
  )
  ssh sh@lo "$myscript"
}

par_tcsh_environment_too_big() {
    echo Not implemented
}

par_zsh_environment_too_big() {
  myscript=$(cat <<'_EOF'
    echo 'bug #50815: env_parallel should warn if the environment is too big'
    . `which env_parallel.zsh`;

    bigvar="$(perl -e 'print "x"x24000')"
    env_parallel echo ::: OK_bigvar
    bigvar="$(perl -e 'print "x"x12000')"
    env_parallel -S lo echo ::: OK_bigvar_remote

    bigvar="$(perl -e 'print "\""x24000')"
    env_parallel echo ::: OK_bigvar_quote
    bigvar="$(perl -e 'print "\""x12000')"
    env_parallel -S lo echo ::: OK_bigvar_quote_remote

    bigvar=u
    eval 'bigfunc() { a="'"$(perl -e 'print "x"x24000')"'"; };'
    env_parallel echo ::: OK_bigfunc
    eval 'bigfunc() { a="'"$(perl -e 'print "x"x12000')"'"; };'
    env_parallel -S lo echo ::: OK_bigfunc_remote

    eval 'bigfunc() { a="'"$(perl -e 'print "\""x24000')"'"; };'
    env_parallel echo ::: OK_bigfunc_quote
    eval 'bigfunc() { a="'"$(perl -e 'print "\""x12000')"'"; };'
    env_parallel -S lo echo ::: OK_bigfunc_quote_remote
    bigfunc() { true; }

    echo Rest should fail

    bigvar="$(perl -e 'print "x"x126000')"
    env_parallel echo ::: fail_bigvar
    env_parallel -S lo echo ::: fail_bigvar_remote

    bigvar="$(perl -e 'print "\""x127000')"
    env_parallel echo ::: fail_bigvar_quote
    env_parallel -S lo echo ::: fail_bigvar_quote_remote

    bigvar=u
    eval 'bigfunc() { a="'"$(perl -e 'print "x"x128000')"'"; };'
    env_parallel echo ::: fail_bigfunc
    env_parallel -S lo echo ::: fail_bigfunc_remote

    eval 'bigfunc() { a="'"$(perl -e 'print "\""x129000')"'"; };'
    env_parallel echo ::: fail_bigfunc_quote
    env_parallel -S lo echo ::: fail_bigfunc_quote_remote

    bigfunc() { true; }
_EOF
  )
  ssh zsh@lo "$myscript"
}

par_ash_parset() {
  myscript=$(cat <<'_EOF'
    echo 'parset'
    . `which env_parallel.ash`

#    Arrays not supported
#    echo '### parset into array'
#    parset arr1 echo ::: foo bar baz
#    echo ${arr1[0]} ${arr1[1]} ${arr1[2]}

    echo '### parset into vars with comma'
    parset comma3,comma2,comma1 echo ::: baz bar foo
    echo $comma1 $comma2 $comma3

    echo '### parset into vars with space'
    parset 'space3 space2 space1' echo ::: baz bar foo
    echo $space1 $space2 $space3

    echo '### parset with newlines'
    parset 'newline3 newline2 newline1' seq ::: 3 2 1
    echo "$newline1"
    echo "$newline2"
    echo "$newline3"

#    Arrays not supported
#    echo '### parset into indexed array vars'
#    parset 'myarray[6],myarray[5],myarray[4]' echo ::: baz bar foo
#    echo ${myarray[*]}
#    echo ${myarray[4]} ${myarray[5]} ${myarray[6]}

    echo '### env_parset'
    myfun() {
        myecho myfun "$@";
    }
    alias myecho='echo myecho "$myvar"'
    myvar="myvar"
#    Arrays not supported
#    myarr=("myarr  0" "myarr  1" "myarr  2")
    mynewline="`echo newline1;echo newline2;`"
#    Arrays not supported
#    env_parset arr1 myfun ::: foo bar baz
#    echo "${arr1[0]} ${arr1[1]} ${arr1[2]}"
    env_parset comma3,comma2,comma1 myecho ::: baz bar foo
    echo "$comma1 $comma2 $comma3"
    env_parset 'space3 space2 space1' myecho ::: baz bar foo
    echo "$space1 $space2 $space3"
    env_parset 'newline3 newline2 newline1' 'echo "$mynewline";seq' ::: 3 2 1
    echo "$newline1"
    echo "$newline2"
    echo "$newline3"
#    Arrays not supported
#    env_parset 'myarray[6],myarray[5],myarray[4]' myfun ::: baz bar foo
#    echo "${myarray[*]}"
#    echo "${myarray[4]} ${myarray[5]} ${myarray[6]}"
    parset a,b,c,d 'echo {};exit {}' ::: 0 1 1 0
    echo Exit value 2 = $?
    env_parset a,b,c,d 'echo {};exit {}' ::: 0 1 1 0
    echo Exit value 2 = $?
_EOF
  )
  ssh ash@lo "$myscript"
}

par_bash_parset() {
  myscript=$(cat <<'_EOF'
    echo 'parset'
    . `which env_parallel.bash`

    echo '### parset into array'
    parset arr1 echo ::: foo bar baz
    echo ${arr1[0]} ${arr1[1]} ${arr1[2]}

    echo '### parset into vars with comma'
    parset comma3,comma2,comma1 echo ::: baz bar foo
    echo $comma1 $comma2 $comma3

    echo '### parset into vars with space'
    parset 'space3 space2 space1' echo ::: baz bar foo
    echo $space1 $space2 $space3

    echo '### parset with newlines'
    parset 'newline3 newline2 newline1' seq ::: 3 2 1
    echo "$newline1"
    echo "$newline2"
    echo "$newline3"

    echo '### parset into indexed array vars'
    parset 'myarray[6],myarray[5],myarray[4]' echo ::: baz bar foo
    echo ${myarray[*]}
    echo ${myarray[4]} ${myarray[5]} ${myarray[6]}

    echo '### env_parset'
    myfun() {
        myecho myfun "$@";
    }
    alias myecho='echo myecho "$myvar" "${myarr[1]}"'
    myvar="myvar"
    myarr=("myarr  0" "myarr  1" "myarr  2")
    mynewline="`echo newline1;echo newline2;`"
    env_parset arr1 myfun ::: foo bar baz
    echo "${arr1[0]} ${arr1[1]} ${arr1[2]}"
    env_parset comma3,comma2,comma1 myfun ::: baz bar foo
    echo "$comma1 $comma2 $comma3"
    env_parset 'space3 space2 space1' myfun ::: baz bar foo
    echo "$space1 $space2 $space3"
    env_parset 'newline3 newline2 newline1' 'echo "$mynewline";seq' ::: 3 2 1
    echo "$newline1"
    echo "$newline2"
    echo "$newline3"
    env_parset 'myarray[6],myarray[5],myarray[4]' myfun ::: baz bar foo
    echo "${myarray[*]}"
    echo "${myarray[4]} ${myarray[5]} ${myarray[6]}"
    parset a,b,c,d 'echo {};exit {}' ::: 0 1 1 0
    echo Exit value 2 = $?
    env_parset a,b,c,d 'echo {};exit {}' ::: 0 1 1 0
    echo Exit value 2 = $?
_EOF
  )
  ssh bash@lo "$myscript"
}

par_csh_parset() {
    echo Not implemented
}

par_dash_parset() {
  myscript=$(cat <<'_EOF'
    echo 'parset'
    . `which env_parallel.dash`

#    Arrays not supported
#    echo '### parset into array'
#    parset arr1 echo ::: foo bar baz
#    echo ${arr1[0]} ${arr1[1]} ${arr1[2]}

    echo '### parset into vars with comma'
    parset comma3,comma2,comma1 echo ::: baz bar foo
    echo $comma1 $comma2 $comma3

    echo '### parset into vars with space'
    parset 'space3 space2 space1' echo ::: baz bar foo
    echo $space1 $space2 $space3

    echo '### parset with newlines'
    parset 'newline3 newline2 newline1' seq ::: 3 2 1
    echo "$newline1"
    echo "$newline2"
    echo "$newline3"

#    Arrays not supported
#    echo '### parset into indexed array vars'
#    parset 'myarray[6],myarray[5],myarray[4]' echo ::: baz bar foo
#    echo ${myarray[*]}
#    echo ${myarray[4]} ${myarray[5]} ${myarray[6]}

    echo '### env_parset'
    myfun() {
        myecho myfun "$@";
    }
    alias myecho='echo myecho "$myvar"'
    myvar="myvar"
#    Arrays not supported
#    myarr=("myarr  0" "myarr  1" "myarr  2")
    mynewline="`echo newline1;echo newline2;`"
#    Arrays not supported
#    env_parset arr1 myfun ::: foo bar baz
#    echo "${arr1[0]} ${arr1[1]} ${arr1[2]}"
    env_parset comma3,comma2,comma1 myecho ::: baz bar foo
    echo "$comma1 $comma2 $comma3"
    env_parset 'space3 space2 space1' myecho ::: baz bar foo
    echo "$space1 $space2 $space3"
    env_parset 'newline3 newline2 newline1' 'echo "$mynewline";seq' ::: 3 2 1
    echo "$newline1"
    echo "$newline2"
    echo "$newline3"
#    Arrays not supported
#    env_parset 'myarray[6],myarray[5],myarray[4]' myfun ::: baz bar foo
#    echo "${myarray[*]}"
#    echo "${myarray[4]} ${myarray[5]} ${myarray[6]}"
    parset a,b,c,d 'echo {};exit {}' ::: 0 1 1 0
    echo Exit value 2 = $?
    env_parset a,b,c,d 'echo {};exit {}' ::: 0 1 1 0
    echo Exit value 2 = $?
_EOF
  )
  ssh dash@lo "$myscript"
}

par_fish_parset() {
    echo Not implemented
}

par_ksh_parset() {
  myscript=$(cat <<'_EOF'
    echo 'parset'
    . `which env_parallel.ksh`

    echo '### parset into array'
    parset arr1 echo ::: foo bar baz
    echo ${arr1[0]} ${arr1[1]} ${arr1[2]}

    echo '### parset into vars with comma'
    parset comma3,comma2,comma1 echo ::: baz bar foo
    echo $comma1 $comma2 $comma3

    echo '### parset into vars with space'
    parset 'space3 space2 space1' echo ::: baz bar foo
    echo $space1 $space2 $space3

    echo '### parset with newlines'
    parset 'newline3 newline2 newline1' seq ::: 3 2 1
    echo "$newline1"
    echo "$newline2"
    echo "$newline3"

    echo '### parset into indexed array vars'
    parset 'myarray[6],myarray[5],myarray[4]' echo ::: baz bar foo
    echo ${myarray[*]}
    echo ${myarray[4]} ${myarray[5]} ${myarray[6]}

    echo '### env_parset'
    myfun() {
        myecho myfun "$@";
    }
    alias myecho='echo myecho "$myvar" "${myarr[1]}"'
    myvar="myvar"
    myarr=("myarr  0" "myarr  1" "myarr  2")
    mynewline="`echo newline1;echo newline2;`"
    env_parset arr1 myfun ::: foo bar baz
    echo "${arr1[0]} ${arr1[1]} ${arr1[2]}"
    env_parset comma3,comma2,comma1 myfun ::: baz bar foo
    echo "$comma1 $comma2 $comma3"
    env_parset 'space3 space2 space1' myfun ::: baz bar foo
    echo "$space1 $space2 $space3"
    env_parset 'newline3 newline2 newline1' 'echo "$mynewline";seq' ::: 3 2 1
    echo "$newline1"
    echo "$newline2"
    echo "$newline3"
    env_parset 'myarray[6],myarray[5],myarray[4]' myfun ::: baz bar foo
    echo "${myarray[*]}"
    echo "${myarray[4]} ${myarray[5]} ${myarray[6]}"
    parset a,b,c,d 'echo {};exit {}' ::: 0 1 1 0
    echo Exit value 2 = $?
    env_parset a,b,c,d 'echo {};exit {}' ::: 0 1 1 0
    echo Exit value 2 = $?
_EOF
  )
  ssh ksh@lo "$myscript"
}

par_mksh_parset() {
  myscript=$(cat <<'_EOF'
    echo 'parset'
    . `which env_parallel.mksh`

    echo '### parset into array'
    parset arr1 echo ::: foo bar baz
    echo ${arr1[0]} ${arr1[1]} ${arr1[2]}

    echo '### parset into vars with comma'
    parset comma3,comma2,comma1 echo ::: baz bar foo
    echo $comma1 $comma2 $comma3

    echo '### parset into vars with space'
    parset 'space3 space2 space1' echo ::: baz bar foo
    echo $space1 $space2 $space3

    echo '### parset with newlines'
    parset 'newline3 newline2 newline1' seq ::: 3 2 1
    echo "$newline1"
    echo "$newline2"
    echo "$newline3"

    echo '### parset into indexed array vars'
    parset 'myarray[6],myarray[5],myarray[4]' echo ::: baz bar foo
    echo ${myarray[*]}
    echo ${myarray[4]} ${myarray[5]} ${myarray[6]}

    echo '### env_parset'
    # bug in mksh: Alias must be set before
    alias myecho='echo myecho "$myvar" "${myarr[1]}"'
    myfun() {
        myecho myfun "$@";
    }
    alias myecho='echo myecho "$myvar" "${myarr[1]}"'
    myvar="myvar"
    myarr=("myarr  0" "myarr  1" "myarr  2")
    mynewline="`echo newline1;echo newline2;`"
    env_parset arr1 myfun ::: foo bar baz
    echo "${arr1[0]} ${arr1[1]} ${arr1[2]}"
    env_parset comma3,comma2,comma1 myfun ::: baz bar foo
    echo "$comma1 $comma2 $comma3"
    env_parset 'space3 space2 space1' myfun ::: baz bar foo
    echo "$space1 $space2 $space3"
    env_parset 'newline3 newline2 newline1' 'echo "$mynewline";seq' ::: 3 2 1
    echo "$newline1"
    echo "$newline2"
    echo "$newline3"
    env_parset 'myarray[6],myarray[5],myarray[4]' myfun ::: baz bar foo
    echo "${myarray[*]}"
    echo "${myarray[4]} ${myarray[5]} ${myarray[6]}"
    parset a,b,c,d 'echo {};exit {}' ::: 0 1 1 0
    echo Exit value 2 = $?
    env_parset a,b,c,d 'echo {};exit {}' ::: 0 1 1 0
    echo Exit value 2 = $?
_EOF
  )
  ssh mksh@lo "$myscript"
}

par_sh_parset() {
  myscript=$(cat <<'_EOF'
    echo 'parset'
    . `which env_parallel.sh`

#    echo '### parset into array'
#    echo "Arrays not supported in all sh's"
#    parset arr1 echo ::: foo bar baz
#    echo ${arr1[0]} ${arr1[1]} ${arr1[2]}

    echo '### parset into vars with comma'
    parset comma3,comma2,comma1 echo ::: baz bar foo
    echo $comma1 $comma2 $comma3

    echo '### parset into vars with space'
    parset 'space3 space2 space1' echo ::: baz bar foo
    echo $space1 $space2 $space3

    echo '### parset with newlines'
    parset 'newline3 newline2 newline1' seq ::: 3 2 1
    echo "$newline1"
    echo "$newline2"
    echo "$newline3"

#    echo '### parset into indexed array vars'
#    echo "Arrays not supported in all sh's"
#    parset 'myarray[6],myarray[5],myarray[4]' echo ::: baz bar foo
#    echo ${myarray[*]}
#    echo ${myarray[4]} ${myarray[5]} ${myarray[6]}

    echo '### env_parset'
    echo '# alias'
    alias myalias='echo myalias'
    env_parset alias3,alias2,alias1 myalias ::: baz bar foo
    echo "$alias1"
    echo "$alias2"
    echo "$alias3"

#    echo '# function'
#    echo "Arrays not supported in all sh's"
#    myfun() {
#        echo myfun "$@";
#    }
#    env_parset fun3,fun2,fun1 myfun ::: baz bar foo
#    echo "$fun1"
#    echo "$fun2"
#    echo "$fun3"

    echo '# variable with newline'
    myvar="`echo newline1;echo newline2;`"
    env_parset var3,var2,var1 'echo "$myvar"' ::: baz bar foo
    echo "$var1"
    echo "$var2"
    echo "$var3"

#    Arrays not supported
#    myarr=("myarr  0" "myarr  1" "myarr  2")
#    Arrays not supported
#    env_parset arr1 myfun ::: foo bar baz
#    echo "${arr1[0]} ${arr1[1]} ${arr1[2]}"

    echo '### parset into vars with comma'
    env_parset comma3,comma2,comma1 echo ::: baz bar foo
    echo "$comma1 $comma2 $comma3"
    echo '### parset into vars with space'
    env_parset 'space3 space2 space1' echo ::: baz bar foo
    echo "$space1 $space2 $space3"
    echo '### parset with newlines'
    mynewline="`echo newline1;echo newline2;`"
    env_parset 'newline3 newline2 newline1' 'echo "$mynewline";seq' ::: 3 2 1
    echo "$newline1"
    echo "$newline2"
    echo "$newline3"
#    Arrays not supported
#    env_parset 'myarray[6],myarray[5],myarray[4]' myfun ::: baz bar foo
#    echo "${myarray[*]}"
#    echo "${myarray[4]} ${myarray[5]} ${myarray[6]}"
    parset a,b,c,d 'echo {};exit {}' ::: 0 1 1 0
    echo Exit value 2 = $?
    env_parset a,b,c,d 'echo {};exit {}' ::: 0 1 1 0
    echo Exit value 2 = $?
_EOF
  )
  ssh sh@lo "$myscript"
}

par_tcsh_parset() {
    echo Not implemented
}

par_zsh_parset() {
  myscript=$(cat <<'_EOF'
    echo 'parset'
    . `which env_parallel.zsh`
    eval "`cat <<"_EOS";

    echo '### parset into array'
    parset arr1 echo ::: foo bar baz
    echo ${arr1[1]} ${arr1[2]} ${arr1[3]}

    echo '### parset into vars with comma'
    parset comma3,comma2,comma1 echo ::: baz bar foo
    echo $comma1 $comma2 $comma3

    echo '### parset into vars with space'
    parset 'space3 space2 space1' echo ::: baz bar foo
    echo $space1 $space2 $space3

    echo '### parset with newlines'
    parset 'newline3 newline2 newline1' seq ::: 3 2 1
    echo "$newline1"
    echo "$newline2"
    echo "$newline3"

    echo '### parset into indexed array vars'
    parset 'myarray[6],myarray[5],myarray[4]' echo ::: baz bar foo
    echo ${myarray[*]}
    echo ${myarray[4]} ${myarray[5]} ${myarray[6]}

    echo '### env_parset'
    alias myecho='echo myecho "$myvar" "${myarr[1]}"';
    # eval is needed because zsh does not see alias in function otherwise
    eval "myfun() {
        myecho myfun \"\$\@\"
    }"
    myvar="myvar"
    myarr=("myarr  0" "myarr  1" "myarr  2")
    mynewline="$(echo newline1;echo newline2;)"
    env_parset arr1 myfun {} ::: foo bar baz
    echo "${arr1[1]}"
    echo "${arr1[2]}"
    echo "${arr1[3]}"
    env_parset comma3,comma2,comma1 myfun ::: baz bar foo
    echo "$comma1"
    echo "$comma2"
    echo "$comma3"
    env_parset 'space3 space2 space1' myfun ::: baz bar foo
    echo "$space1"
    echo "$space2"
    echo "$space3"
    env_parset 'newline3 newline2 newline1' 'echo "$mynewline";seq' ::: 3 2 1
    echo "$newline1"
    echo "$newline2"
    echo "$newline3"
    env_parset 'myarray[6],myarray[5],myarray[4]' myfun ::: baz bar foo
    echo "${myarray[*]}"
    echo "${myarray[4]} ${myarray[5]} ${myarray[6]}"
    parset a,b,c,d 'echo {};exit {}' ::: 0 1 1 0
    echo Exit value 2 = $?
    env_parset a,b,c,d 'echo {};exit {}' ::: 0 1 1 0
    echo Exit value 2 = $?
_EOS`"
_EOF
  )
  ssh zsh@lo "$myscript"
}

### env_parallel_session

par_ash_env_parallel_session() {
  myscript=$(cat <<'_EOF'
    . `which env_parallel.ash`
    echo '### Test env_parallel --session'

    level0var=l0var
# Arrays and functions not supported
#   level0arr=(level0 array)
#   level0func() { echo l0func; }
    alias level0alias='echo l0alias'

    env_parallel --session

    level1var=l1var
# Arrays and functions not supported
#    level1arr=(level1 array)
#    level1func() { echo l1func; }
    alias level1alias='echo l1alias'

    echo '### level0 should be hidden, level1 should be transferred'
    env_parallel -Slo 'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel      'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel -Slo 'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK
    env_parallel      'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK

    env_parallel --session

    level2var=l2var
# Arrays and functions not supported
#    level2arr=(level2 array)
#    level2func() { echo l2func; }
    alias level2alias='echo l2alias'

    echo '### level0+1 should be hidden, level2 should be transferred'
    env_parallel -Slo 'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel      'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel -Slo 'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: fail
    env_parallel      'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: fail
    env_parallel -Slo 'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK
    env_parallel      'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK

    env_parallel --endsession

    echo '### level0 should be hidden, level1+2 should be transferred'
    env_parallel -Slo 'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel      'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel -Slo 'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK
    env_parallel      'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK
    env_parallel -Slo 'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK
    env_parallel      'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK

    env_parallel --endsession

    echo '### level0+1+2 should be transferred'
    env_parallel -Slo 'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: OK
    env_parallel      'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: OK
    env_parallel -Slo 'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK
    env_parallel      'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK
    env_parallel -Slo 'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK
    env_parallel      'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK

    alias aliasbefore='echo before'
# Functions not supported
#    varbefore='before'
#    funcbefore() { echo 'before' "$@"; }
# Arrays not supported
#    arraybefore=(array before)
    env_parallel --session
    # stuff defined
    env_parallel aliasbefore ::: must_fail
    env_parallel -S lo aliasbefore ::: must_fail
# Functions not supported
#    env_parallel funcbefore ::: must_fail
#    env_parallel -S lo funcbefore ::: must_fail
    env_parallel echo '$varbefore' ::: no_before
    env_parallel -S lo echo '$varbefore' ::: no_before
# Arrays not supported
#    env_parallel echo '${arraybefore[*]}' ::: no_before
#    env_parallel -S lo echo '${arraybefore[*]}' ::: no_before
    alias aliasafter='echo after'
    varafter='after'
# Functions not supported
#    funcafter() { echo 'after' "$@"; }
# Arrays not supported
#    arrayafter=(array after)
    env_parallel aliasafter ::: aliasafter_OK
    env_parallel -S lo aliasafter ::: aliasafter_OK
# Functions not supported
#    env_parallel funcafter ::: funcafter_OK
#    env_parallel -S lo funcafter ::: funcafter_OK
    env_parallel echo '$varafter' ::: varafter_OK
    env_parallel -S lo echo '$varafter' ::: varafter_OK
# Arrays not supported
#    env_parallel echo '${arrayafter[*]}' ::: arrayafter_OK
#    env_parallel -S lo echo '${arrayafter[*]}' ::: arrayafter_OK
    unset PARALLEL_IGNORED_NAMES
_EOF
  )
  ssh ash@lo "$myscript"
}

par_bash_env_parallel_session() {
  myscript=$(cat <<'_EOF'
    echo '### Test env_parallel --session / --end-session'
    . `which env_parallel.bash`

    level0var=l0var
    level0arr=(level0 array)
    level0func() { echo l0func; }
    alias level0alias='echo l0alias'

    env_parallel --session

    level1var=l1var
    level1arr=(level1 array)
    level1func() { echo l1func; }
    alias level1alias='echo l1alias'

    echo '### level0 should be hidden, level1 should be transferred'
    env_parallel -Slo 'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel      'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel -Slo 'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK
    env_parallel      'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK

    env_parallel --session

    level2var=l2var
    level2arr=(level2 array)
    level2func() { echo l2func; }
    alias level2alias='echo l2alias'

    echo '### level0+1 should be hidden, level2 should be transferred'
    env_parallel -Slo 'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel      'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel -Slo 'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: fail
    env_parallel      'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: fail
    env_parallel -Slo 'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK
    env_parallel      'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK

    env_parallel --endsession

    echo '### level0 should be hidden, level1+2 should be transferred'
    env_parallel -Slo 'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel      'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel -Slo 'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK
    env_parallel      'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK
    env_parallel -Slo 'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK
    env_parallel      'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK

    env_parallel --endsession

    echo '### level0+1+2 should be transferred'
    env_parallel -Slo 'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: OK
    env_parallel      'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: OK
    env_parallel -Slo 'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK
    env_parallel      'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK
    env_parallel -Slo 'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK
    env_parallel      'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK

    alias aliasl0='echo l0'
    varl0='l0'
    funcl0() { echo 'l0' "$@"; }
    arrayl0=(array l0)
    env_parallel --session
    # stuff defined
    env_parallel aliasl0 ::: must_fail
    env_parallel -S lo aliasl0 ::: must_fail
    env_parallel funcl0 ::: must_fail
    env_parallel -S lo funcl0 ::: must_fail
    env_parallel echo '$varl0' ::: no_before
    env_parallel -S lo echo '$varl0' ::: no_before
    env_parallel echo '${arrayl0[*]}' ::: no_before
    env_parallel -S lo echo '${arrayl0[*]}' ::: no_before
    alias aliasl1='echo l1'
    varl1='l1'
    funcl1() { echo 'l1' "$@"; }
    arrayl1=(array l1)
    env_parallel aliasl1 ::: aliasl1_OK
    env_parallel -S lo aliasl1 ::: aliasl1_OK
    env_parallel funcl1 ::: funcl1_OK
    env_parallel -S lo funcl1 ::: funcl1_OK
    env_parallel echo '$varl1' ::: varl1_OK
    env_parallel -S lo echo '$varl1' ::: varl1_OK
    env_parallel echo '${arrayl1[*]}' ::: arrayl1_OK
    env_parallel -S lo echo '${arrayl1[*]}' ::: arrayl1_OK


    unset PARALLEL_IGNORED_NAMES
_EOF
  )
  ssh bash@lo "$myscript"
}

par_csh_env_parallel_session() {
    echo Not implemented
}

par_dash_env_parallel_session() {
  myscript=$(cat <<'_EOF'
    . `which env_parallel.dash`
    echo '### Test env_parallel --session'

    level0var=l0var
# Arrays and functions not supported
#   level0arr=(level0 array)
#   level0func() { echo l0func; }
    alias level0alias='echo l0alias'

    env_parallel --session

    level1var=l1var
# Arrays and functions not supported
#    level1arr=(level1 array)
#    level1func() { echo l1func; }
    alias level1alias='echo l1alias'

    echo '### level0 should be hidden, level1 should be transferred'
    env_parallel -Slo 'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel      'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel -Slo 'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK
    env_parallel      'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK

    env_parallel --session

    level2var=l2var
# Arrays and functions not supported
#    level2arr=(level2 array)
#    level2func() { echo l2func; }
    alias level2alias='echo l2alias'

    echo '### level0+1 should be hidden, level2 should be transferred'
    env_parallel -Slo 'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel      'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel -Slo 'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: fail
    env_parallel      'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: fail
    env_parallel -Slo 'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK
    env_parallel      'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK

    env_parallel --endsession

    echo '### level0 should be hidden, level1+2 should be transferred'
    env_parallel -Slo 'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel      'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel -Slo 'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK
    env_parallel      'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK
    env_parallel -Slo 'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK
    env_parallel      'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK

    env_parallel --endsession

    echo '### level0+1+2 should be transferred'
    env_parallel -Slo 'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: OK
    env_parallel      'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: OK
    env_parallel -Slo 'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK
    env_parallel      'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK
    env_parallel -Slo 'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK
    env_parallel      'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK

    alias aliasbefore='echo before'
    varbefore='before'
# Functions not supported
#    funcbefore() { echo 'before' "$@"; }
# Arrays not supported
#    arraybefore=(array before)
    env_parallel --session
    # stuff defined
    env_parallel aliasbefore ::: must_fail
    env_parallel -S lo aliasbefore ::: must_fail
# Functions not supported
#    env_parallel funcbefore ::: must_fail
#    env_parallel -S lo funcbefore ::: must_fail
    env_parallel echo '$varbefore' ::: no_before
    env_parallel -S lo echo '$varbefore' ::: no_before
# Arrays not supported
#    env_parallel echo '${arraybefore[*]}' ::: no_before
#    env_parallel -S lo echo '${arraybefore[*]}' ::: no_before
    alias aliasafter='echo after'
    varafter='after'
# Functions not supported
#    funcafter() { echo 'after' "$@"; }
# Arrays not supported
#    arrayafter=(array after)
    env_parallel aliasafter ::: aliasafter_OK
    env_parallel -S lo aliasafter ::: aliasafter_OK
# Functions not supported
#    env_parallel funcafter ::: funcafter_OK
#    env_parallel -S lo funcafter ::: funcafter_OK
    env_parallel echo '$varafter' ::: varafter_OK
    env_parallel -S lo echo '$varafter' ::: varafter_OK
# Arrays not supported
#    env_parallel echo '${arrayafter[*]}' ::: arrayafter_OK
#    env_parallel -S lo echo '${arrayafter[*]}' ::: arrayafter_OK
    unset PARALLEL_IGNORED_NAMES
_EOF
  )
  ssh dash@lo "$myscript"
}

par_fish_env_parallel_session() {
  myscript=$(cat <<'_EOF'
    . (which env_parallel.fish)

    echo '### Test env_parallel --session'

    alias aliasbefore='echo before'
    set varbefore 'before'
    function funcbefore
      echo 'before' "$argv"
    end
    set arraybefore array before
    env_parallel --session
    # stuff defined
    env_parallel aliasbefore ::: must_fail
    env_parallel -S lo aliasbefore ::: must_fail
    env_parallel funcbefore ::: must_fail
    env_parallel -S lo funcbefore ::: must_fail
    env_parallel echo '$varbefore' ::: no_before
    env_parallel -S lo echo '$varbefore' ::: no_before
    env_parallel echo '$arraybefore' ::: no_before
    env_parallel -S lo echo '$arraybefore' ::: no_before
    alias aliasafter='echo after'
    set varafter 'after'
    function funcafter
      echo 'after' "$argv"
    end
    set arrayafter array after
    env_parallel aliasafter ::: aliasafter_OK
    env_parallel -S lo aliasafter ::: aliasafter_OK
    env_parallel funcafter ::: funcafter_OK
    env_parallel -S lo funcafter ::: funcafter_OK
    env_parallel echo '$varafter' ::: varafter_OK
    env_parallel -S lo echo '$varafter' ::: varafter_OK
    env_parallel echo '$arrayafter' ::: arrayafter_OK
    env_parallel -S lo echo '$arrayafter' ::: arrayafter_OK
    set -e PARALLEL_IGNORED_NAMES
_EOF
  )
  ssh fish@lo "$myscript"
}

par_ksh_env_parallel_session() {
  myscript=$(cat <<'_EOF'
    . `which env_parallel.ksh`
    echo '### Test env_parallel --session'

    level0var=l0var
    level0arr=(level0 array)
    level0func() { echo l0func; }
    alias level0alias='echo l0alias'

    env_parallel --session

    level1var=l1var
    level1arr=(level1 array)
    level1func() { echo l1func; }
    alias level1alias='echo l1alias'

    echo '### level0 should be hidden, level1 should be transferred'
    env_parallel -Slo 'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel      'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel -Slo 'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK
    env_parallel      'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK

    env_parallel --session

    level2var=l2var
    level2arr=(level2 array)
    level2func() { echo l2func; }
    alias level2alias='echo l2alias'

    echo '### level0+1 should be hidden, level2 should be transferred'
    env_parallel -Slo 'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel      'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel -Slo 'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: fail
    env_parallel      'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: fail
    env_parallel -Slo 'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK
    env_parallel      'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK

    env_parallel --endsession

    echo '### level0 should be hidden, level1+2 should be transferred'
    env_parallel -Slo 'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel      'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel -Slo 'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK
    env_parallel      'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK
    env_parallel -Slo 'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK
    env_parallel      'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK

    env_parallel --endsession

    echo '### level0+1+2 should be transferred'
    env_parallel -Slo 'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: OK
    env_parallel      'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: OK
    env_parallel -Slo 'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK
    env_parallel      'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK
    env_parallel -Slo 'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK
    env_parallel      'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK

    alias aliasbefore='echo before'
    varbefore='before'
    funcbefore() { echo 'before' "$@"; }
    arraybefore=(array before)
    env_parallel --session
    # stuff defined
    env_parallel aliasbefore ::: must_fail
    env_parallel -S lo aliasbefore ::: must_fail
    env_parallel funcbefore ::: must_fail
    env_parallel -S lo funcbefore ::: must_fail
    env_parallel echo '$varbefore' ::: no_before
    env_parallel -S lo echo '$varbefore' ::: no_before
    env_parallel echo '${arraybefore[*]}' ::: no_before
    env_parallel -S lo echo '${arraybefore[*]}' ::: no_before
    alias aliasafter='echo after'
    varafter='after'
    funcafter() { echo 'after' "$@"; }
    arrayafter=(array after)
    env_parallel aliasafter ::: aliasafter_OK
    env_parallel -S lo aliasafter ::: aliasafter_OK
    env_parallel funcafter ::: funcafter_OK
    env_parallel -S lo funcafter ::: funcafter_OK
    env_parallel echo '$varafter' ::: varafter_OK
    env_parallel -S lo echo '$varafter' ::: varafter_OK
    env_parallel echo '${arrayafter[*]}' ::: arrayafter_OK
    env_parallel -S lo echo '${arrayafter[*]}' ::: arrayafter_OK
    unset PARALLEL_IGNORED_NAMES
_EOF
  )
  ssh ksh@lo "$myscript"
}

par_mksh_env_parallel_session() {
  myscript=$(cat <<'_EOF'
    . `which env_parallel.mksh`
    echo '### Test env_parallel --session'

    level0var=l0var
    level0arr=(level0 array)
    level0func() { echo l0func; }
    alias level0alias='echo l0alias'

    env_parallel --session

    level1var=l1var
    level1arr=(level1 array)
    level1func() { echo l1func; }
    alias level1alias='echo l1alias'

    echo '### level0 should be hidden, level1 should be transferred'
    env_parallel -Slo 'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel      'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel -Slo 'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK
    env_parallel      'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK

    env_parallel --session

    level2var=l2var
    level2arr=(level2 array)
    level2func() { echo l2func; }
    alias level2alias='echo l2alias'

    echo '### level0+1 should be hidden, level2 should be transferred'
    env_parallel -Slo 'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel      'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel -Slo 'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: fail
    env_parallel      'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: fail
    env_parallel -Slo 'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK
    env_parallel      'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK

    env_parallel --endsession

    echo '### level0 should be hidden, level1+2 should be transferred'
    env_parallel -Slo 'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel      'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel -Slo 'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK
    env_parallel      'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK
    env_parallel -Slo 'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK
    env_parallel      'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK

    env_parallel --endsession

    echo '### level0+1+2 should be transferred'
    env_parallel -Slo 'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: OK
    env_parallel      'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: OK
    env_parallel -Slo 'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK
    env_parallel      'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK
    env_parallel -Slo 'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK
    env_parallel      'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK

    alias aliasbefore='echo before'
    varbefore='before'
    funcbefore() { echo 'before' "$@"; }
    arraybefore=(array before)
    env_parallel --session
    # stuff defined
    env_parallel aliasbefore ::: must_fail
    env_parallel -S lo aliasbefore ::: must_fail
    env_parallel funcbefore ::: must_fail
    env_parallel -S lo funcbefore ::: must_fail
    env_parallel echo '$varbefore' ::: no_before
    env_parallel -S lo echo '$varbefore' ::: no_before
    env_parallel echo '${arraybefore[*]}' ::: no_before
    env_parallel -S lo echo '${arraybefore[*]}' ::: no_before
    alias aliasafter='echo after'
    varafter='after'
    funcafter() { echo 'after' "$@"; }
    arrayafter=(array after)
    env_parallel aliasafter ::: aliasafter_OK
    env_parallel -S lo aliasafter ::: aliasafter_OK
    env_parallel funcafter ::: funcafter_OK
    env_parallel -S lo funcafter ::: funcafter_OK
    env_parallel echo '$varafter' ::: varafter_OK
    env_parallel -S lo echo '$varafter' ::: varafter_OK
    env_parallel echo '${arrayafter[*]}' ::: arrayafter_OK
    env_parallel -S lo echo '${arrayafter[*]}' ::: arrayafter_OK
    unset PARALLEL_IGNORED_NAMES
_EOF
  )
  ssh mksh@lo "$myscript"
}

par_sh_env_parallel_session() {
  myscript=$(cat <<'_EOF'
    . `which env_parallel.sh`
    echo '### Test env_parallel --session'

    level0var=l0var
#    level0arr=(level0 array)
    level0func() { echo l0func; }
#    alias level0alias='echo l0alias'

    env_parallel --session

    level1var=l1var
#    level1arr=(level1 array)
    level1func() { echo l1func; }
#    alias level1alias='echo l1alias'

    echo '### level0 should be hidden, level1 should be transferred'
    env_parallel -Slo 'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel      'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel -Slo 'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK
    env_parallel      'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK

    env_parallel --session

    level2var=l2var
#    level2arr=(level2 array)
    level2func() { echo l2func; }
#    alias level2alias='echo l2alias'

    echo '### level0+1 should be hidden, level2 should be transferred'
    env_parallel -Slo 'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel      'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel -Slo 'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: fail
    env_parallel      'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: fail
    env_parallel -Slo 'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK
    env_parallel      'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK

    env_parallel --endsession

    echo '### level0 should be hidden, level1+2 should be transferred'
    env_parallel -Slo 'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel      'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel -Slo 'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK
    env_parallel      'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK
    env_parallel -Slo 'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK
    env_parallel      'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK

    env_parallel --endsession

    echo '### level0+1+2 should be transferred'
    env_parallel -Slo 'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: OK
    env_parallel      'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: OK
    env_parallel -Slo 'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK
    env_parallel      'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK
    env_parallel -Slo 'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK
    env_parallel      'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK

    alias aliasbefore='echo before'
    varbefore='before'
    funcbefore() { echo 'before' "$@"; }
#    Arrays not supported
#    arraybefore=(array before)
    env_parallel --session
    # stuff defined
    env_parallel aliasbefore ::: must_fail
    env_parallel -S lo aliasbefore ::: must_fail
    env_parallel funcbefore ::: must_fail
    env_parallel -S lo funcbefore ::: must_fail
    env_parallel echo '$varbefore' ::: no_before
    env_parallel -S lo echo '$varbefore' ::: no_before
#    Arrays not supported
#    env_parallel echo '${arraybefore[*]}' ::: no_before
#    env_parallel -S lo echo '${arraybefore[*]}' ::: no_before
    alias aliasafter='echo after'
    varafter='after'
    funcafter() { echo 'after' "$@"; }
#    Arrays not supported
#    arrayafter=(array after)
    env_parallel aliasafter ::: aliasafter_OK
    env_parallel -S lo aliasafter ::: aliasafter_OK
    env_parallel funcafter ::: funcafter_OK
    env_parallel -S lo funcafter ::: funcafter_OK
    env_parallel echo '$varafter' ::: varafter_OK
    env_parallel -S lo echo '$varafter' ::: varafter_OK
#    Arrays not supported
#    env_parallel echo '${arrayafter[*]}' ::: arrayafter_OK
#    env_parallel -S lo echo '${arrayafter[*]}' ::: arrayafter_OK
    unset PARALLEL_IGNORED_NAMES
_EOF
  )
  ssh sh@lo "$myscript"
}

par_tcsh_env_parallel_session() {
    echo Not implemented
}

par_zsh_env_parallel_session() {
  myscript=$(cat <<'_EOF'
    . `which env_parallel.zsh`
    eval "`cat <<"_EOS";
    echo '### Test env_parallel --session'

    level0var=l0var
    level0arr=(level0 array)
    level0func() { echo l0func; }
    alias level0alias='echo l0alias'

    env_parallel --session

    level1var=l1var
    level1arr=(level1 array)
    level1func() { echo l1func; }
    alias level1alias='echo l1alias'

    echo '### level0 should be hidden, level1 should be transferred'
    env_parallel -Slo 'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel      'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel -Slo 'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK
    env_parallel      'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK

    env_parallel --session

    level2var=l2var
    level2arr=(level2 array)
    level2func() { echo l2func; }
    alias level2alias='echo l2alias'

    echo '### level0+1 should be hidden, level2 should be transferred'
    env_parallel -Slo 'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel      'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel -Slo 'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: fail
    env_parallel      'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: fail
    env_parallel -Slo 'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK
    env_parallel      'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK

    env_parallel --endsession

    echo '### level0 should be hidden, level1+2 should be transferred'
    env_parallel -Slo 'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel      'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: fail
    env_parallel -Slo 'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK
    env_parallel      'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK
    env_parallel -Slo 'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK
    env_parallel      'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK

    env_parallel --endsession

    echo '### level0+1+2 should be transferred'
    env_parallel -Slo 'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: OK
    env_parallel      'echo $level0var; level0func; level0alias; echo ${level0arr[*]}' ::: OK
    env_parallel -Slo 'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK
    env_parallel      'echo $level1var; level1func; level1alias; echo ${level1arr[*]}' ::: OK
    env_parallel -Slo 'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK
    env_parallel      'echo $level2var; level2func; level2alias; echo ${level2arr[*]}' ::: OK

    alias aliasbefore='echo before'
    varbefore='before'
    funcbefore() { echo 'before' "$@"; }
    arraybefore=(array before)
    env_parallel --session
    # stuff defined
    env_parallel aliasbefore ::: must_fail
    env_parallel -S lo aliasbefore ::: must_fail
    env_parallel funcbefore ::: must_fail
    env_parallel -S lo funcbefore ::: must_fail
    env_parallel echo '$varbefore' ::: no_before
    env_parallel -S lo echo '$varbefore' ::: no_before
    env_parallel echo '${arraybefore[*]}' ::: no_before
    env_parallel -S lo echo '${arraybefore[*]}' ::: no_before
    alias aliasafter='echo after'
    varafter='after'
    funcafter() { echo 'after' "$@"; }
    arrayafter=(array after)
    env_parallel aliasafter ::: aliasafter_OK
    env_parallel -S lo aliasafter ::: aliasafter_OK
    env_parallel funcafter ::: funcafter_OK
    env_parallel -S lo funcafter ::: funcafter_OK
    env_parallel echo '$varafter' ::: varafter_OK
    env_parallel -S lo echo '$varafter' ::: varafter_OK
    env_parallel echo '${arrayafter[*]}' ::: arrayafter_OK
    env_parallel -S lo echo '${arrayafter[*]}' ::: arrayafter_OK
    unset PARALLEL_IGNORED_NAMES
_EOS`"
_EOF
  )
  ssh zsh@lo "$myscript"
}

export -f $(compgen -A function | grep par_)

# --retries 2 due to ssh_exchange_identification: read: Connection reset by peer

#compgen -A function | grep par_ | sort | parallel --delay $D -j$P --tag -k '{} 2>&1'
#compgen -A function | grep par_ | sort |
compgen -A function | grep par_ | LC_ALL=C sort -r |
#    parallel --joblog /tmp/jl-`basename $0` --delay $D -j$P --tag -k '{} 2>&1'
    # 2019-07-14 200% too high for 16 GB/4 thread
    parallel --joblog /tmp/jl-`basename $0` -j75% --retries 2 --tag -k '{} 2>&1' |
    perl -pe 's/line \d?\d\d:/line XXX:/g;
              s/\d+ >= \d+/XXX >= XXX/;
              s/sh:? \d?\d\d:/sh: XXX:/;
              s/:\d?\d\d:/:XXX:/;
              s/sh\[\d+\]/sh[XXX]/;
	      s/.*(tange|zenodo).*//i;
	      s:/usr/bin:/bin:g;
	      '
