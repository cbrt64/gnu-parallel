#!/bin/bash

# SPDX-FileCopyrightText: 2021 Ole Tange, http://ole.tange.dk and Free Software and Foundation, Inc.
#
# SPDX-License-Identifier: GPL-3.0-or-later

# Simple jobs that never fails
# Each should be taking 3-10s and be possible to run in parallel
# I.e.: No race conditions, no logins

par_pipe_regexp() {
    echo '### --pipe --regexp'
    gen() {
	cat <<EOF
A2, Start, 5
A2, 00100, 5
A2, 00200, 6
A2, 00300, 6
A2, Start, 7
A2, 00100, 7
A2, Start, 7
A2, 00200, 8
EOF
	true
    }
    p="parallel --pipe --regexp -k"
    gen | $p --recstart 'A\d+, Start' -N1 'echo Record;cat'
    gen | $p --recstart '[A-Z]\d+, Start' -N1 'echo Record;cat'
    gen | $p --recstart '.*, Start' -N1 'echo Record;cat'
    echo '### Prepend first record with garbage'
    (echo Garbage; gen) |
	$p --recstart 'A\d+, Start' -N1 'echo Record;cat'
    (echo Garbage; gen) |
	$p --recstart '[A-Z]\d+, Start' -N1 'echo Record;cat'
    (echo Garbage; gen) |
	$p --recstart '.*, Start' -N1 'echo Record;cat'
}

par_delay_halt_soon() {
    echo "bug #59893: --halt soon doesn't work with --delay"
    seq 0 10 |
	stdout parallel --delay 1 -uj2 --halt soon,fail=1 'sleep 0.{};echo {};exit {}'
}

par_show_limits() {
    echo '### Test --show-limits'
    (
	(echo b; echo c; echo f) | parallel -k --show-limits echo {}ar
	(echo b; echo c; echo f) | parallel -j1 -kX --show-limits -s 100 echo {}ar
	echo "### BUG: empty lines with --show-limit"
	echo | stdout parallel --show-limits
    ) | perl -pe 's/131\d\d\d/131xxx/'
}

par_test_delimiter() {
    echo "### Test : as delimiter. This can be confusing for uptime ie. --load";
    export PARALLEL="--load 300%"
    parallel -k --load 300% -d : echo ::: a:b:c
}

par_10000_m_X() {
    echo '### Test -m with 10000 args'
    seq 10000 | perl -pe 's/$/.gif/' |
        parallel -j1 -km echo a{}b{.}c{.} |
        parallel -k --pipe --tee ::: wc md5sum
}

par_10000_5_rpl_X() {
    echo '### Test -X with 10000 args and 5 replacement strings'
    seq 10000 | perl -pe 's/$/.gif/' | parallel -j1 -kX echo a{}b{.}c{.}{.}{} | wc -l
    seq 10000 | perl -pe 's/$/.gif/' | parallel -j1 -kX echo a{}b{.}c{.}{.} | wc -l
    seq 10000 | perl -pe 's/$/.gif/' | parallel -j1 -kX echo a{}b{.}c{.} | wc -l
    seq 10000 | perl -pe 's/$/.gif/' | parallel -j1 -kX echo a{}b{.}c | wc -l
    seq 10000 | perl -pe 's/$/.gif/' | parallel -j1 -kX echo a{}b | wc -l
}

par_X_I_meta() {
    echo '### Test -X -I with shell meta chars'
    seq 10000 | parallel -j1 -I :: -X echo a::b::c:: | wc -l
    seq 10000 | parallel -j1 -I '<>' -X echo 'a<>b<>c<>' | wc -l
    seq 10000 | parallel -j1 -I '<' -X echo 'a<b<c<' | wc -l
    seq 10000 | parallel -j1 -I '>' -X echo 'a>b>c>' | wc -l
}

par_delay() {
    echo "### Test --delay"
    seq 9 | /usr/bin/time -f %e  parallel -j3 --delay 0.57 true {} 2>&1 |
	perl -ne '$_ > 3.3 and print "More than 3.3 secs: OK\n"'
}

par_sshdelay() {
    echo '### test --sshdelay'
    stdout /usr/bin/time -f %e parallel -j0 --sshdelay 0.5 -S localhost true ::: 1 2 3 |
	perl -ne 'print($_ > 1.30 ? "OK\n" : "Not OK\n")'
}

