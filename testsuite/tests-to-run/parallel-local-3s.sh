#!/bin/bash

# Simple jobs that never fails
# Each should be taking 3-10s and be possible to run in parallel
# I.e.: No race conditions, no logins

par_resume_failed_k() {
    echo '### bug #38299: --resume-failed -k'
    tmp=$(tempfile)
    parallel -k --resume-failed --joblog $tmp echo job{#} val {}\;exit {} ::: 0 1 2 3 0 1
    echo try 2. Gives failing - not 0
    parallel -k --resume-failed --joblog $tmp echo job{#} val {}\;exit {} ::: 0 1 2 3 0 1
    echo with exit 0
    parallel -k --resume-failed --joblog $tmp echo job{#} val {}\;exit 0  ::: 0 1 2 3 0 1
    echo try 2 again. Gives empty
    parallel -k --resume-failed --joblog $tmp echo job{#} val {}\;exit {} ::: 0 1 2 3 0 1
    rm $tmp
}

par_resume_k() {
    echo '### --resume -k'
    tmp=$(tempfile)
    parallel -k --resume --joblog $tmp echo job{}id\;exit {} ::: 0 1 2 3 0 5
    echo try 2 = nothing
    parallel -k --resume --joblog $tmp echo job{}id\;exit {} ::: 0 1 2 3 0 5
    echo two extra
    parallel -k --resume --joblog $tmp echo job{}id\;exit 0 ::: 0 1 2 3 0 5 6 7
    rm -f $tmp
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

par_slow_args_generation() {
    echo '### Test slow arguments generation - https://savannah.gnu.org/bugs/?32834'
    seq 1 3 | parallel -j1 "sleep 2; echo {}" | parallel -kj2 echo
}

par_kill_term_twice() {
    echo '### Are children killed if GNU Parallel receives TERM twice? There should be no sleep at the end'

    parallel -q bash -c 'sleep 120 & pid=$!; wait $pid' ::: 1 &
    T=$!
    sleep 5
    pstree $$
    kill -TERM $T
    sleep 1
    pstree $$
    kill -TERM $T
    sleep 1
    pstree $$
}

par_kill_int_twice() {
    echo '### Are children killed if GNU Parallel receives INT twice? There should be no sleep at the end'

    parallel -q bash -c 'sleep 120 & pid=$!; wait $pid' ::: 1 &
    T=$!
    sleep 5
    pstree $$
    kill -INT $T
    sleep 1
    pstree $$
}

par_children_receive_sig() {
    echo '### Do children receive --termseq signals'

    show_signals() {
	perl -e 'for(keys %SIG) { $SIG{$_} = eval "sub { print STDERR \"Got $_\\n\"; }";} while(1){sleep 1}';
    }
    export -f show_signals
    echo | stdout parallel --termseq TERM,200,TERM,100,TERM,50,KILL,25 -u \
	--timeout 1s show_signals

    echo | stdout parallel --termseq INT,200,TERM,100,KILL,25 -u \
	--timeout 1s show_signals
    sleep 3
}

par_wrong_slot_rpl_resume() {
    echo '### bug #47644: Wrong slot number replacement when resuming'
    seq 0 20 |
    parallel -kj 4 --delay 0.2 --joblog /tmp/parallel-bug-47558 \
	'sleep 1; echo {%} {=$_==10 and exit =}'
    seq 0 20 |
    parallel -kj 4 --resume --delay 0.2 --joblog /tmp/parallel-bug-47558 \
	'sleep 1; echo {%} {=$_==110 and exit =}'
}

par_pipepart_block() {
    echo '### --pipepart --block -# (# < 0)'

    seq 1000 > /run/shm/parallel$$
    parallel -j2 -k --pipepart echo {#} :::: /run/shm/parallel$$
    parallel -j2 -k --block -1 --pipepart echo {#}-2 :::: /run/shm/parallel$$
    parallel -j2 -k --block -2 --pipepart echo {#}-4 :::: /run/shm/parallel$$
    parallel -j2 -k --block -10 --pipepart echo {#}-20 :::: /run/shm/parallel$$
    rm /run/shm/parallel$$
}

par_keeporder_roundrobin() {
    echo 'bug #50081: --keep-order --round-robin should give predictable results'

    export PARALLEL="-j13 --block 1m --pipe --roundrobin"
    random500m() {
	< /dev/zero openssl enc -aes-128-ctr -K 1234 -iv 1234 2>/dev/null |
	    head -c 500m;
    }
    a=$(random500m | parallel -k 'echo {#} $(md5sum)' | sort)
    b=$(random500m | parallel -k 'echo {#} $(md5sum)' | sort)
    c=$(random500m | parallel    'echo {#} $(md5sum)' | sort)
    if [ "$a" == "$b" ] ; then
	# Good: -k should be == -k
	if [ "$a" == "$c" ] ; then
	    # Bad: without -k the command should give different output
	    echo 'Broken: a == c'
	    printf "$a\n$b\n$c\n"
	else
	    echo OK
	fi
    else
	echo 'Broken: a <> b'
	printf "$a\n$b\n$c\n"
    fi
}

par_multiline_commands() {
    echo 'bug #50781: joblog format with multiline commands'
    rm -f /tmp/jl.$$
    parallel --jl /tmp/jl.$$ --timeout 2s 'sleep {}; echo {};
echo finish {}' ::: 1 2 4
    parallel --jl /tmp/jl.$$ --timeout 5s --retry-failed 'sleep {}; echo {};
echo finish {}' ::: 1 2 4
    rm -f /tmp/jl.$$
}

par_dryrun_timeout_ungroup() {
    echo 'bug #51039: --dry-run --timeout 1.4m -u breaks'
    seq 1000 | stdout parallel --dry-run --timeout 1.4m -u --jobs 10 echo | wc
}

par_sqlworker_hostname() {
    echo 'bug #50901: --sqlworker should use hostname in the joblog instead of :'

    MY=:mysqlunittest
    parallel --sqlmaster $MY/hostname echo ::: 1 2 3
    parallel -k --sqlworker $MY/hostname
    hostname=`hostname`
    sql $MY 'select host from hostname;' |
	perl -pe "s/$hostname/<hostname>/g"
}

par_commandline_with_newline() {
    echo 'bug #51299: --retry-failed with command with newline'
    echo 'The format must remain the same'
    (
	parallel --jl - 'false "command
with
newlines"' ::: a b | sort

	echo resume
	parallel --resume --jl - 'false "command
with
newlines"' ::: a b c | sort

	echo resume-failed
	parallel --resume-failed --jl - 'false "command
with
newlines"' ::: a b c d | sort

	echo retry-failed
	parallel --retry-failed --jl - 'false "command
with
newlines"' ::: a b c d e | sort
    ) | perl -pe 's/\0/<null>/g;s/\d+/./g'
}

par_delay_human_readable() {
    # Test that you can use d h m s in --delay
    parallel --delay 0.1s echo ::: a b c
    parallel --delay 0.01m echo ::: a b c
}

par_exitval_signal() {
    echo '### Test --joblog with exitval and Test --joblog with signal -- timing dependent'
    rm -f /tmp/parallel_sleep
    cp /bin/sleep mysleep
    chmod +x mysleep
    parallel --joblog /tmp/parallel_joblog_signal \
	     './mysleep {}' ::: 30 2>/dev/null &
    parallel --joblog /tmp/parallel_joblog_exitval \
	     'echo foo >/tmp/parallel_sleep; ./mysleep {} && echo sleep was not killed=BAD' ::: 30 2>/dev/null &
    while [ ! -e /tmp/parallel_sleep ] ; do
	sleep 1
    done
    sleep 1
    killall -6 mysleep
    wait
    grep -q 134 /tmp/parallel_joblog_exitval && echo exitval=128+6 OK
    grep -q '[^0-9]6[^0-9]' /tmp/parallel_joblog_signal && echo signal OK
    
    rm -f /tmp/parallel_joblog_exitval /tmp/parallel_joblog_signal
}

par_do_not_export_PARALLEL_ENV() {
    echo '### Do not export $PARALLEL_ENV to children'
    doit() {
	echo Should be 0
	echo "$PARALLEL_ENV" | wc
	echo Should give 60k and not overflow
	PARALLEL_ENV="$PARALLEL_ENV" parallel echo '{=$_="\""x$_=}' ::: 60000 | wc
    }
    . `which env_parallel.bash`
    # Make PARALLEL_ENV as big as possible
    PARALLEL_ENV="a='$(seq 100000 | head -c $((139000-$(set|wc -c) )) )'"
    env_parallel doit ::: 1
}

par_nice() {
    echo 'Check that --nice works'
    # parallel-20160422 OK
    # wait for load < 8
    parallel --load 8 echo ::: load_10
    parallel -j0 --timeout 10 --nice 18 bzip2 '<' ::: /dev/zero /dev/zero &
    pid=$!
    # Should find 2 lines
    # Try 5 times if the machine is slow starting bzip2
    (sleep 1; ps -eo "%c %n" | grep 18 | grep bzip2) ||
	(sleep 1; ps -eo "%c %n" | grep 18 | grep bzip2) ||
	(sleep 1; ps -eo "%c %n" | grep 18 | grep bzip2) ||
	(sleep 1; ps -eo "%c %n" | grep 18 | grep bzip2) ||
	(sleep 1; ps -eo "%c %n" | grep 18 | grep bzip2) ||
	(sleep 1; ps -eo "%c %n" | grep 18 | grep bzip2)
    parallel --retries 10 '! kill -TERM' ::: $pid 2>/dev/null
}

par_test_diff_roundrobin_k() {
    echo '### test there is difference on -k'
    . $(which env_parallel.bash)
    mytest() {
	K=$1
	doit() {
	    # Sleep random time ever 10k line
	    # to mix up which process gets the next block
	    perl -ne '$t++ % 10000 or select(undef, undef, undef, rand()/1000);print' |
		md5sum
	}
	export -f doit
	seq 1000000 |
	    parallel --block 65K --pipe $K --roundrobin doit |
	    sort
    }
    export -f mytest
    parset a,b,c mytest ::: -k -k ''
    # a == b and a != c or error
    if [ "$a" == "$b" ]; then
	if [ "$a" != "$c" ]; then
	    echo OK
	else
	    echo error a c
	fi
    else
	echo error a b
    fi
}

export -f $(compgen -A function | grep par_)
compgen -A function | grep par_ | LC_ALL=C sort |
    parallel -j6 --tag -k --joblog /tmp/jl-`basename $0` '{} 2>&1'
