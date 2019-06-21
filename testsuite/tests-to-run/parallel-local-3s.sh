#!/bin/bash

# Simple jobs that never fails
# Each should be taking 3-10s and be possible to run in parallel
# I.e.: No race conditions, no logins

par_maxargs() {
    echo '### Test -n and --max-args: Max number of args per line (only with -X and -m)'

    (echo line 1;echo line 2;echo line 3) | parallel -k -n1 -m echo
    (echo line 1;echo line 1;echo line 2) | parallel -k -n2 -m echo
    (echo line 1;echo line 2;echo line 3) | parallel -k -n1 -X echo
    (echo line 1;echo line 1;echo line 2) | parallel -k -n2 -X echo
    (echo line 1;echo line 2;echo line 3) | parallel -k -n1 echo
    (echo line 1;echo line 1;echo line 2) | parallel -k -n2 echo
    (echo line 1;echo line 2;echo line 3) | parallel -k --max-args=1 -X echo
    (echo line 1;echo line 2;echo line 3) | parallel -k --max-args 1 -X echo
    (echo line 1;echo line 1;echo line 2) | parallel -k --max-args=2 -X echo
    (echo line 1;echo line 1;echo line 2) | parallel -k --max-args 2 -X echo
    (echo line 1;echo line 2;echo line 3) | parallel -k --max-args 1 echo
    (echo line 1;echo line 1;echo line 2) | parallel -k --max-args 2 echo
}

