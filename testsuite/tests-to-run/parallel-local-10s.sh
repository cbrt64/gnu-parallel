#!/bin/bash

# Simple jobs that never fails
# Each should be taking 10-30s and be possible to run in parallel
# I.e.: No race conditions, no logins

par_line_buffer() {
    echo "### --line-buffer"
    tmp1=$(tempfile)
    tmp2=$(tempfile)

    seq 10 | parallel -j20 --line-buffer  'seq {} 10 | pv -qL 10' > $tmp1
    seq 10 | parallel -j20                'seq {} 10 | pv -qL 10' > $tmp2
    cat $tmp1 | wc
    diff $tmp1 $tmp2 >/dev/null
    echo These must diff: $?
    rm $tmp1 $tmp2
}

par_pipe_line_buffer() {
    echo "### --pipe --line-buffer"
    tmp1=$(tempfile)
    tmp2=$(tempfile)

    seq 200| parallel -N10 -L1 --pipe  -j20 --line-buffer --tagstring {#} pv -qL 10 > $tmp1
    seq 200| parallel -N10 -L1 --pipe  -j20               --tagstring {#} pv -qL 10 > $tmp2
    cat $tmp1 | wc
    diff $tmp1 $tmp2 >/dev/null
    echo These must diff: $?
    rm $tmp1 $tmp2
}

par_pipe_line_buffer_compress() {
    echo "### --pipe --line-buffer --compress"
    seq 200| parallel -N10 -L1 --pipe  -j20 --line-buffer --compress --tagstring {#} pv -qL 10 | wc
}

par__pipepart_spawn() {
    echo '### bug #46214: Using --pipepart doesnt spawn multiple jobs in version 20150922'
    seq 1000000 > /tmp/num1000000;
    stdout nice parallel --pipepart --progress -a /tmp/num1000000 --block 10k -j0 true |
    grep 1:local | perl -pe 's/\d\d\d/999/g'
}

par__pipe_tee() {
    echo 'bug #45479: --pipe/--pipepart --tee'
    echo '--pipe --tee'

    random1G() {
	< /dev/zero openssl enc -aes-128-ctr -K 1234 -iv 1234 2>/dev/null |
	    head -c 1G;
    }
    random1G | parallel --pipe --tee cat ::: {1..3} | LANG=C wc -c
}

par__pipepart_tee() {
    echo 'bug #45479: --pipe/--pipepart --tee'
    echo '--pipepart --tee'

    random1G() {
	< /dev/zero openssl enc -aes-128-ctr -K 1234 -iv 1234 2>/dev/null |
	    head -c 1G;
    }
    tmp=$(mktemp)
    random1G >$tmp
    parallel --pipepart --tee -a $tmp cat ::: {1..3} | LANG=C wc -c
    rm $tmp
}

par__memleak() {
    echo "### Test memory consumption stays (almost) the same for 30 and 300 jobs"
    echo "should give 1 == true"

    mem30=$( nice stdout time -f %M parallel -j2 true :::: <(perl -e '$a="x"x60000;for(1..30){print $a,"\n"}') );
    mem300=$( nice stdout time -f %M parallel -j2 true :::: <(perl -e '$a="x"x60000;for(1..300){print $a,"\n"}') );
    echo "Memory use should not depend very much on the total number of jobs run\n";
    echo "Test if memory consumption(300 jobs) < memory consumption(30 jobs) * 110% ";
    echo $(($mem300*100 < $mem30 * 110))
}

par_slow_total_jobs() {
    echo 'bug #51006: Slow total_jobs() eats job'
    (echo a; sleep 15; echo b; sleep 15; seq 2) |
	parallel -k echo '{=total_jobs()=}' 2> >(perl -pe 's/\d/X/g')
}

par_interactive() {
    echo '### Test -p --interactive'
    cat >/tmp/parallel-script-for-expect <<_EOF
#!/bin/bash

seq 1 3 | parallel -k -p "sleep 0.1; echo opt-p"
seq 1 3 | parallel -k --interactive "sleep 0.1; echo opt--interactive"
_EOF
    chmod 755 /tmp/parallel-script-for-expect

    (
	expect -b - <<_EOF
spawn /tmp/parallel-script-for-expect
expect "echo opt-p 1"
send "y\n"
expect "echo opt-p 2"
send "n\n"
expect "echo opt-p 3"
send "y\n"
expect "opt-p 1"
expect "opt-p 3"
expect "echo opt--interactive 1"
send "y\n"
expect "echo opt--interactive 2"
send "n\n"
expect "opt--interactive 1"
expect "echo opt--interactive 3"
send "y\n"
expect "opt--interactive 3"
send "\n"
_EOF
	echo
    ) | perl -ne 's/\r//g;/\S/ and print' |
	# Race will cause the order to change
	sort
}

par_k() {
    echo '### Test -k'
    ulimit -n 50
    (echo "sleep 3; echo begin"; seq 1 30 |
	parallel -kq echo "sleep 1; echo {}";
     echo "echo end") | stdout nice parallel -k -j0 |
	grep -Ev 'No more file handles.|Raising ulimit -n'
}

par_k_linebuffer() {
    echo '### bug #47750: -k --line-buffer should give current job up to now'

    parallel --line-buffer --tag -k 'seq {} | pv -qL 10' ::: {10..20}
    parallel --line-buffer -k 'echo stdout top;sleep 1;echo stderr in the middle >&2; sleep 1;echo stdout' ::: end 2>&1
}

par_maxlinelen_m_I() {
    echo "### Test max line length -m -I"

    seq 1 60000 | parallel -I :: -km -j1 echo a::b::c | sort >/tmp/114-a$$;
    md5sum </tmp/114-a$$;
    export CHAR=$(cat /tmp/114-a$$ | wc -c);
    export LINES=$(cat /tmp/114-a$$ | wc -l);
    echo "Chars per line ($CHAR/$LINES): "$(echo "$CHAR/$LINES" | bc);
    rm /tmp/114-a$$
}

par_maxlinelen_X_I() {
    echo "### Test max line length -X -I"

    seq 1 60000 | parallel -I :: -kX -j1 echo a::b::c | sort >/tmp/114-b$$;
    md5sum </tmp/114-b$$;
    export CHAR=$(cat /tmp/114-b$$ | wc -c);
    export LINES=$(cat /tmp/114-b$$ | wc -l);
    echo "Chars per line ($CHAR/$LINES): "$(echo "$CHAR/$LINES" | bc);
    rm /tmp/114-b$$
}

par_compress_fail() {
    echo "### bug #41609: --compress fails"
    seq 12 | parallel --compress --compress-program bzip2 -k seq {} 1000000 | md5sum
    seq 12 | parallel --compress -k seq {} 1000000 | md5sum
}

par_round_robin_blocks() {
    echo "bug #49664: --round-robin does not complete"
    seq 20000000 | parallel -j8 --block 10M --round-robin --pipe wc -c | wc -l
}

par_results_csv() {
    echo "bug #: --results csv"

    doit() {
	parallel -k $@ --results -.csv echo ::: H2 22 23 ::: H1 11 12;
    }
    export -f doit
    parallel -k --tag doit ::: '--header :' '' \
	::: --tag '' ::: --files '' ::: --compress '' |
    perl -pe 's:/par......par:/tmpfile:g;s/\d+\.\d+/999.999/g'
}

par_results_compress() {
    parallel --results /tmp/ged --compress echo ::: 1 | wc -l
    parallel --results /tmp/ged echo ::: 1 | wc -l
}

par_kill_children_timeout() {
    echo '### Test killing children with --timeout and exit value (failed if timed out)'
    pstree $$ | grep sleep | grep -v anacron | grep -v screensave | wc
    doit() {
	for i in `seq 100 120`; do
	    bash -c "(sleep $i)" &
	    sleep $i &
	done;
	wait;
	echo No good;
    }
    export -f doit
    parallel --timeout 3 doit ::: 1000000000 1000000001
    echo $?;
    sleep 2;
    pstree $$ | grep sleep | grep -v anacron | grep -v screensave | wc
}

par_tmux_fg() {
    echo 'bug #50107: --tmux --fg should also write how to access it'
    stdout parallel --tmux --fg sleep ::: 3 | perl -pe 's/.tmp\S+/tmp/'
}

par_plus_dyn_repl() {
    echo "Dynamic replacement strings defined by --plus"

    unset myvar
    echo ${myvar:-myval}
    parallel --rpl '{:-(.+)} $_ ||= $$1' echo {:-myval} ::: "$myvar"
    parallel --plus echo {:-myval} ::: "$myvar"
    parallel --plus echo {2:-myval} ::: "wrong" ::: "$myvar" ::: "wrong"
    parallel --plus echo {-2:-myval} ::: "wrong" ::: "$myvar" ::: "wrong"

    myvar=abcAaAdef
    echo ${myvar:2}
    parallel --rpl '{:(\d+)} substr($_,0,$$1) = ""' echo {:2} ::: "$myvar"
    parallel --plus echo {:2} ::: "$myvar"
    parallel --plus echo {2:2} ::: "wrong" ::: "$myvar" ::: "wrong"
    parallel --plus echo {-2:2} ::: "wrong" ::: "$myvar" ::: "wrong"

    echo ${myvar:2:3}
    parallel --rpl '{:(\d+?):(\d+?)} $_ = substr($_,$$1,$$2);' echo {:2:3} ::: "$myvar"
    parallel --plus echo {:2:3} ::: "$myvar"
    parallel --plus echo {2:2:3} ::: "wrong" ::: "$myvar" ::: "wrong"
    parallel --plus echo {-2:2:3} ::: "wrong" ::: "$myvar" ::: "wrong"

    echo ${#myvar}
    parallel --rpl '{#} $_ = length $_;' echo {#} ::: "$myvar"
    # {#} used for job number
    parallel --plus echo {#} ::: "$myvar"

    echo ${myvar#bc}
    parallel --rpl '{#(.+?)} s/^$$1//;' echo {#bc} ::: "$myvar"
    parallel --plus echo {#bc} ::: "$myvar"
    parallel --plus echo {2#bc} ::: "wrong" ::: "$myvar" ::: "wrong"
    parallel --plus echo {-2#bc} ::: "wrong" ::: "$myvar" ::: "wrong"
    echo ${myvar#abc}
    parallel --rpl '{#(.+?)} s/^$$1//;' echo {#abc} ::: "$myvar"
    parallel --plus echo {#abc} ::: "$myvar"
    parallel --plus echo {2#abc} ::: "wrong" ::: "$myvar" ::: "wrong"
    parallel --plus echo {-2#abc} ::: "wrong" ::: "$myvar" ::: "wrong"

    echo ${myvar%de}
    parallel --rpl '{%(.+?)} s/$$1$//;' echo {%de} ::: "$myvar"
    parallel --plus echo {%de} ::: "$myvar"
    parallel --plus echo {2%de} ::: "wrong" ::: "$myvar" ::: "wrong"
    parallel --plus echo {-2%de} ::: "wrong" ::: "$myvar" ::: "wrong"
    echo ${myvar%def}
    parallel --rpl '{%(.+?)} s/$$1$//;' echo {%def} ::: "$myvar"
    parallel --plus echo {%def} ::: "$myvar"
    parallel --plus echo {2%def} ::: "wrong" ::: "$myvar" ::: "wrong"
    parallel --plus echo {-2%def} ::: "wrong" ::: "$myvar" ::: "wrong"

    echo ${myvar/def/ghi}
    parallel --rpl '{/(.+?)/(.+?)} s/$$1/$$2/;' echo {/def/ghi} ::: "$myvar"
    parallel --plus echo {/def/ghi} ::: "$myvar"
    parallel --plus echo {2/def/ghi} ::: "wrong" ::: "$myvar" ::: "wrong"
    parallel --plus echo {-2/def/ghi} ::: "wrong" ::: "$myvar" ::: "wrong"

    echo ${myvar^a}
    parallel --rpl '{^(.+?)} s/^($$1)/uc($1)/e;' echo {^a} ::: "$myvar"
    parallel --plus echo {^a} ::: "$myvar"
    parallel --plus echo {2^a} ::: "wrong" ::: "$myvar" ::: "wrong"
    parallel --plus echo {-2^a} ::: "wrong" ::: "$myvar" ::: "wrong"
    echo ${myvar^^a}
    parallel --rpl '{^^(.+?)} s/($$1)/uc($1)/eg;' echo {^^a} ::: "$myvar"
    parallel --plus echo {^^a} ::: "$myvar"
    parallel --plus echo {2^^a} ::: "wrong" ::: "$myvar" ::: "wrong"
    parallel --plus echo {-2^^a} ::: "wrong" ::: "$myvar" ::: "wrong"

    myvar=AbcAaAdef
    echo ${myvar,A}
    parallel --rpl '{,(.+?)} s/^($$1)/lc($1)/e;' echo '{,A}' ::: "$myvar"
    parallel --plus echo '{,A}' ::: "$myvar"
    parallel --plus echo '{2,A}' ::: "wrong" ::: "$myvar" ::: "wrong"
    parallel --plus echo '{-2,A}' ::: "wrong" ::: "$myvar" ::: "wrong"
    echo ${myvar,,A}
    parallel --rpl '{,,(.+?)} s/($$1)/lc($1)/eg;' echo '{,,A}' ::: "$myvar"
    parallel --plus echo '{,,A}' ::: "$myvar"
    parallel --plus echo '{2,,A}' ::: "wrong" ::: "$myvar" ::: "wrong"
    parallel --plus echo '{-2,,A}' ::: "wrong" ::: "$myvar" ::: "wrong"
}

par_linebuffer_tag_slow_output() {
    echo "Test output tag with mixing halflines"
    halfline() {
	perl -e '$| = 1; map { print $ARGV[0]; sleep(2); print "$_\n" } split //, "Half\n"' $1
    }
    export -f halfline
    parallel --delay 1 -j0 --tag --line-buffer halfline ::: a b
}

par_retries_all_fail() {
    echo "bug #53748: -k --retries 10 + out of filehandles = blocking"
    ulimit -n 30
    seq 8 |
	parallel -k -j0 --retries 2 --timeout 0.1 'echo {}; sleep {}; false' 2>/dev/null
}



export -f $(compgen -A function | grep par_)
compgen -A function | grep par_ | sort |
    parallel --joblog /tmp/jl-`basename $0` -j10 --tag -k '{} 2>&1'
