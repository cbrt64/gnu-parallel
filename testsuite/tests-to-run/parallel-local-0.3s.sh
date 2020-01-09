#!/bin/bash

# Simple jobs that never fails
# Each should be taking 0.3-1s and be possible to run in parallel
# I.e.: No race conditions, no logins

stdsort() {
    "$@" 2>&1 | LC_ALL=C sort;
}
export -f stdsort

# Test amount of parallelization
# parallel --shuf --jl /tmp/myjl -j1 'export JOBS={1};'bash tests-to-run/parallel-local-0.3s.sh ::: {1..16} ::: {1..5}

par_tmux_command_not_found() {
    echo '### PARALLEL_TMUX not found'
    PARALLEL_TMUX=not-existing parallel --tmux echo ::: 1
}

par_echo_jobseq() {
     echo '### bug #44995: parallel echo {#} ::: 1 2 ::: 1 2'

     parallel -k echo {#} ::: 1 2 ::: 1 2
}

par_no_joblog_with_dryrun() {
    echo 'bug #46016: --joblog should not log when --dryrun'

    parallel --dryrun --joblog - echo ::: Only_this
}

par_tagstring_with_d() {
    echo 'bug #47002: --tagstring with -d \n\n'

    (seq 3; echo; seq 4) |
	parallel -k -d '\n\n' --tagstring {%} echo ABC';'echo
}

par_xargs_nul_char_in_input() {
    echo 'bug #47290: xargs: Warning: a NUL character occurred in the input'

    perl -e 'print "foo\0not printed"' | parallel echo
}

par_maxproc() {
    echo '### Test --max-procs and -P: Number of processes'

    seq 1 10 | parallel -k --max-procs +0 echo max proc
    seq 1 10 | parallel -k -P 200% echo 200% proc
}

par_maxchar_s() {
    echo '### Test --max-chars and -s: Max number of chars in a line'

    (echo line 1;echo line 1;echo line 2) | parallel -k --max-chars 25 -X echo
    (echo line 1;echo line 1;echo line 2) | parallel -k -s 25 -X echo
}

par_no_run_if_empty() {
    echo '### Test --no-run-if-empty and -r: This should give no output'

    echo "  " | parallel -r echo
    echo "  " | parallel --no-run-if-empty echo
}

par_help() {
    echo '### Test --help and -h: Help output (just check we get the same amount of lines)'

    echo Output from -h and --help
    parallel -h | wc -l
    parallel --help | wc -l
}

par_version() {
    echo '### Test --version: Version output (just check we get the same amount of lines)'

    parallel --version | wc -l
}

par_verbose_t() {
    echo '### Test --verbose and -t'

    (echo b; echo c; echo f) | parallel -k -t echo {}ar 2>&1 >/dev/null
    (echo b; echo c; echo f) | parallel -k --verbose echo {}ar 2>&1 >/dev/null
}

par_show_limits() {
    echo '### Test --show-limits'

    (echo b; echo c; echo f) | parallel -k --show-limits echo {}ar
    (echo b; echo c; echo f) | parallel -j1 -kX --show-limits -s 100 echo {}ar
}

par_test_zero_args() {
    echo '### Test 0-arguments'

    seq 1 2 | parallel -k -n0 echo n0
    seq 1 2 | parallel -k -L0 echo L0
    seq 1 2 | parallel -k -N0 echo N0
}

par_l0_is_l1() {
    echo '### Because of --tollef -l, then -l0 == -l1, sorry'

    seq 1 2 | parallel -k -l0 echo l0
}

par_replace_replacementstring() {
    echo '### Test replace {}'

    seq 1 2 | parallel -k -N0 echo replace {} curlies
}

par_arguments_on_cmdline() {
    echo '### Test arguments on commandline'

    parallel -k -N0 echo args on cmdline ::: 1 2
}

par_nice_locally() {
    echo '### Test --nice locally'

    parallel --nice 1 -vv 'PAR=a bash -c "echo  \$PAR {}"' ::: b
}

par_disk_full() {
    echo '### Disk full'

    SMALLDISK=${SMALLDISK:-/mnt/ram}
    export SMALLDISK
    (
	cd /tmp
	sudo umount -l smalldisk.img
	dd if=/dev/zero of=smalldisk.img bs=100k count=1k
	yes|mkfs smalldisk.img
	sudo mkdir -p /mnt/ram
	sudo mount smalldisk.img /mnt/ram
	sudo chmod 777 /mnt/ram
    ) >/dev/null 2>/dev/null

    cat /dev/zero >$SMALLDISK/out
    parallel --tmpdir $SMALLDISK echo ::: OK

    rm $SMALLDISK/out

    sudo umount -l /tmp/smalldisk.img
}

par_delimiter() {
    echo '### Test --delimiter and -d: Delimiter instead of newline'

    echo '# Yes there is supposed to be an extra newline for -d N'
    echo line 1Nline 2Nline 3 | parallel -k -d N echo This is
    echo line 1Nline 2Nline 3 | parallel -k --delimiter N echo This is
    printf "delimiter NUL line 1\0line 2\0line 3" | parallel -k -d '\0' echo
    printf "delimiter TAB line 1\tline 2\tline 3" | parallel -k --delimiter '\t' echo
}

par_argfile() {
    echo '### Test -a and --arg-file: Read input from file instead of stdin'

    seq 1 10 >/tmp/parallel_$$-1; parallel -k -a /tmp/parallel_$$-1 echo; rm /tmp/parallel_$$-1
    seq 1 10 >/tmp/parallel_$$-2; parallel -k --arg-file /tmp/parallel_$$-2 echo; rm /tmp/parallel_$$-2
}

par_pipe_unneeded_procs() {
    echo '### Test bug #34241: --pipe should not spawn unneeded processes'
    seq 3 | parallel -j30 --pipe --block-size 10 cat\;echo o 2> >(grep -Ev 'Warning: Starting|Warning: Consider')
}

par_results_arg_256() {
    echo '### bug #42089: --results with arg > 256 chars (should be 1 char shorter)'
    parallel --results parallel_test_dir echo ::: 1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456;
    ls parallel_test_dir/1/
    rm -rf parallel_test_dir
}

par_pipe_to_func() {
    echo '### bug #45998: --pipe to function broken'

    myfunc() { echo $1; cat; }
    export -f myfunc
    echo pipefunc OK | parallel --pipe myfunc {#}
    echo pipefunc and more OK | parallel --pipe 'myfunc {#};echo and more OK'
}

par_pipepart_roundrobin() {
    echo '### bug #45769: --round-robin --pipepart gives wrong results'

    seq 10000 >/tmp/seq10000
    parallel -j2 --pipepart -a /tmp/seq10000 --block 14 --round-robin wc | wc -l
    rm /tmp/seq10000
}

par_pipepart_header() {
    echo '### bug #44614: --pipepart --header off by one'

    seq 10 >/tmp/parallel_44616
    parallel --pipepart -a /tmp/parallel_44616 -k --block 5 'echo foo; cat'
    parallel --pipepart -a /tmp/parallel_44616 -k --block 2 --regexp --recend 3'\n' 'echo foo; cat'
    rm /tmp/parallel_44616
}

par_quote() {
    echo '### Test -q'
    parallel -kq perl -e '$ARGV[0]=~/^\S+\s+\S+$/ and print $ARGV[0],"\n"' ::: "a b" c "d e f" g "h i"

    echo '### Test -q {#}'
    parallel -kq echo {#} ::: a b
    parallel -kq echo {\#} ::: a b
    parallel -kq echo {\\#} ::: a b
}

par_read_from_stdin() {
    echo '### Test empty line as input'
    echo | parallel echo empty input line

    echo '### Tests if (cat | sh) works'
    perl -e 'for(1..25) {print "echo a $_; echo b $_\n"}' | parallel 2>&1 | sort

    echo '### Test if xargs-mode works'
    perl -e 'for(1..25) {print "a $_\nb $_\n"}' | parallel echo 2>&1 | sort
}

par_total_from_joblog() {
    echo 'bug #47086: [PATCH] Initialize total_completed from joblog'
    rm -f /tmp/parallel-47086
    parallel -j1 --joblog /tmp/parallel-47086 --halt now,fail=1          echo '{= $_=$Global::total_completed =};exit {}' ::: 0 0 0 1 0 0
    parallel -j1 --joblog /tmp/parallel-47086 --halt now,fail=1 --resume echo '{= $_=$Global::total_completed =};exit {}' ::: 0 0 0 1 0 0
}

par_xapply() {
    echo '### Test bug #43284: {%} and {#} with --xapply'
    parallel --xapply 'echo {1} {#} {%} {2}' ::: a ::: b
    parallel -N2 'echo {%}' ::: a b

    echo '### bug #47501: --xapply for some input sources'
    # Wrapping does not work yet
    parallel -k echo ::: a b c aWRAP :::+ aa bb cc ::: A B :::+ AA BB AAwrap
}

par_exit_val() {
    echo '### Test bug #45619: "--halt" erroneous error exit code (should give 0)'
    seq 10 | parallel --halt now,fail=1 true
    echo $?

    echo '### Test exit val - true'
    echo true | parallel
    echo $?

    echo '### Test exit val - false'
    echo false | parallel
    echo $?
}

par_long_cmd_mem_use() {
    echo '### Test long commands do not take up all memory'

    seq 1 100 |
	parallel -j0 -qv perl -e '$r=rand(shift); for($f = 0; $f < $r; $f++){ $a = "a"x100 } print shift,"\n"' 10000 2>/dev/null |
	sort
}

par_test_L_context_replace() {
    echo '### Test -N context replace'

    seq 19 | parallel -k -N 10  echo a{}b

    echo '### Test -L context replace'

    seq 19 | parallel -k -L 10  echo a{}b
}

par_test_r_with_pipe() {
    echo '### Test of -r with --pipe - the first should give an empty line. The second should not.'

    echo | parallel  -j2 -N1 --pipe cat | wc -l
    echo | parallel -r -j2 -N1 --pipe cat | wc -l
}

par_test_tty() {
    echo '### Test --tty'

    seq 0.1 0.1 0.5 | parallel -j1 --tty tty\;sleep
}

par_no_command_given() {
    echo '### Test bugfix if no command given'

    (echo echo; seq 1 5; perl -e 'print "z"x1000000'; seq 12 15) |
	stdout parallel -j1 -km -s 10
}


par_inefficient_L() {
    echo "bug #37325: Inefficiency of --pipe -L"

    seq 2000 | parallel -k --pipe --block 1k -L 4 wc\;echo FOO | uniq
}

par_pipe_record_size_in_lines() {
    echo "bug #34958: --pipe with record size measured in lines"

    seq 10 | parallel -k --pipe -L 4 cat\;echo bug 34958-1
    seq 10 | parallel -k --pipe -l 4 cat\;echo bug 34958-2
}

par_pipe_no_command() {
    echo '### --pipe without command'

    seq -w 10 | stdout parallel --pipe
}

par_expansion_in_colsep() {
    echo '### bug #36260: {n} expansion in --colsep files fails for empty fields if all following fields are also empty'

    echo A,B,, | parallel --colsep , echo {1}{3}{2}
}

par_extglob() {
    bash -O extglob -c '. `which env_parallel.bash`;
      _longopt () {
        case "$prev" in
          --+([-a-z0-9_]))
            echo foo;;
        esac;
      };
      env_parallel echo ::: env_parallel 2>&1
    '
}

par_tricolonplus() {
    echo '### bug #48745: :::+ bug'

    parallel -k echo ::: 11 22 33 ::::+ <(seq 3) <(seq 21 23) ::: a b c :::+ aa bb cc
    parallel -k echo :::: <(seq 3) <(seq 21 23) :::+ a b c ::: aa bb cc
    parallel -k echo :::: <(seq 3) :::: <(seq 21 23) :::+ a b c ::: aa bb cc
}

par_colsep_0() {
    echo 'bug --colsep 0'

    parallel --colsep 0 echo {2} ::: a0OK0c
    parallel --header : --colsep 0 echo {ok} ::: A0ok0B a0OK0b
}

par_empty() {
    echo "bug #:"

    parallel echo ::: true
}

par_empty_line() {
    echo '### Test bug: empty line for | sh with -k'
    (echo echo a ; echo ; echo echo b) | parallel -k
}

par_append_joblog() {
    echo '### can you append to a joblog using +'
    parallel --joblog /tmp/parallel_append_joblog echo ::: 1
    parallel --joblog +/tmp/parallel_append_joblog echo ::: 1
    wc -l /tmp/parallel_append_joblog
}

par_file_ending_in_newline() {
    echo '### Hans found a bug giving unitialized variable'
    echo >/tmp/parallel_f1
    echo >/tmp/parallel_f2'
'
    echo /tmp/parallel_f1 /tmp/parallel_f2 |
    stdout parallel -kv --delimiter ' ' gzip
    rm /tmp/parallel_f*
}

par_python_children() {
    echo '### bug #49970: Python child process dies if --env is used'
    fu() { echo joe; }
    export -f fu
    echo foo | stdout parallel --env fu python -c \
    \""import os; f = os.popen('uname -p'); output = f.read(); rc = f.close()"\"
}

par_pipepart_block_bigger_2G() {
    echo '### Test that --pipepart can have blocks > 2GB'
    tmp=$(mktemp)
    echo foo >$tmp
    parallel --pipepart -a $tmp --block 3G wc
    rm $tmp
}

par_retries_replacement_string() {
    tmp=$(mktemp)
    parallel --retries {//} "echo {/} >>$tmp;exit {/}" ::: 1/11 2/22 3/33
    sort $tmp
    rm $tmp
}

par_tee() {
    export PARALLEL='-k --tee --pipe --tag'
    seq 1000000 | parallel 'echo {%};LC_ALL=C wc' ::: {1..5} ::: {a..b}
    seq 300000 | parallel 'grep {1} | LC_ALL=C wc {2}' ::: {1..5} ::: -l -c
}

par_tagstring_pipe() {
    echo 'bug #50228: --pipe --tagstring broken'
    seq 3000 | parallel -j4 --pipe -N1000 -k --tagstring {%} LC_ALL=C wc
}

par_link_files_as_only_arg() {
    echo 'bug #50685: single ::::+ does not work'
    parallel -k echo ::::+ <(seq 10) <(seq 3) <(seq 4)
}

par_basic_halt() {
    cpuburn=$(tempfile)
    cpuburn2=$(tempfile)
    (echo '#!/usr/bin/perl'
     echo "eval{setpriority(0,0,9)}; while(1){}") > $cpuburn
    chmod 700 $cpuburn
    cp -a $cpuburn $cpuburn2

    parallel -j4 --halt 2 ::: 'sleep 1' $cpuburn false;
    killall $(basename $cpuburn) 2>/dev/null &&
	echo ERROR: cpuburn should already have been killed
    parallel -j4 --halt -2 ::: 'sleep 1' $cpuburn2 true;
    killall $(basename $cpuburn2) 2>/dev/null &&
	echo ERROR: cpuburn2 should already have been killed
    rm $cpuburn $cpuburn2

    parallel --halt error echo ::: should not print
    parallel --halt soon echo ::: should not print
    parallel --halt now echo ::: should not print
}

par_newline_in_command() {
    echo Command with newline and positional replacement strings
    parallel "
      echo {1
      } {2}
    " ::: O ::: K
}

par_wd_3dot_local() {
    echo 'bug #45993: --wd ... should also work when run locally'

    (
	parallel --wd /bi 'pwd; echo $OLDPWD; echo' ::: fail
	parallel --wd /bin 'pwd; echo $OLDPWD; echo' ::: OK
	parallel --wd / 'pwd; echo $OLDPWD; echo' ::: OK
	parallel --wd /tmp 'pwd; echo $OLDPWD; echo' ::: OK
	parallel --wd ... 'pwd; echo $OLDPWD; echo' ::: OK
	parallel --wd . 'pwd; echo $OLDPWD; echo' ::: OK
    ) |
	perl -pe 's:/mnt/4tb::; s:/home/tange:~:;' |
	perl -pe 's:parallel./:parallel/:;' |
	perl -pe 's/'`hostname`'/hostname/g; s/\d+/0/g'
}

par_X_eta_div_zero() {
    echo '### bug #34422: parallel -X --eta crashes with div by zero'

    # We do not care how long it took
    seq 2 | stdout parallel -X --eta echo |
	grep -E -v 'ETA:.*AVG' |
	perl -pe 's/\d+/0/g' |
	perl -pe 's/Comp.* to complete//' |
	perl -ne '/../ and print'
}

par_parcat_args_stdin() {
    echo 'bug #51690: parcat: read args from stdin'
    tmp1=$(tempfile)
    tmp2=$(tempfile)
    echo OK1 > $tmp1
    echo OK2 > $tmp2
    (echo $tmp1
     echo $tmp2) | parcat | sort
    rm $tmp1 $tmp2
}

par_parcat_rm() {
    echo 'bug #51691: parcat --rm remove fifo when opened'
    tmp1=$(tempfile)
    echo OK1 > $tmp1
    parcat --rm $tmp1
    rm $tmp1 2>/dev/null || echo OK file removed
}

par_linebuffer_files() {
    echo '### bug #48658: --linebuffer --files'

    stdout parallel --files --linebuffer 'sleep .1;seq {};sleep .1' ::: {1..10} | wc -l
}

par_halt_one_job() {
    echo '# Halt soon if there is a single job'
    echo should run 0 1 = job 1 2
    parallel -j1 --halt now,fail=1 'echo {#};exit {}' ::: 0 1 0
    echo should run 1 = job 1
    parallel -j1 --halt now,fail=1 'echo {#};exit {}' ::: 1 0 1
    echo should run 0 1 = job 1 2
    parallel -j1 --halt soon,fail=1 'echo {#};exit {}' ::: 0 1 0
    echo should run 1 = job 1
    parallel -j1 --halt soon,fail=1 'echo {#};exit {}' ::: 1 0 1
}

par_blocking_redir() {
    (
	echo 'bug #52740: Bash redirection with process substitution blocks'
	echo Test stdout
	echo 3 | parallel seq > >(echo stdout;wc) 2> >(echo stderr >&2; wc >&2)
	echo Test stderr
	echo nOfilE | parallel ls > >(echo stdout;wc) 2> >(echo stderr >&2; wc >&2)
    ) 2>&1 | LC_ALL=C sort
}

par_pipepart_recend_recstart() {
    echo 'bug #52343: --recend/--recstart does wrong thing with --pipepart'
    tmp1=$(tempfile)
    seq 10 > $tmp1
    parallel -k --pipepart -a $tmp1 --recend '\n' --recstart '6' --block 1 'echo a; cat'
    parallel -k --pipe < $tmp1 --recend '\n' --recstart '6' --block 1 'echo a; cat'
    rm $tmp1 2>/dev/null
}

par_pipe_tag_v() {
    echo 'pipe with --tag -v'
    seq 3 | parallel -v --pipe --tagstring foo cat
    # This should only give the filename
    seq 3 | parallel -v --pipe --tagstring foo --files cat |
	perl -pe 's:/tmp/par.*.par:/tmp/tmpfile.par:'
}

par_dryrun_append_joblog() {
    echo '--dry-run should not append to joblog'
    rm -f /tmp/jl.$$
    parallel -k --jl /tmp/jl.$$ echo ::: 1 2 3
    parallel --dryrun -k --jl +/tmp/jl.$$ echo ::: 1 2 3 4
    # Job 4 should not show up: 3 lines + header = 4
    wc -l < /tmp/jl.$$
}

par_0_no_newline() {
    echo 'A single zero without \n should not be ignored'
    echo -n 0 | parallel echo
}

par_csv() {
    (echo '"col1""x3""","new'
     echo 'line col2","new2'
     echo 'line col3",col 4') |
	parallel --csv echo {1}-{2}-{3}-{4}
    echo '"2""x3"" board","Value with ,",Column 3' |
	parallel --csv echo {1}-{2}-{3}
}

par_csv_pipe() {
    echo 'Only pass full records to tail'
    echo 'Too small block size'
    perl -e 'for $b(1..10) {
           print join",", map {"\"$_\n$_\""} $b*1000..$b*1000+1000;
           print "\n"
         }' |
	stdout parallel --pipe --csv -k --block 10k tail -n1 |
	sort -n

    echo 'More records in single block'
    perl -e 'for $b(1..10) {
           print join",", map {"\"$_\n$_\""} $b*1000..$b*1000+1000;
           print "\n"
         }' |
	stdout parallel --pipe --csv -k --block 100k tail -n1 |
	sort -n
}

par_slow_pipe_regexp() {
    echo "### bug #53718: --pipe --regexp -N blocks"
    echo This should take a few ms, but took more than 2 hours
    seq 54000 80000 |
	parallel -N1000 --regexp --pipe --recstart 4 --recend 5 -k wc
    echo "### These should give same output"
    seq 54000 80000 |
	parallel -N1000 --regexp --pipe --recstart 4 --recend 5 -k cat |
	md5sum
    seq 54000 80000 | md5sum
}

par_results() {
    echo "### --results test.csv"
    parallel -k --results /tmp/$$.csv echo ::: a b c
    rm /tmp/$$.csv
}

par_testquote() {
    testquote() {
	printf '"#&/\n()*=?'"'" |
	    PARALLEL_SHELL=$1 parallel -0 echo
    }
    export -f testquote
    parallel --tag -k testquote ::: ash bash csh dash fdsh fish fizsh ksh ksh93 mksh posh rbash rc rzsh sash sh static-sh tcsh yash zsh
}

par_locale_quoting() {
    echo "### quoting in different locales"
    printf '\243`/tmp/test\243`\n'
    printf '\243`/tmp/test\243`\n' | LC_ALL=zh_HK.big5hkscs xargs echo '$LC_ALL'
    # LC_ALL should be zh_HK.big5hkscs, but that makes quoting hard.
    printf '\243`/tmp/test\243`\n' | LC_ALL=zh_HK.big5hkscs parallel -v echo '$LC_ALL'
}

par_PARALLEL_ENV() {
    echo '### PARALLEL_ENV as variable'
    PARALLEL_ENV="v='OK as variable'" parallel {} '$v' ::: echo
    PARALLEL_ENV=$(mktemp)
    echo '### PARALLEL_ENV as file'
    echo "v='OK as file'" > $PARALLEL_ENV
    PARALLEL_ENV="$PARALLEL_ENV" parallel {} '$v' ::: echo
    echo '### PARALLEL_ENV as fifo'
    rm $PARALLEL_ENV
    mkfifo $PARALLEL_ENV
    # () needed to avoid [1]+  Done
    (echo "v='OK as fifo'" > $PARALLEL_ENV &) 2>/dev/null
    PARALLEL_ENV="$PARALLEL_ENV" parallel {} '$v' ::: echo
    rm $PARALLEL_ENV
}

par_pipe_recend() {
    echo 'bug #54328: --pipe --recend '' blocks'
    seq 3 | parallel -k --pipe --regexp --recend '' -n 1 xxd
    seq 3 | parallel -k --pipe --recend '' -n 1 xxd
}

par_perlexpr_with_newline() {
    echo 'Perl expression spanning 2 lines'
    mkdir -p tmp
    cd tmp
    touch "Dad's \"famous\" 1' pizza"
    # Important with newline in perl expression:
    parallel mv {} '{= $a=pQ($_); $b=$_;
      $_=qx{date -r "$a" +%FT%T}; chomp; $_="$_ $b" =}' \
	 ::: "Dad's \"famous\" 1' pizza"
    rm *"Dad's \"famous\" 1' pizza"
}

par_empty_command() {
    echo 'bug #54647: parset ignores empty lines'
    # really due to this. Should give an empty line due to -v:
    parallel -v :::: <(echo)
    . `which env_parallel.bash`
    parset a,b,c :::: <(echo echo A; echo; echo echo C)
    echo Empty: $b
    parset a,b,c :::: <(echo echo A; echo echo B; echo echo C)
    echo B: $b
}

par_empty_input_on_stdin() {
    echo 'https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=910470'
    echo 'This should give no output'
    true | stdout parallel --shuf echo
}

par_tee_too_many_args() {
    echo '### Fail if there are more arguments than --jobs'
    seq 11 | parallel -k --tag --pipe -j4 --tee grep {} ::: {1..4}
    seq 11 | parallel -k --tag --pipe -j4 --tee grep {} ::: {1..5}
}

par_space_envvar() {
    echo "### bug: --gnu was ignored if env var started with space: PARALLEL=' --gnu'"
    export PARALLEL=" -v" && parallel echo ::: 'space in envvar OK'
}

par_pipe_N1_regexp() {
    echo 'bug #55131: --regexp --recstart hangs'
    echo "These should give the same"
    printf 'begin\n%send\n' '' a b c |
        parallel -kN1 --recstart 'begin\n' --pipe --regexp echo JOB{#}\;cat\;echo END
    printf 'begin\n%send\n' '' a b c |
        parallel -kN1 --recstart 'begin\n' --pipe          echo JOB{#}\;cat\;echo END
}

par_sem_quote() {
    echo '### sem --quote should not add empty argument'
    sem --id sem_quote --fg --quote -v echo
}

par_halt_on_error_division_by_zero() {
    echo '### --halt-on-error soon,fail=100% with no input should not give division by zero'
    stdout parallel --halt-on-error soon,fail=100% echo </dev/null
    echo $?
}

par_wd_dotdotdot() {
    echo '### parallel --wd ... should clean up'
    parallel --wd ... 'pwd;true' ::: foo | parallel ls 2>/dev/null
    echo $? == 1
    echo '### $OLDPWD should be the dir in which parallel starts'
    cd /tmp
    parallel --wd ... 'echo $OLDPWD' ::: foo
}

par_fish() {
    echo '### https://github.com/fish-shell/fish-shell/issues/5582'
    echo OK | stdout fish -c 'parallel --pipe cat'
}

par_jobslot_jobnumber_pipe() {
    echo '### Test bug #43376: {%} and {#} with --pipe'
    echo foo | parallel -q --pipe -k echo {#}
    echo foo | parallel --pipe -k echo {%}
    echo foo | parallel -q --pipe -k echo {%}
    echo foo | parallel --pipe -k echo {#}
}

par_replacement_string_as_part_of_command() {
    echo '### {} as part of the command'
    echo p /bin/ls | parallel l{= s/p/s/ =}
    echo /bin/ls-p | parallel --colsep '-' l{=2 s/p/s/ =} {1}
    echo s /bin/ls | parallel l{}
    echo /bin/ls | parallel ls {}
    echo ls /bin/ls | parallel {}
    echo ls /bin/ls | parallel
}

par_japanese_chars_in_replacement_string() {
    echo '### bug #43817: Some JP char cause problems in positional replacement strings'
    parallel -k echo ::: '�<�>' '�<1 $_=2�>' 'ワ'
    parallel -k echo {1} ::: '�<�>' '�<1 $_=2�>' 'ワ'
    parallel -Xj1 echo ::: '�<�>' '�<1 $_=2�>' 'ワ'
    parallel -Xj1 echo {1} ::: '�<�>' '�<1 $_=2�>' 'ワ'
}

par_rpl_that_is_substring_of_longer_rpl() {
    echo '### --rpl % that is a substring of longer --rpl %D'
    parallel --rpl '{+.} s:.*\.::' --rpl '%' \
	     --rpl '%D $_=::shell_quote(::dirname($_));' \
	     --rpl '%B s:.*/::;s:\.[^/.]+$::;' \
	     --rpl '%E s:.*\.::' \
	     'echo {}=%;echo %D={//};echo %B={/.};echo %E={+.};echo %D/%B.%E={}' ::: a.b/c.d/e.f
}

par_unquote_replacement_string() {
    echo '### Can part of the replacement string be unquoted using uq()?'
    parallel echo '{}{=uq()=}' ::: '`echo foo`'
}

par_delimiter_space() {
    echo '### Does space as delimiter work?'
    parallel -d " " echo ::: "1 done"
}

par_recend_not_regexp() {
    echo '### bug #56558: --rrs with --recend that is not regexp'
    echo 'a+b' | parallel -k --pipe --rrs --recend '+' -N1 'cat;echo end'
}

par_profile() {
    echo '### Test -J profile, -J /dir/profile, -J ./profile'
    echo --tag > testprofile_local
    parallel -J ./testprofile_local echo ::: local
    rm testprofile_local
    echo --tag > testprofile_abs
    parallel -J `pwd`/testprofile_abs echo ::: abs
    rm testprofile_abs
    echo --tag > ~/.parallel/testprofile_config
    parallel -J testprofile_config echo ::: config
    rm ~/.parallel/testprofile_config
}

par_bin() {
    echo '### Test --bin'
    seq 10 | parallel --pipe --bin 1 -j4 wc | sort
    paste <(seq 10) <(seq 10 -1 1) |
	parallel --pipe --colsep '\t' --bin 2 -j4 wc | sort
    echo '### Test --bin with expression that gives 1..n'
    paste <(seq 10) <(seq 10 -1 1) |
	parallel --pipe --colsep '\t' --bin '2 $_=$_%2+1' -j4 wc | sort
    echo '### Test --bin with expression that gives 0..n-1'
    paste <(seq 10) <(seq 10 -1 1) |
	parallel --pipe --colsep '\t' --bin '2 $_%=2' -j4 wc | sort
    # Fails - blocks!
    # paste <(seq 10000000) <(seq 10000000 -1 1) | parallel --pipe --colsep '\t' --bin 2 wc
}

par_cr_newline_header() {
    echo '### --header : should set named replacement string if input line ends in \r\n'
    printf "foo\r\nbar\r\n" |
	parallel --colsep , --header : echo {foo}
}

export -f $(compgen -A function | grep par_)
compgen -A function | grep par_ | LC_ALL=C sort |
    parallel --timeout 30 -j6 --tag -k --joblog /tmp/jl-`basename $0` '{} 2>&1'