par_totaljob_repl() {
    echo '{##} bug #45841: Replacement string for total no of jobs'

    parallel -k --plus echo {##} ::: {a..j};
    parallel -k 'echo {= $::G++ > 3 and ($_=$Global::JobQueue->total_jobs());=}' ::: {1..10}
    parallel -k -N7 --plus echo {#} {##} ::: {1..14}
    parallel -k -N7 --plus echo {#} {##} ::: {1..15}
    parallel -k -S 8/: -X --plus echo {#} {##} ::: {1..15}
}

par_jobslot_repl() {
    echo 'bug #46232: {%} with --bar/--eta/--shuf or --halt xx% broken'

    parallel --bar -kj2 --delay 0.1 echo {%} ::: a b  ::: c d e 2>/dev/null
    parallel --halt now,fail=10% -kj2 --delay 0.1 echo {%} ::: a b  ::: c d e
    parallel --eta -kj2 --delay 0.1 echo {%} ::: a b  ::: c d e 2>/dev/null
    parallel --shuf -kj2 --delay 0.1 echo {%} ::: a b  ::: c d e 2>/dev/null

    echo 'bug #46231: {%} with --pipepart broken. Should give 1+2'

    seq 10000 > /tmp/num10000
    parallel -k --pipepart -ka /tmp/num10000 --block 10k -j2 --delay 0.05 echo {%}
    rm /tmp/num10000
}

par_shard() {
    echo '### --shard'
    # Each of the 5 lines should match:
    #   ##### ##### ######
    seq 100000 | parallel --pipe --shard 1 -j5  wc |
	perl -pe 's/(.*\d{5,}){3}/OK/'
    # Data should be sharded to all processes
    shard_on_col() {
	col=$1
	seq 10 99 | shuf | perl -pe 's/(.)/$1\t/g' |
	    parallel --pipe --shard $col -j2 --colsep "\t" sort -k$col |
	    field $col | sort | uniq -c
    }
    shard_on_col 1
    shard_on_col 2

    shard_on_col_name() {
	colname=$1
	col=$2
	(echo AB; seq 10 99 | shuf) | perl -pe 's/(.)/$1\t/g' |
	    parallel --header : --pipe --shard $colname -j2 --colsep "\t" sort -k$col |
	    field $col | sort | uniq -c
    }
    shard_on_col_name A 1
    shard_on_col_name B 2

    shard_on_col_expr() {
	colexpr="$1"
	col=$2
	(seq 10 99 | shuf) | perl -pe 's/(.)/$1\t/g' |
	    parallel --pipe --shard "$colexpr" -j2 --colsep "\t" "sort -k$col; echo c1 c2" |
	    field $col | sort | uniq -c
    }
    shard_on_col_expr '1 $_%=3' 1
    shard_on_col_expr '2 $_%=3' 2

    shard_on_col_name_expr() {
	colexpr="$1"
	col=$2
	(echo AB; seq 10 99 | shuf) | perl -pe 's/(.)/$1\t/g' |
	    parallel --header : --pipe --shard "$colexpr" -j2 --colsep "\t" "sort -k$col; echo c1 c2" |
	    field $col | sort | uniq -c
    }
    shard_on_col_name_expr 'A $_%=3' 1
    shard_on_col_name_expr 'B $_%=3' 2
    
    echo '*** broken'
    # Shorthand for --pipe -j+0
    seq 100000 | parallel --shard 1 wc |
	perl -pe 's/(.*\d{5,}){3}/OK/'
    # Combine with arguments
    seq 100000 | parallel --shard 1 echo {}\;wc ::: {1..5} ::: a b |
	perl -pe 's/(.*\d{5,}){3}/OK/'
}

par_distribute_args_at_EOF() {
    echo '### Test distribute arguments at EOF to 2 jobslots'
    seq 1 92 | parallel -j2 -kX -s 100 echo

    echo '### Test distribute arguments at EOF to 5 jobslots'
    seq 1 92 | parallel -j5 -kX -s 100 echo

    echo '### Test distribute arguments at EOF to infinity jobslots'
    seq 1 92 | parallel -j0 -kX -s 100 echo 2>/dev/null

    echo '### Test -N is not broken by distribution - single line'
    seq 9 | parallel  -N 10  echo

    echo '### Test -N is not broken by distribution - two lines'
    seq 19 | parallel -k -N 10  echo
}

par_test_X_with_multiple_source() {
    echo '### Test {} multiple times in different commands'

    seq 10 | parallel -v -Xj1 echo {} \; echo {}

    echo '### Test of -X {1}-{2} with multiple input sources'

    parallel -j1 -kX  echo {1}-{2} ::: a ::: b
    parallel -j2 -kX  echo {1}-{2} ::: a b ::: c d
    parallel -j2 -kX  echo {1}-{2} ::: a b c ::: d e f
    parallel -j0 -kX  echo {1}-{2} ::: a b c ::: d e f

    echo '### Test of -X {}-{.} with multiple input sources'

    parallel -j1 -kX  echo {}-{.} ::: a ::: b
    parallel -j2 -kX  echo {}-{.} ::: a b ::: c d
    parallel -j2 -kX  echo {}-{.} ::: a b c ::: d e f
    parallel -j0 -kX  echo {}-{.} ::: a b c ::: d e f
}

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

par_slow_args_generation() {
    echo '### Test slow arguments generation - https://savannah.gnu.org/bugs/?32834'
    seq 1 3 | parallel -j1 "sleep 2; echo {}" | parallel -kj2 echo
}

par_kill_term() {
    echo '### Are children killed if GNU Parallel receives TERM? There should be no sleep at the end'

    parallel -q bash -c 'sleep 120 & pid=$!; wait $pid' ::: 1 &
    T=$!
    sleep 5
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

par_sqlandworker_uninstalled_dbd() {
    echo 'bug #56096: dbi-csv no such column'
    sudo mv /usr/share/perl5/DBD/CSV.pm /usr/share/perl5/DBD/CSV.pm.gone
    parallel --sqlandworker csv:////%2Ftmp%2Flog.csv echo ::: must fail
    sudo cp /usr/share/perl5/DBD/CSV.pm.gone /usr/share/perl5/DBD/CSV.pm
    parallel --sqlandworker csv:////%2Ftmp%2Flog.csv echo ::: works
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
    rm -f mysleep
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

par_lb_mem_usage() {
    long_line() {
	perl -e 'print "x"x100_000_000'
    }
    export -f long_line
    memusage() {
	round=$1
	shift
	/usr/bin/time -v "$@" 2>&1 >/dev/null |
	    perl -ne '/Maximum resident set size .kbytes.: (\d+)/ and print $1,"\n"' |
	    perl -pe '$_ = int($_/'$round')."\n"'
    }
    # 1 line - RAM usage 1 x 100 MB
    memusage 100000 parallel --lb ::: long_line
    # 2 lines - RAM usage 1 x 100 MB
    memusage 100000 parallel --lb ::: 'long_line; echo; long_line'
    # 1 double length line - RAM usage 2 x 100 MB
    memusage 100000 parallel --lb ::: 'long_line; long_line'
}

par_groupby() {
    tsv() {
	printf "%s\t" a1 b1 C1; echo
	printf "%s\t" 2 2 2; echo
	printf "%s\t" 3 2 2; echo
	printf "%s\t" 3 3 2; echo
	printf "%s\t" 3 2 4; echo
	printf "%s\t" 3 2 2; echo
	printf "%s\t" 3 2 3; echo
    }
    export -f tsv

    ssv() {
	# space separated
	printf "%s\t" a1 b1 C1; echo
	printf "%s " 2 2 2; echo
	printf "%s \t" 3 2 2; echo
	printf "%s\t " 3 3 2; echo
	printf "%s  " 3 2 4; echo
	printf "%s\t\t" 3 2 2; echo
	printf "%s\t  \t" 3 2 3; echo
    }
    export -f ssv

    cssv() {
	# , + space separated
	printf "%s,\t" a1 b1 C1; echo
	printf "%s ," 2 2 2; echo
	printf "%s  ,\t" 3 2 2; echo
	printf "%s\t, " 3 3 2; echo
	printf "%s,," 3 2 4; echo
	printf "%s\t,,, " 3 2 2; echo
	printf "%s\t" 3 2 3; echo
    }
    export -f cssv

    csv() {
	# , separated
	printf "%s," a1 b1 C1; echo
	printf "%s," 2 2 2; echo
	printf "%s," 3 2 2; echo
	printf "%s," 3 3 2; echo
	printf "%s," 3 2 4; echo
	printf "%s," 3 2 2; echo
	printf "%s," 3 2 3; echo
    }
    export -f csv

    tester() {
	block="$1"
	groupby="$2"
	generator="$3"
	colsep="$4"
	echo "### test $generator | --colsep $colsep --groupby $groupby $block"
	$generator |
	    parallel --pipe --colsep "$colsep" --groupby "$groupby" -k $block 'echo NewRec; cat'
    }
    export -f tester
    parallel --tag -k tester \
	     ::: -N1 '--block 20' \
	     ::: '3 $_%=2' 3 's/^(.).*/$1/' C1 'C1 $_%=2' \
	     ::: tsv ssv cssv csv \
	     :::+ '\t' '\s+' '[\s,]+' ','

    # Test --colsep char: OK
    # Test --colsep pattern: OK
    # Test --colsep -N1: OK
    # Test --colsep --block 20: OK
    # Test --groupby colno: OK
    # Test --groupby 'colno perl': OK
    # Test --groupby colname: OK
    # Test --groupby 'colname perl': OK
    # Test space sep --colsep '\s': OK
    # Test --colsep --header : (OK: --header : not needed)
}

par_groupby_pipepart() {
    tsv() {
	printf "%s\t" a1 b1 c1 d1 e1 f1; echo
	seq 100000 999999 | perl -pe '$_=join"\t",split//' |
	    sort --parallel=8 --buffer-size=50% -rk3
    }
    export -f tsv

    ssv() {
	# space separated
	tsv | perl -pe '@sep=("\t"," "); s/\t/$sep[rand(2)]/ge;'
    }
    export -f ssv

    cssv() {
	# , + space separated
	tsv | perl -pe '@sep=("\t"," ",","); s/\t/$sep[rand(2)].$sep[rand(2)]/ge;'
    }
    export -f cssv

    csv() {
	# , separated
	tsv | perl -pe 's/\t/,/g;'
    }
    export -f csv

    tester() {
	generator="$1"
	colsep="$2"
	groupby="$3"
	tmp=`tempfile`
	
	echo "### test $generator | --colsep $colsep --groupby $groupby"
	$generator > $tmp
	parallel --pipepart -a $tmp --colsep "$colsep" --groupby "$groupby" -k 'echo NewRec; wc'
    }
    export -f tester
    parallel --tag -k tester \
	     ::: tsv ssv cssv csv \
	     :::+ '\t' '\s+' '[\s,]+' ',' \
	     ::: '3 $_%=2' 3 c1 'c1 $_%=2' 's/^(\d+[\t ,]+){2}(\d+).*/$2/'
}

export -f $(compgen -A function | grep par_)
compgen -A function | grep par_ | LC_ALL=C sort |
    parallel -j6 --tag -k --joblog /tmp/jl-`basename $0` '{} 2>&1'