par_compute_command_len() {
    echo "### Computing length of command line"
    seq 1 2 | parallel -k -N2 echo {1} {2}
    parallel --xapply -k -a <(seq 11 12) -a <(seq 1 3) echo
    parallel -k -C %+ echo '"{1}_{3}_{2}_{4}"' ::: 'a% c %%b' 'a%c% b %d'
    parallel -k -C %+ echo {4} ::: 'a% c %%b'
}

par_replacement_slashslash() {
    echo '### Test {//}'
    parallel -k echo {//} {} ::: a a/b a/b/c
    parallel -k echo {//} {} ::: /a /a/b /a/b/c
    parallel -k echo {//} {} ::: ./a ./a/b ./a/b/c
    parallel -k echo {//} {} ::: a.jpg a/b.jpg a/b/c.jpg
    parallel -k echo {//} {} ::: /a.jpg /a/b.jpg /a/b/c.jpg
    parallel -k echo {//} {} ::: ./a.jpg ./a/b.jpg ./a/b/c.jpg

    echo '### Test {1//}'
    parallel -k echo {1//} {} ::: a a/b a/b/c
    parallel -k echo {1//} {} ::: /a /a/b /a/b/c
    parallel -k echo {1//} {} ::: ./a ./a/b ./a/b/c
    parallel -k echo {1//} {} ::: a.jpg a/b.jpg a/b/c.jpg
    parallel -k echo {1//} {} ::: /a.jpg /a/b.jpg /a/b/c.jpg
    parallel -k echo {1//} {} ::: ./a.jpg ./a/b.jpg ./a/b/c.jpg
}

par_eta() {
    echo '### Test of --eta'
    seq 1 10 | stdout parallel --eta "sleep 1; echo {}" | wc -l

    echo '### Test of --eta with no jobs'
    stdout parallel --eta "sleep 1; echo {}" < /dev/null
}

par_progress() {
    echo '### Test of --progress'
    seq 1 10 | stdout parallel --progress "sleep 1; echo {}" | wc -l

    echo '### Test of --progress with no jobs'
    stdout parallel --progress "sleep 1; echo {}" < /dev/null
}

par_tee_with_premature_close() {
    echo '--tee --pipe should send all data to all commands'
    echo 'even if a command closes stdin before reading everything'
    echo 'tee with --output-error=warn-nopipe support'
    correct="$(seq 1000000 | parallel -k --tee --pipe ::: wc head tail 'sleep 1')"
    echo "$correct"
    echo 'tee without --output-error=warn-nopipe support'
    mkdir -p tmp
    cat > tmp/tee <<-EOF
	#!/usr/bin/perl

	if(grep /output-error=warn-nopipe/, @ARGV) {
	    exit(1);
	}
	exec "/usr/bin/tee", @ARGV;
	EOF
    chmod +x tmp/tee
    PATH=tmp:$PATH
    # This gives incomplete output due to:
    # * tee not supporting --output-error=warn-nopipe
    # * sleep closes stdin before EOF
    # Depending on tee it may provide partial output or no output
    wrong="$(seq 1000000 | parallel -k --tee --pipe ::: wc head tail 'sleep 1')"
    if diff <(echo "$correct") <(echo "$wrong") >/dev/null; then
	echo Wrong: They should not give the same output
    else
	echo OK
    fi
}

par_tee_too_many_args() {
    echo '### Fail if there are more arguments than --jobs'
    seq 11 | stdout parallel -k --tag --pipe -j4 --tee grep {} ::: {1..4}
    seq 11 | stdout parallel -k --tag --pipe -j0 --tee grep {} ::: {1..10000}
}

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
    parallel -k --plus -j 10 echo '{0#}/{##}:{0%}' ::: {1..5} ::: {1..4}
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

par_multiline_commands() {
    echo 'bug #50781: joblog format with multiline commands'
    rm -f /tmp/jl.$$
    parallel --jl /tmp/jl.$$ --timeout 2s 'sleep {}; echo {};
echo finish {}' ::: 1 2 4
    parallel --jl /tmp/jl.$$ --timeout 5s --retry-failed 'sleep {}; echo {};
echo finish {}' ::: 1 2 4
    rm -f /tmp/jl.$$
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

export -f $(compgen -A function | grep par_)
compgen -A function | grep par_ | LC_ALL=C sort |
    parallel --timeout 1000% -j6 --tag -k --joblog /tmp/jl-`basename $0` '{} 2>&1'
